import base64
import io
import json
import unittest
from unittest.mock import patch
from pypdf import PdfWriter
from pypdf.generic import DecodedStreamObject, DictionaryObject, NameObject
from server import InputError, extract_pages, generate, offline_cards, validate_cards, ai_cards


def sample_pdf():
    writer = PdfWriter()
    page = writer.add_blank_page(width=600, height=800)
    font = DictionaryObject({NameObject('/Type'): NameObject('/Font'), NameObject('/Subtype'): NameObject('/Type1'), NameObject('/BaseFont'): NameObject('/Helvetica')})
    page[NameObject('/Resources')] = DictionaryObject({NameObject('/Font'): DictionaryObject({NameObject('/F1'): writer._add_object(font)})})
    stream = DecodedStreamObject()
    stream.set_data(b'BT /F1 12 Tf 50 700 Td (Flutter uses widgets to describe the user interface. StatefulWidget preserves mutable state between rebuilds. Dart supports asynchronous operations with Futures.) Tj ET')
    page[NameObject('/Contents')] = writer._add_object(stream)
    out = io.BytesIO(); writer.write(out)
    return out.getvalue()


class GenerationTests(unittest.TestCase):
    def test_pdf_to_cards(self):
        data = generate({'pdf': base64.b64encode(sample_pdf()).decode(), 'count': 5, 'mode': 'offline'})
        self.assertEqual(data['mode'], 'offline')
        self.assertTrue(1 <= len(data['cards']) <= 5)
        self.assertEqual(data['cards'][0]['page'], 1)
        self.assertIn('______', data['cards'][0]['question'])
        self.assertIn('Flutter', data['cards'][0]['answer'])

    def test_invalid_pdf_and_scan(self):
        for value in ['invalid%%', base64.b64encode(b'not pdf').decode()]:
            with self.assertRaises(InputError): extract_pages(value)
        w = PdfWriter(); w.add_blank_page(width=100, height=100)
        out = io.BytesIO(); w.write(out)
        with self.assertRaisesRegex(InputError, 'OCR'): extract_pages(base64.b64encode(out.getvalue()).decode())

    def test_invalid_count_and_mode(self):
        for value in [0, 21, True, '10']:
            with self.assertRaises(InputError): generate({'count': value})
        with self.assertRaises(InputError): generate({'mode': 'unknown'})

    def test_ai_requires_real_source_and_nonempty_answer(self):
        pages = [{'page': 1, 'text': 'Flutter uses widgets to describe the user interface.'}]
        row = {'question': 'Que fait Flutter ?', 'answer': 'Il utilise des widgets.', 'page': 1, 'quote': 'Flutter uses widgets'}
        self.assertEqual(len(validate_cards({'cards': [row]}, pages, 5)), 1)
        for field, bad in [('page', 2), ('answer', ''), ('quote', 'This does not exist in the original document')]:
            with self.assertRaises(InputError): validate_cards({'cards': [{**row, field: bad}]}, pages, 5)

    @patch('server.ai_cards')
    def test_uploaded_pdf_uses_claude_by_default(self, claude):
        claude.return_value = [{'question': 'What are widgets?', 'answer': 'UI building blocks.', 'page': 1}]
        result = generate({'pdf': base64.b64encode(sample_pdf()).decode(), 'count': 10})
        self.assertEqual(result['mode'], 'ai')
        self.assertEqual(result['cards'], claude.return_value)
        pages, count = claude.call_args.args
        self.assertIn('Flutter', pages[0]['text'])
        self.assertEqual(count, 10)

    @patch.dict('os.environ', {'ANTHROPIC_API_KEY': ''})
    def test_no_silent_fake_ai(self):
        with self.assertRaisesRegex(InputError, 'pas configuré'): ai_cards([], 5)

    @patch.dict('os.environ', {'ANTHROPIC_API_KEY': 'test-key', 'ANTHROPIC_MODEL': 'claude-sonnet-5-5'})
    @patch('urllib.request.urlopen')
    def test_provider_response_contract(self, request):
        pages = [{'page': 1, 'text': 'Flutter uses widgets to describe the user interface.'}]
        cards = {'cards': [{'question': 'Que fait Flutter ?', 'answer': 'Il utilise des widgets.', 'page': 1, 'quote': 'Flutter uses widgets'}]}
        request.return_value.__enter__.return_value.read.return_value = json.dumps({'stop_reason': 'end_turn', 'content': [{'type': 'text', 'text': json.dumps(cards)}]}).encode()
        self.assertEqual(ai_cards(pages, 5)[0]['page'], 1)
        req = request.call_args.args[0]
        self.assertEqual(req.full_url, 'https://api.anthropic.com/v1/messages')
        body = json.loads(req.data)
        self.assertEqual(body['model'], 'claude-sonnet-5-5')
        self.assertEqual(body['output_config']['format']['type'], 'json_schema')
        self.assertEqual(req.get_header('X-api-key'), 'test-key')
        self.assertNotIn('test-key', json.dumps(body))

    @patch.dict('os.environ', {'ANTHROPIC_API_KEY': 'test-key'})
    @patch('urllib.request.urlopen')
    def test_truncated_response_is_not_saved(self, request):
        request.return_value.__enter__.return_value.read.return_value = json.dumps({'stop_reason': 'max_tokens'}).encode()
        with self.assertRaisesRegex(InputError, 'interrompue'): ai_cards([], 5)

    @patch.dict('os.environ', {'ANTHROPIC_API_KEY': 'test-key'})
    @patch('urllib.request.urlopen')
    def test_auth_error_is_actionable_and_does_not_echo_secrets(self, request):
        import urllib.error
        request.side_effect = urllib.error.HTTPError('https://api.anthropic.com/v1/messages', 401, 'secret-provider-body', {}, None)
        with self.assertRaisesRegex(InputError, 'Clé API Claude invalide') as error: ai_cards([], 5)
        self.assertNotIn('test-key', str(error.exception))

class ExplanationTests(unittest.TestCase):
    @patch('server.claude_json')
    def test_explains_card_and_returns_all_sections(self, claude):
        from server import explain
        claude.return_value = {'explanation': ' Pourquoi. ', 'example': 'Exemple.', 'takeaway': 'À retenir.'}
        result = explain({'question': '  Pourquoi ? ', 'answer': ' Réponse. '})
        self.assertEqual(result, {'explanation': 'Pourquoi.', 'example': 'Exemple.', 'takeaway': 'À retenir.'})
        self.assertEqual(claude.call_args.args[1], {'question': 'Pourquoi ?', 'answer': 'Réponse.'})

    @patch('server.claude_json')
    def test_invalid_card_does_not_call_claude(self, claude):
        from server import explain
        with self.assertRaises(InputError):
            explain({'question': '', 'answer': 'Réponse.'})
        claude.assert_not_called()

    @patch('server.claude_json', return_value={'explanation': 'Only one section.'})
    def test_incomplete_explanation_is_rejected(self, _):
        from server import explain
        with self.assertRaisesRegex(InputError, 'incomplète'):
            explain({'question': 'Pourquoi ?', 'answer': 'Réponse.'})


if __name__ == '__main__': unittest.main()
