# StudyMate API — Dart Frog + SQLite

This is the backend used by the Flutter app. Application code runs in Dart; SQLite stores accounts, courses, extracted passages and vectors. Ollama runs local embedding and language models. See [the current RAG guide](../docs/courses_rag.md) for setup, indexing and validation.

## Run on Windows

From the repository root (Flutter 3.47.7 / Dart 3.13.5 on the validation machine):

```powershell
cd backend
dart pub get
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-dev.ps1
```

The script creates a random development signing secret once in `data/jwt-secret.txt`, loads it into `JWT_SECRET`, and starts `dart run bin/server.dart` on `127.0.0.1:8080`. It never prints the secret. The whole data directory is Git-ignored. Protect this directory with your local OS account permissions; do not share it or use this development secret for a deployed service. Keep it between restarts to preserve token validity. No sample account is seeded.

Alternative, with a secret already supplied by your environment:

```powershell
cd backend
# JWT_SECRET must already contain a strong random secret of at least 32 characters.
$env:HOST = '127.0.0.1'
$env:PORT = '8080'
dart run bin/server.dart
```

`GET http://localhost:8080/health` returns `{"status":"ok"}`. Stop the server with Ctrl+C. The first run resolves native SQLite/PDFium assets and may require network access. No Java PDF extractor or external SQLite installation is required.

The regular entry point uses Dart Frog's `serve` and `RequestContext` directly. Conventional Dart Frog route files also delegate to the same HTTP application through an injected singleton. To install the optional route-development CLI:

```powershell
dart pub global activate dart_frog_cli
# Set JWT_SECRET first, then from backend/:
dart pub global run dart_frog_cli:dart_frog dev
```

The validated command is `dart run bin/server.dart`. Do not run multiple backend processes against the same development files: the processing queue is single-process and startup marks interrupted jobs failed.

## Flutter / Android emulator

In a second terminal at the repository root:

