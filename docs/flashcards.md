# Claude Flashcards & SQFlite

Upload a PDF in **Créer depuis un PDF**. Selecting the file starts Claude generation automatically (10 cards by default). Each card has a question, answer and source page. Inspect/edit generated cards, then revise using Oublié / Difficile / Bien / Facile. Reviews adapt the next due date.

## Configure Claude Sonnet 5.5

The backend uses Anthropic's native `POST https://api.anthropic.com/v1/messages`, model `claude-sonnet-5-5`, and a structured JSON output schema. It extracts page-labelled text from the uploaded PDF, sends it to Claude and validates source quotations in the result.

Edit `backend/.env` locally:

```dotenv
ANTHROPIC_API_KEY=your-real-anthropic-key
ANTHROPIC_MODEL=claude-sonnet-5-5
```

`backend/.env` is gitignored and loaded automatically. Existing process environment variables take precedence. Restart the Python backend after editing it. Keep the key in this file or the server environment; it is never passed from Flutter, stored in SQFlite, or returned in an API response. Do not paste your real key into source code or chat.

A key with Anthropic API credits and model access is required. Without it, uploading returns an actionable configuration error. There is no automatic fake or offline fallback in the upload flow. The example deck remains available for testing reviews without a key.

Official references:
- https://platform.claude.com/docs/en/models/sonnet-5-5/overview
- https://platform.claude.com/docs/en/build-with-claude/structured-outputs

## Run

Python 3.10+ and Flutter 3.47.5 / Dart 3.13.4 were used.

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
.\.venv\Scripts\python.exe backend/server.py
```

In another terminal:

```powershell
flutter pub get
dart run sqflite_common_ffi_web:setup
flutter run --no-pub -d web-server --web-port 8080 --web-hostname 127.0.0.1
```

Or serve a release build:

```powershell
flutter build web --no-pub --no-web-resources-cdn
.\.venv\Scripts\python.exe -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

Open http://127.0.0.1:8080. Keep the backend on port 8081 running separately. On Windows, `pub get` may report missing desktop symlink support after successful package resolution; web builds can use `--no-pub`. Native Windows plugin development needs Developer Mode.

To use a deployed backend set `--dart-define=FLASHCARDS_API_URL=https://your-backend` and set the backend's ALLOWED_ORIGINS to the actual frontend origin.

## SQFlite database

`FlashcardDatabase` is the persistence layer:

- Android/iOS/macOS: native `sqflite`.
- Windows/Linux: `sqflite_common_ffi`.
- Browser: `sqflite_common_ffi_web`, running real SQLite WebAssembly in a worker and persisting it in IndexedDB. This is the SQFlite browser adapter, since native SQFlite itself does not run in a browser.

Database: `smart_learning_flashcards.db`, schema version 2.
Tables: `decks` (title, source, generation mode, ordering), `cards` (question, answer, source page, due date, interval, ease, repetitions, reviews, lapses), `metadata` (migration state). Foreign keys link cards to decks. Indexes cover due dates and deck ordering. Saves run in a transaction: failed writes preserve the prior dataset.

The prior SharedPreferences library migrates once on first database open. The old key `smart_learning.flashcards.v1` is retained as a recovery copy, while the SQLite marker prevents deleted decks from being reimported. SharedPreferences is no longer used for ongoing card/review storage. Malformed legacy content is preserved and reported.

Browser storage is tied to origin and port: continue using 127.0.0.1:8080 to keep the same database. Clearing site data deletes the browser database. No cross-device synchronization or user accounts are implemented.

Web assets `web/sqlite3.wasm` and `web/sqflite_sw.js` must be served next to index.html. They are checked into source. After upgrading SQLite packages run `dart run sqflite_common_ffi_web:setup --force`, rebuild, then reload all tabs.

## API and limits

`GET /health` returns status, ai_configured, provider and model, never the key.

`POST /api/flashcards/generate`:

```json
{"pdf":"base64 PDF bytes","filename":"course.pdf","count":10,"mode":"ai"}
```

```json
{"cards":[{"question":"...","answer":"...","page":1}],"mode":"ai","page_count":1}
```

Maximum PDF: 10 MiB, 100 pages, 60,000 extracted characters. Scanned PDFs need OCR before import. Count: 1–20; short sources may produce fewer cards. The server checks question/answer lengths, source pages, exact quotations, duplicates, truncated model responses and provider failures. Review answers before studying; source checks do not guarantee correctness.

The internal offline extractor remains available via `mode: offline` for deterministic backend tests and legacy tooling. The Flutter upload flow always requests Claude.

Server binds only to localhost; allowed browser origins default to http://127.0.0.1:8080 and http://localhost:8080. The service processes PDFs in memory. For public hosting add authentication, rate limits, isolated PDF parsing and a production HTTP server.

## Review scheduling

SM-2 inspired: Oublié = 10 minutes and reset successful repetitions; Difficile = 1 day initially then interval × 1.2; Bien = 1 day, 6 days, then interval × ease; Facile = 4 days initially then interval × (ease + .15) × 1.3. Ease is bounded 1.3–3.0; intervals 1–3650 days. Forgotten cards become due after ten minutes. A session uses its initial due-card queue. Each rating is saved; failed saves roll back the rating.

Memorization index: successful repetitions × 20, capped at 100 and reset after forgetting. This is a self-assessment heuristic.

## Verify

```powershell
flutter analyze --no-pub lib test
flutter test --no-pub
.\.venv\Scripts\python.exe -m unittest discover -s backend -v
flutter build web --no-pub --no-web-resources-cdn
```

Tests cover SQLite persistence across connections, one-time migration, transaction rollback, corrupt-data recovery, review intervals, the reveal/rate flow, narrow layout, PDF extraction, source validation and mocked Anthropic responses/errors. A live Claude call requires the local API key.

Use **Explain more with AI** in a deck or after revealing the answer during review. The backend sends only that card’s question and answer to Claude and returns a French explanation, example, and takeaway. Explanations are generated on demand and do not change review progress.

Use **Créer manuellement** to name a deck and enter its first card without AI or a PDF. Add more cards from the deck. **Cartes à retravailler** starts a focused review of cards last rated Oublié or Difficile, even before their due date. Rating a card Bien or Facile removes it from this list. Older cards enter the list only after a new rating; the previous database did not record individual grades.
