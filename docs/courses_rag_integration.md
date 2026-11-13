# Smart Courses & RAG — team integration

## 1. Module and review scope

This branch provides Flutter course/subject organization, native PDF selection and viewing, a Dart Frog REST backend, persistent SQLite metadata/chunks/vectors, local Ollama embeddings and answer generation, semantic search, and citations that open original PDF pages. Connected mode is the default. The explicit demo mode is in-memory and uses keyword retrieval only.

Read [the audit](courses_rag_audit_report.md) before describing the module as complete. This is a reviewable working implementation with known limitations, not a claim of 100% correctness or production readiness. No new features were added during publication preparation.

## 2. Prerequisites and checkout

- Git, Flutter 3.47.0 or newer with Dart satisfying `^3.13.4`, and an Android SDK/emulator (see the committed lockfile SDK constraints). Use the team's matching SDK; validation used Dart 3.13.5. Check `flutter --version` and `flutter doctor` locally.
- Windows PowerShell for the startup scripts below; PowerShell 7 for the optional multipart HTTP example in the backend README.
- Install Ollama from [the official download page](https://ollama.com/download). Allow sufficient disk and memory for both models; first dependency/native-library/model downloads require Internet.
- No cloud AI account, provider API key, existing database, or pre-seeded student is required.

Fresh checkout (do not run checkout over another developer's unsaved work):

```powershell
git clone --branch feature/courses-rag https://github.com/gamemakerzzz/Project_Flutter_5SAE10_GRP4.git
cd Project_Flutter_5SAE10_GRP4
flutter pub get
Push-Location backend
dart pub get
Pop-Location
```

Keep both `pubspec.lock` files. They pin application/backend dependency versions. Do not copy `.dart_tool`, SDK caches, installed models, or another person's local SQLite/PDF storage.

## 3. Flutter architecture

`lib/main.dart` starts `StudyMateApp`. `SessionController`/`AuthApi` restore or create the authenticated session. `StudentShell` owns the session's `CoursesViewModel` and wires `CoursesApiService` with the shared API URL and token provider. Screens forward actions to view models; repositories handle data access. Disposing the shell disposes polling and HTTP clients.

The courses feature contains the editor/library/detail screens, native file import, PDF viewer, semantic search, RAG chat, and source-reference cards. `SourcePassage` carries course/document/chunk/page identity. `LocalCoursesRepository` is only for explicitly selected demo mode. Theme/shared widgets and the connected dashboard/profile/auth screens are necessary dependencies of the existing app composition; they are included rather than leaving unresolved imports.

## 4. Backend architecture and SQLite initialization

- `backend/bin/server.dart`: executable Dart Frog server.
- `routes/`: conventional route adapters; `_middleware.dart` injects the shared application.
- `lib/src/http/application.dart`: bounded requests, dispatch, identity/ownership and error responses.
- `security/auth.dart`: bcrypt, JWT and profile integration.
- `repositories/store.dart`, `database/database.dart`: parameterized SQLite queries and migration runner.
- `services/course_service.dart`, `pdf_service.dart`: course/document CRUD, file storage, PDFium extraction, queued processing and page-aware chunks.
- `services/ollama_provider.dart`, `rag_service.dart`: embeddings, persisted vectors, cosine ranking, LLM calls and citation validation.

Starting from `backend/` creates `data/studymate.db` and `storage/pdfs/` automatically. Migrations `001_initial.sql` and `002_embeddings.sql` apply transactionally to schema version 2. Foreign keys, WAL and ownership constraints are enabled. There is no database to import from this branch. Migration 002 preserves existing data while adding vectors.

Run one backend process per data/storage root. Back up the database and PDF directory together; do not delete them as a routine reset or copy a live WAL database incorrectly. The tests create isolated temporary roots and do not delete development data.

## 5. Start Ollama and download the required models

Start the installed Ollama application/service. If it is not already serving, run this in its own terminal and keep it running:

```powershell
ollama serve
```

In another terminal, download models once:

```powershell
ollama pull embeddinggemma:300m
ollama pull qwen3:4b
ollama list
```

Alternatively, from the repository root on Windows:

```powershell
cd backend
.\setup-ai.ps1
```

The helper starts local Ollama if needed and downloads those same models. EmbeddingGemma generates document/query vectors; Qwen3 generates answers. Ollama must remain reachable at `http://127.0.0.1:11434`. Installed models are not committed to Git. Model inference is local after download.

## 6. Start the backend

From the repository root in a separate PowerShell terminal:

```powershell
cd backend
dart pub get
$env:PORT = '8081'
.\start-dev.ps1
```

If script execution is restricted, invoke the same script with a process-scoped policy rather than changing machine policy:

```powershell
$env:PORT = '8081'
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-dev.ps1
```

`start-dev.ps1` creates a random local signing secret once in ignored `backend/data/jwt-secret.txt`, binds loopback, uses `backend/` as the persistent root, and runs `dart run bin/server.dart`. Retain the secret locally across restarts; never share or commit it. The script defaults to port 8080 when `PORT` is absent; this guide consistently selects 8081 for server and app.

Check readiness from another terminal:

```powershell
Invoke-RestMethod http://127.0.0.1:8081/health
```

Expected: `status` is `ok`. This proves server availability, not that AI models are present. Missing/stopped models produce explicit AI errors when indexing/searching/generating.

On other platforms, start from `backend/` with a securely generated process-environment `JWT_SECRET` (at least 32 characters), `PORT=8081`, and run `dart run bin/server.dart`. No `.env` loader is installed; do not expect copying `.env.example` to configure the process.

## 7. Environment variables

| Variable | Scope and behavior |
|---|---|
| `JWT_SECRET` | Required by direct server startup; generated/read by Windows startup script. Backend only. |
| `HOST` | Backend default `127.0.0.1`; startup script enforces loopback. |
| `PORT` | Backend default 8080; this guide uses 8081. |
| `BACKEND_ROOT` | Data/storage root for direct startup; Windows helper sets it to its own backend directory. Migration sources resolve from backend working directory. |
| `OLLAMA_BASE_URL` | Default `http://127.0.0.1:11434`; only local HTTP loopback addresses are accepted. |
| `OLLAMA_EMBED_MODEL` | Default `embeddinggemma:300m`. |
| `OLLAMA_CHAT_MODEL` | Default `qwen3:4b`. |
| `RAG_ENABLED` | Default enabled; `false` disables AI explicitly. Does not enable demo fallback. |
| `API_BASE_URL` | Flutter compile-time `--dart-define`, not a backend environment variable. |
| `DEMO_MODE` | Flutter compile-time boolean; default false. `true` selects the separate in-memory demo. |

`backend/.env.example` contains only configuration examples, no signing secret. No provider credential belongs in Flutter or Git.

## 8. Start Flutter on Android

Launch an Android emulator through Android Studio, then from the repository root:

```powershell
flutter devices
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8081
```

Replace `emulator-5554` with the ID printed by `flutter devices`. Android's `10.0.2.2` reaches the host computer; `localhost` inside the emulator does not. Keep **both Dart backend and Ollama running**. The app must be rebuilt/relaunched when changing a dart-define.

The debug network-security configuration permits HTTP only to `10.0.2.2`, `127.0.0.1` and `localhost`. Release requires HTTPS. A physical device cannot use the emulator host alias: use an appropriately secured reachable HTTPS backend, or a deliberate developer-only adb reverse setup. The physical-device setup was not validated by this audit.

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8081
```

Build output is ignored. The earlier audit used port 18081 with temporary data; do not copy that audit endpoint unless intentionally running that isolated server.

## 9. Main REST endpoints

All routes except health/register/login require `Authorization: Bearer <accessToken>`.

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Backend health |
| POST | `/api/auth/register`, `/api/auth/login` | Real account/session |
| GET / PUT | `/api/users/me` | Shared authenticated profile |
| GET / POST | `/api/courses` | List/create owned courses |
| GET / PUT / DELETE | `/api/courses/{id}` | Owned course CRUD |
| GET / POST | `/api/courses/{id}/documents` | List/upload; multipart field `file` |
| GET / DELETE | `/api/documents/{id}` | Metadata/delete |
| GET | `/api/documents/{id}/status`, `/api/documents/{id}/content` | Processing state/authenticated PDF bytes |
| POST | `/api/documents/{id}/retry` | Retry failed extraction |
| GET / POST | `/api/courses/{id}/index` | Index progress/start or resume |
| POST | `/api/courses/search` | `{courseId, query, topK: 5, mode: "semantic"}` |
| POST | `/api/rag/ask` | `{courseId, question}` → `{answer, sources, generated}` |

Omitted search mode selects legacy keyword search, not semantic search. Source responses include document/course/chunk IDs, original page, excerpt and score; RAG also supplies source numbers. See [backend contracts](../backend/README.md) and [RAG guide](courses_rag.md).

Common failures: 401 missing/expired session; 404 missing/foreign-owned resource; 409 duplicate or indexing conflict; 413 upload/index limits; 501 AI disabled; 503 model/service unavailable; 504 AI timeout; 502 malformed provider response. No fabricated answer replaces an unavailable provider.

## 10. PDF and RAG smoke test

1. Register your own local test account; no real student credentials are shipped.
2. Open Courses, create a subject label and a course, and import a selectable-text PDF you are permitted to use (up to 20 MiB).
3. Wait for extraction to become Ready. PDF readiness and AI-index readiness are separate; first search can wait for indexing.
4. Search using a paraphrase of a known passage. Confirm semantic results reference the uploaded document and original page.
5. Ask a question answered by that passage. Compare the answer and exact source excerpt, then use **Open source page**.
6. Ask an unrelated question and verify insufficient-context behavior; do not infer universal accuracy from one successful answer.
7. Log out, restart app/backend, log back in and verify documents remain. Register another local account and verify it cannot see the first account's materials.

Reproducible checks from the repository root:

```powershell
flutter analyze lib test
flutter test
Push-Location backend
dart analyze
dart test
dart run bin/verify_rag.dart
Pop-Location
```

Stop the development backend before Dart native-asset rebuilds/tests on Windows if it holds the SQLite DLL open. Keep Ollama running for `verify_rag.dart`. The verification script uses real models, a synthetic PDF, temporary accounts/storage and an HTTP server. Backend/Flutter regular tests also include deterministic provider/mock cases; they are not all real-model quality tests. Keep the root `test/features/courses/pdf_fixture.dart`: backend tests and the real-model verifier import it, so use the whole repository checkout, not only a copied `backend/` directory.

Full `flutter analyze` traverses the unrelated legacy `template_reference` app and currently reports its unresolved/obsolete dependencies. Use the scoped Flutter command above plus separate backend analysis.

## 11. Required shared Auth/Profile integration

Keep `AuthApi`, secure token storage, `SessionController`, `Student`, shared theme/widgets and the `StudentShell` repository lifecycle together when integrating. Backend ownership derives from the verified JWT, not a client-supplied user ID. Use the same API URL for auth and courses. Do not replace a failed connected request with demo data.

The dashboard consumes actual saved courses in connected mode; study hours/progress and other teammates' modules are not implemented here. Demo fixtures remain dependencies of the explicit demo path and its tests. Course subject labels are independent of profile subject preferences. Preserve teammates' newer auth/navigation changes by adapting this wiring during review, not by copying this branch's entire `lib/` over theirs.

## 12. Known limitations and integration procedure

Known limits: no OCR, 250 pages / one million extracted characters per PDF, approximate 900-unit chunks, 5,000 chunks/course, exact in-memory cosine scan, local single-process queues, no persisted chat history, 30-minute JWT without refresh/revocation, and no password recovery. Citation validation checks existence/quotes/markers, not every claim's truth. Sentence-aware chunking, token-aware context assembly and broader PDF/adversarial evaluation remain audit follow-ups. See the audit for executed versus unexecuted cases.

Repository README conventions identify **`main`** as the PR integration target. Submit `feature/courses-rag` for review into `main`; do not merge automatically. Review shared auth/profile/dashboard/navigation changes carefully alongside other feature branches. Do not overwrite the separate quiz/exam implementation.

For an existing clean reviewer checkout:

```powershell
git fetch origin
git switch --track origin/feature/courses-rag
```

If the local branch already exists, switch to it and inspect divergence before updating; do not reset or force-push. Review the full diff, resolve any shared-file conflicts deliberately on an integration branch/PR, resolve dependencies in both packages, run scoped analyses/tests and the APK build, then repeat the PDF/RAG smoke test. Merging is a teammate/reviewer action after review, not part of publishing this branch.

Excluded from publication: local SQLite databases/WAL files, JWT secret files, runtime PDF storage, real `.env`, model installations, cache/build/APK output, the loose root PDF, and the unrelated `pec.yaml` scratch file. Checked-in platform plugin registration sources are retained as normal Flutter source integration; they are not binary build artifacts.
