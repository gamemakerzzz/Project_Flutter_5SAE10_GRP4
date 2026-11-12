# feat: Smart Courses & RAG — Flutter + Dart Frog + SQLite + Ollama

Base: `main` (repository README integration convention). Head: `feature/courses-rag`.

## Summary

Connect the Flutter course workspace to persistent, authenticated course ingestion and local RAG. A student can create a course/subject, select a PDF, retrieve its passages by meaning, ask a question, and follow verified source references to the original PDF page. This replaces the baseline placeholder application with the existing integrated module and its required shared app/auth/profile/dashboard wiring.

## Included

- Course/document CRUD, native PDF import/viewing, processing states, semantic search and RAG chat.
- Dart Frog HTTP routes/services, bcrypt/JWT authentication, ownership checks, bounded uploads and error handling.
- SQLite migrations, persistent users/courses/documents/chunks/vectors, filesystem PDF storage and deletion cleanup.
- PDFium extraction and page-aware chunking; Ollama embeddings, cosine retrieval, structured answers and citation validation.
- Dependency manifests/lockfiles, Android debug networking, necessary checked-in platform plugin registration sources, tests, synthetic fixtures and audit evidence.
- Existing audit fixes for custom subjects, index-limit messages, overflowing citation numbers and Unicode chunk boundaries.

No new feature development was performed for publication. Other learning modules remain separate; do not replace teammates' implementations wholesale when resolving shared-file conflicts.

## Setup and integration

Follow [the integration guide](https://github.com/gamemakerzzz/Project_Flutter_5SAE10_GRP4/blob/feature/courses-rag/docs/courses_rag_integration.md). Install Ollama and download:

```sh
ollama pull embeddinggemma:300m
ollama pull qwen3:4b
```

Keep Ollama serving on loopback and the Dart backend running. From `backend/`, run `dart pub get`, set `PORT=8081` in the process environment, then run `start-dev.ps1` on Windows. It creates a local ignored JWT secret and initializes SQLite/migrations automatically; no pre-existing database or seeded credentials are needed. For direct startup, supply a strong `JWT_SECRET` and run `dart run bin/server.dart` from `backend/`.

From the repository root, run `flutter pub get` and `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8081` (replace the device ID as needed). `.env.example` is documentation, not an automatically loaded configuration. Release requires HTTPS. Preserve the shared `AuthApi`/`SessionController` token provider and repository disposal lifecycle; backend authorization never trusts a client user ID.

## Validation

Fresh publication checks:

- `flutter pub get`: passed.
- `flutter analyze lib test`: passed, no issues.
- `flutter test`: **30 passed**.
- `dart pub get` and `dart analyze` in `backend/`: passed.
- `dart test` in `backend/`: **18 passed** after stopping the prior temporary audit server to release the Windows SQLite DLL. The initial locked-DLL attempt did not execute the suite successfully.
- `flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8081`: passed.

The preceding audit also executed real Ollama RAG and Android native upload, generated citation → PDF page navigation, logout/app/backend restart persistence, and real HTTP cross-user isolation. These are historical audit results, not claimed as rerun during publication. Full-repository analysis has known failures in the unrelated legacy `template_reference` application; use separate scoped app/backend checks.

## Known limitations / review risks

- The audit verdict is **not 100% complete**. Paragraph/sentence-aware chunking, tokenizer-aware context assembly, broader PDF edge cases, and adversarial/claim-support validation remain follow-ups.
- No OCR, chat persistence, refresh tokens, logout revocation, or password recovery. Native PDF parsing has no hard worker timeout. This is a single-process local service, not a hardened public deployment.
- Citation checks verify real source identity/quotes/markers, not every generated claim's truth.
- Both packages require a compatible modern Dart/Flutter SDK; backend test fixtures are shared with the root test directory, so retain the full repository checkout.
- Shared auth/profile/dashboard/navigation changes require coordinated review alongside teammates' branches. No teammate branch was merged or overwritten, and this PR must not auto-merge.

See [the detailed audit report](https://github.com/gamemakerzzz/Project_Flutter_5SAE10_GRP4/blob/feature/courses-rag/docs/courses_rag_audit_report.md) for the compliance matrix and test limitations. Local databases, JWT secrets, private uploads, installed models, caches, APKs, the loose root PDF and unrelated scratch file are intentionally excluded.
