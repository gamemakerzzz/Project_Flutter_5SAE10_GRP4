"""Bounded retries for temporary upstream failures; never logs request secrets."""
import time
import urllib.error
import urllib.request


def read_response(request):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return response.read(2 * 1024 * 1024 + 1)
        except urllib.error.HTTPError as error:
            retryable = error.code in (500, 502, 503, 504, 529)
            if not retryable or attempt == 2 or error.headers.get('x-should-retry') == 'false':
                raise
            try:
                delay = float(error.headers.get('retry-after', 2 ** attempt))
            except (TypeError, ValueError):
                delay = 2 ** attempt
            error.close()
            time.sleep(min(max(delay, 0), 5))
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)
