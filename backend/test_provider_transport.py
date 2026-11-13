import unittest
import urllib.error
from unittest.mock import MagicMock, patch

from provider_transport import read_response


class RetryTests(unittest.TestCase):
    @patch('provider_transport.time.sleep')
    @patch('provider_transport.urllib.request.urlopen')
    def test_temporary_503_recovers(self, open_url, sleep):
        success = MagicMock()
        success.__enter__.return_value.read.return_value = b'{}'
        open_url.side_effect = [urllib.error.HTTPError('https://example.com', 503, '', {'retry-after': '1'}, None), success]
        self.assertEqual(read_response(object()), b'{}')
        self.assertEqual(open_url.call_count, 2)
        sleep.assert_called_once_with(1)

    @patch('provider_transport.time.sleep')
    @patch('provider_transport.urllib.request.urlopen')
    def test_persistent_outage_stops_after_three_attempts(self, open_url, sleep):
        open_url.side_effect = [urllib.error.HTTPError('https://example.com', 503, '', {}, None) for _ in range(3)]
        with self.assertRaises(urllib.error.HTTPError):
            read_response(object())
        self.assertEqual(open_url.call_count, 3)

    @patch('provider_transport.time.sleep')
    @patch('provider_transport.urllib.request.urlopen')
    def test_invalid_key_is_not_retried(self, open_url, sleep):
        open_url.side_effect = urllib.error.HTTPError('https://example.com', 401, '', {}, None)
        with self.assertRaises(urllib.error.HTTPError):
            read_response(object())
        self.assertEqual(open_url.call_count, 1)
        sleep.assert_not_called()

    @patch('provider_transport.time.sleep')
    @patch('provider_transport.urllib.request.urlopen')
    def test_provider_no_retry_header_is_respected(self, open_url, sleep):
        open_url.side_effect = urllib.error.HTTPError('https://example.com', 503, '', {'x-should-retry': 'false'}, None)
        with self.assertRaises(urllib.error.HTTPError):
            read_response(object())
        self.assertEqual(open_url.call_count, 1)