```powershell
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Create an account using **Get Started**, then open **Courses**. Create a course, import a PDF, wait for **Ready**, open it, and search for words from its text. Sign out, restart, and sign in again: the server retains the same documents. A valid saved token also restores your profile automatically after app restart.

The emulator reaches the Windows host through `10.0.2.2`. `localhost` inside Android is the emulator itself. Debug HTTP is permitted only for `10.0.2.2`, `127.0.0.1`, and `localhost`; release builds require an explicitly configured HTTPS URL. The main manifest disallows cleartext and Android backups; the debug-only network-security resource adds the local exceptions. No firewall changes are performed.

On this workstation, another service already occupies port 8080. The verified setup uses 8081 instead:

```powershell
# Server terminal, from backend/:
$env:PORT = '8081'
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-dev.ps1
# Flutter terminal, from repository root:
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8081
```

Explicit offline demo:

```powershell
flutter run --dart-define=DEMO_MODE=true
```

The demo remains in-memory and clearly labeled. Failed server requests never switch to demo data. Connected semantic search and Ask AI require the local models: run `./setup-ai.ps1` once. In connected mode, dashboard course counts/cards use server data; learning hours, progress and exam planning are not yet implemented. Password recovery is explicitly unavailable.

## Environment

| Variable | Meaning |
| --- | --- |
| JWT_SECRET | Required signing secret; at least 32 characters. Never put it in Flutter. |
| HOST | Bind address, default `127.0.0.1`. |
| PORT | Port, default `8080`. |
| BACKEND_ROOT | Persistent data/storage root, default working directory. Start from backend so migrations resolve. |
| API_BASE_URL | Flutter dart-define; default debug emulator URL. Production must use HTTPS. |
| DEMO_MODE | Flutter dart-define, default false. |

## Layers and files

- `bin/server.dart`: startup and graceful shutdown.
- `routes/`: Dart Frog auth, users, courses, documents, search, RAG and health handlers; `_middleware.dart` injects the application.
- `lib/src/http/application.dart`: bounded JSON/multipart HTTP decoding, identity checks, endpoint dispatch and centralized errors.
- `lib/src/http/api_error.dart`: errors and input-field validation.
- `lib/src/config/config.dart`: validated server configuration.
- `lib/src/security/auth.dart`: bcrypt hashing in isolates, JWT issue/verification and profile updates.
- `lib/src/database/database.dart`: persistent SQLite connection and migrations.
- `lib/src/repositories/store.dart`: parameterized SQLite access, ownership lookups and response mapping.
- `lib/src/services/course_service.dart`: course/document operations, PDF queue, cleanup, keyword retrieval.
- `lib/src/services/pdf_service.dart`: real PDFium extraction and page-aware chunks.
- `lib/src/services/rag_contracts.dart`: injectable server-side RAG provider contract.
- `lib/src/services/ollama_provider.dart`: bounded local Ollama HTTP requests, embeddings and structured answer generation.
- `lib/src/services/rag_service.dart`: queued indexing, persisted cosine retrieval, ownership and citation validation.
- `migrations/001_initial.sql`: initial schema.
- `test/api_test.dart`: real HTTP server and temporary SQLite/PDF storage tests.
- `start-dev.ps1`: local startup and persistent development secret.

Existing Flutter screens are preserved. Integration changes are in `lib/core/network/api_config.dart`, `lib/features/auth/data/auth_api.dart`, `SessionController`, `Student`, app composition, auth/profile/dashboard screens and the existing `CoursesApiService`. `flutter_secure_storage` stores only the access token, never the password. Existing demo widget tests explicitly choose demo mode. `test/features/auth_api_test.dart` tests connected session behavior and unavailable RAG.

## Database and files

`data/studymate.db` is created on first startup and never deleted on normal restart. Migration version is `PRAGMA user_version=2`; the incremental migration adds embeddings without replacing existing accounts or PDFs. Foreign keys, WAL, a five-second busy timeout, parameterized statements, unique constraints, owner/document indexes and explicit write transactions are enabled.

| Table | Purpose |
| --- | --- |
| users | UUID, normalized unique email, bcrypt hash, name, academic level, specialty, timestamps. |
| subjects | Unique subject names and UUIDs. |
| user_subjects | Student/subject relationship. |
| courses | Owner UUID, title, subject, description, timestamps. |
| documents | Course UUID, original/safe filename, storage path, MIME, size, SHA-256, status, page count, error, timestamps. |
| document_chunks | Document UUID, original page, chunk index, exact normalized text, timestamp. |
| file_cleanup | Durable retry queue for physical deletion after database transactions. |
| chunk_fts | FTS5 virtual index maintained by insert/delete triggers when available. |

PDF binaries are stored in `storage/pdfs/<random-uuid>.pdf`, never in SQLite. All downloads and metadata requests check document ownership through its course. Client-supplied filenames are display metadata only; no user path is used to open or delete files. SHA-256 prevents duplicate files within the same course. Course deletion cascades through documents/chunks and schedules filesystem cleanup in the same transaction. Failed physical deletions are retried at the next startup; an in-flight extraction cannot recreate a deleted document.

Back up the database and PDF directory together while the server is stopped. If backing up a running SQLite database, use SQLite's backup API rather than copying only the main DB file and ignoring WAL. This development implementation has no automatic backup or orphan-file garbage collector; a hard crash between file write and metadata insertion can leave an unreferenced PDF.

## Authentication

Registration hashes passwords with bcrypt cost 12. Passwords must be at least 8 characters and at most 72 UTF-8 bytes. Email is trimmed, lowercased and unique. Access tokens use HS256, verified signature, issuer, subject and required expiration; lifetime is 30 minutes. No refresh-token endpoint is provided. Authentication endpoints have a basic in-process limit of 20 requests/minute/IP; deploy behind a properly configured TLS reverse proxy with stronger rate controls before public exposure.

Flutter signs out by deleting its stored JWT. **Logout does not revoke an already issued token**; it remains usable until expiry. No token blacklist, password recovery, email verification or account deletion endpoint is implemented. HTTPS is mandatory for deployment. The backend has no seeded demo credentials, and never trusts a supplied user ID for authorization.

## REST contract

Every route except auth and health requires `Authorization: Bearer <accessToken>`.

| Method | Path | Result |
| --- | --- | --- |
| POST | /api/auth/register | 201 `{accessToken, tokenType, expiresIn, user}` |
| POST | /api/auth/login | 200 same session structure |
| GET / PUT | /api/users/me | Authenticated profile |
| GET / POST | /api/courses | Course array / created course |
| GET / PUT / DELETE | /api/courses/{id} | Course / updated course / 204 |
| GET / POST | /api/courses/{id}/documents | Document array / multipart upload 201 |
| GET / DELETE | /api/documents/{id} | Metadata / 204 |
| GET | /api/documents/{id}/status | Current document metadata |
| GET | /api/documents/{id}/content | Authenticated application/pdf bytes |
| POST | /api/documents/{id}/retry | 202 accepted; 409 if processing/already ready |
| POST | /api/courses/search | Exact source passage array |
| GET / POST | /api/courses/{id}/index | Index progress / enqueue missing embeddings |
| POST | /api/rag/ask | `{answer, sources, generated}` with validated source references |

Profile: `{id, fullName, email, academicLevel, specialty, subjects}`. Profile updates accept fullName, academicLevel, specialty and a list of up to 20 subject names. Email changes are not supported.

Course: `{id, title, subject, description, updatedAt}`. Create/update requires title and subject; description is optional. IDs are UUID strings; timestamps are UTC ISO-8601.

Document: `{id, courseId, name, size, status, uploadedAt, pages, error}`. `pages` and `error` may be null. `error` can also contain a warning about non-searchable pages on a Ready document.

Search body: `{courseId, query, topK: 5, mode: "semantic"}`; topK is 1–20. Omitted mode retains keyword search for compatibility. Response items: `{chunkId, documentId, courseId, documentName, page, excerpt, score}`. Semantic score is cosine similarity; keyword score is an FTS ranking value. Neither is a confidence percentage. FTS5 queries use quoted words combined with OR, not raw user-supplied syntax.

Errors use `{status, code, message, timestamp}`. Common statuses: 400 malformed/validation, 401 missing/expired JWT or invalid credentials, 404 absent or inaccessible resource, 409 duplicate email/PDF or processing conflict, 413 oversized body, 415 wrong JSON content type, 429 rate limit, 501 RAG unavailable, 503 upload concurrency limit, 500 unexpected storage/database failure. Internal exceptions and credentials are not sent to clients.

## Example requests (PowerShell)

Use fictional development details and replace the example password before real use:

```powershell
$base = 'http://localhost:8080'
$registration = @{
  fullName='Alex Student'; email='alex@example.com'; password='ExampleOnly123!'
  academicLevel='Bachelor 3'; specialty='Computer Science'; subjects=@('Artificial Intelligence')
} | ConvertTo-Json
$session = Invoke-RestMethod "$base/api/auth/register" -Method Post -ContentType 'application/json' -Body $registration
$login = @{email='alex@example.com';password='ExampleOnly123!'} | ConvertTo-Json
$session = Invoke-RestMethod "$base/api/auth/login" -Method Post -ContentType 'application/json' -Body $login
$headers = @{Authorization="Bearer $($session.accessToken)"}
$body = @{title='Machine Learning';subject='Artificial Intelligence';description='Lecture notes'} | ConvertTo-Json
$course = Invoke-RestMethod "$base/api/courses" -Method Post -Headers $headers -ContentType 'application/json' -Body $body
# PowerShell 7 multipart upload:
Invoke-RestMethod "$base/api/courses/$($course.id)/documents" -Method Post -Headers $headers -Form @{file=Get-Item './lecture.pdf'}
```

## PDF processing and limits

Multipart field `file`, one PDF, 20 MB maximum, extension and `%PDF-` header validation. Request reading is bounded and has a 30-second idle timeout; two uploads may be read concurrently. Saved files start Uploaded, enter a serial processing queue, then Processing and Ready or Failed. Up to 250 pages / 1,000,000 extracted characters per PDF are indexed. PDFium from `pdfrx_engine` performs real page-level extraction on Windows; chunks normalize whitespace and split near 900 characters without crossing pages. Text is saved only after successful extraction, transactionally.

Encrypted/damaged documents fail while their original files remain downloadable. Image-only PDFs fail with an OCR-unavailable message. Documents with some blank pages remain searchable with a warning. Interrupted PDF jobs are marked Failed at startup and can be retried. Ready PDFs are queued for semantic indexing; AI failures do not discard extracted text. Indexing resumes from persisted vectors on the next search. OCR remains outside this module.

This is a local single-process service, not a hardened multi-tenant deployment: no storage quotas/pagination, distributed queue, PDF sandbox worker with hard CPU timeout, or automated antivirus scanning. Native extraction is bounded by pages/text but a pathological PDF can still require process restart. Add these controls, HTTPS termination, monitoring and backups before exposing it publicly.

## Checks

```powershell
cd backend
dart analyze
dart test
cd ..
flutter analyze lib test
flutter test
flutter build apk --debug
```

Backend tests create temporary databases and directories, use a real HTTP server and PDFium, and never touch `backend/data/studymate.db`. Tests cover migration, registration, normalized duplicate email, bcrypt, login, JWT tampering/expiry, profile persistence, course CRUD/isolation, multipart upload/validation/duplicate detection, PDF download, real extraction/chunks/search, failed processing/retry, deletion cleanup and reopening the persisted database.

Full `flutter analyze` also visits the independent legacy `template_reference` app, whose unresolved packages/outdated APIs predate this work. Scoped Flutter analysis and separate backend analysis are the relevant module checks. Exact validation results are recorded below after execution.

## Common problems

- Connection refused: start the backend, check `/health`, use 10.0.2.2 on Android, verify port 8080 is free.
- JWT_SECRET error: use start-dev.ps1 or provide a strong secret; do not put secrets into source.
- 401 after 30 minutes: sign out and sign in again; no refresh tokens are implemented.
- 409 PDF: the same file already exists in that course.
- Failed PDF: inspect its error, retry if appropriate; image-only documents need future OCR.
- Windows symlink warning during Flutter package installation: dependency resolution may still complete; Android builds were checked. Desktop builds can require Windows Developer Mode, which this project does not enable automatically.
- Native asset download failure: allow package downloads on first run; keep SDK/package versions consistent with lockfiles.

## Local RAG

Run `./setup-ai.ps1` to download `embeddinggemma:300m` and `qwen3:4b`. Ollama listens on loopback port 11434; Flutter only calls the authenticated Dart backend. Set `OLLAMA_BASE_URL`, `OLLAMA_EMBED_MODEL`, `OLLAMA_CHAT_MODEL` in the server environment to override defaults, or `RAG_ENABLED=false` to disable AI. Run `dart run bin/verify_rag.dart` with the backend stopped for a real-model end-to-end validation in temporary storage. Windows cannot rebuild the shared SQLite native library while the development server holds it open.

See [Smart Courses and RAG](../docs/courses_rag.md) for the detailed contract, limits and test coverage. Citation validation proves that references exist and quoted text matches; it does not prove every generated claim is correct.

References: [Dart Frog](https://pub.dev/packages/dart_frog), [SQLite Dart bindings](https://pub.dev/packages/sqlite3), [bcrypt](https://pub.dev/packages/bcrypt), [PDF engine](https://pub.dev/packages/pdfrx_engine), [secure token storage](https://pub.dev/packages/flutter_secure_storage).
