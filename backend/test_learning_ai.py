import json
import unittest
from unittest.mock import patch
from learning_ai import LearningError, course_ask, quiz_generate
from server import quiz_correct, InputError


class LearningTests(unittest.TestCase):
    def setUp(self):
        self.sources = [{'chunkId': 'c', 'documentId': 'd', 'courseId': 'course',
                         'documentName': 'Flutter', 'page': 2,
                         'excerpt': 'Flutter uses widgets to describe the user interface.'}]

    def test_course_answer_validates_exact_source_and_number(self):
        value = course_ask({'question': 'What does Flutter use?', 'sources': self.sources},
                           lambda _: {'answer': 'Widgets [1].', 'citations': [
                               {'index': 1, 'quote': 'Flutter uses widgets'}]})
        self.assertTrue(value['generated'])
        self.assertEqual(value['sources'][0]['sourceNumber'], 1)

    def test_hallucinated_citation_is_rejected(self):
        for citation in [{'index': 2, 'quote': 'Flutter uses widgets'},
                         {'index': 1, 'quote': 'Flutter uses magic to render'}]:
            with self.assertRaises(LearningError):
                course_ask({'question': 'What?', 'sources': self.sources},
                           lambda _: {'answer': 'Widgets [1].', 'citations': [citation]})

    def test_insufficient_evidence_is_not_generated_answer(self):
        result = course_ask({'question': 'What?', 'sources': self.sources},
                            lambda _: {'answer': 'No evidence.', 'citations': []})
        self.assertFalse(result['generated'])
        self.assertEqual(result['sources'], [])

    def test_mismatched_inline_citation_is_rejected(self):
        with self.assertRaises(LearningError):
            course_ask({'question': 'What?', 'sources': self.sources},
                       lambda _: {'answer': 'Widgets [2].', 'citations': [
                           {'index': 1, 'quote': 'Flutter uses widgets'}]})

    @patch.dict('os.environ', {'GEMINI_API_KEY': 'test-only'})
    @patch('learning_ai.provider_request')
    def test_gemini_question_contract_and_server_credentials(self, request):
        question = {'prompt': 'What is Flutter?', 'kind': 'open', 'options': [],
                    'correctIndex': None, 'expectedAnswer': 'A UI toolkit',
                    'explanation': 'It builds interfaces.', 'keywords': ['toolkit']}
        request.return_value = {'candidates': [{'content': {'parts': [{'text': json.dumps([question])}]}}]}
        result = quiz_generate({'courseTitle': 'Flutter', 'courseContext': 'Flutter is a UI toolkit.',
                                'count': 1, 'mix': 'open'})
        self.assertEqual(result['questions'][0]['id'], 'question-1')
        self.assertEqual(request.call_args.args[2]['x-goog-api-key'], 'test-only')
        schema = request.call_args.args[3]['generationConfig']['responseJsonSchema']
        self.assertEqual(schema['minItems'], 1)
        self.assertEqual(schema['maxItems'], 1)
        self.assertEqual(schema['items']['properties']['kind']['enum'], ['open'])
        self.assertEqual(schema['items']['properties']['correctIndex']['type'], 'null')
        question['keywords'] = []
        request.return_value['candidates'][0]['content']['parts'][0]['text'] = json.dumps([question])
        with self.assertRaises(LearningError):
            quiz_generate({'courseTitle': 'Flutter', 'courseContext': 'Evidence', 'count': 1, 'mix': 'open'})

    @patch('server.claude_json', side_effect=InputError('Claude: quota exceeded'))
    def test_correction_preserves_provider_failure(self, provider):
        with self.assertRaisesRegex(InputError, 'quota'):
            quiz_correct({'question': 'Question?', 'expectedAnswer': 'Expected', 'answer': 'Student answer'})


if __name__ == '__main__':
    unittest.main()
