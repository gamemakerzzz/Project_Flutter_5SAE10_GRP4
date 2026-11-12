# Smart Courses & RAG — technical and functional audit

Audit date: **12 November 2026** (Europe/London). Repository branch: **`feature/courses-rag`**.

## Executive assessment

**Is my Smart Courses & RAG module fully complete according to the official assignment? NO — not yet certifiable as 100% complete.**

This is a functioning implementation, not a decorative UI or a keyword-search demonstration. Real Android upload, PDFium extraction, SQLite persistence, Ollama embeddings, cosine search, LLM generation, and navigation from a generated citation to PDF page 2 were executed successfully. The course and PDF survived logout, Android process restart, backend process restart, and login. Cross-user HTTP access was denied.

The remaining concerns are narrower than “RAG is missing”: segmentation is based on whitespace/character limits rather than meaningful paragraph/sentence boundaries; context assembly has no tokenizer-aware budget; citation validation establishes provenance but does not validate the support for every generated claim. PDF extraction edge-case coverage is incomplete. These prevent an unconditional correctness/completion claim under the requested audit standard. No unavailable credential or absent model currently blocks the core pipeline.

**Final checks:** backend analysis clean; **18 backend tests passed**; scoped Flutter analysis clean; **30 Flutter tests passed**; Android debug APK built and installed. Full-repository Flutter analysis failed with **1,783 issues in `template_reference`**, the independent legacy application. No percentage is assigned: these requirements have different scope, and passing a representative journey is not a defensible percentage of total correctness.

## Baseline, scope, and evidence handling

- Inspected the actual local source, dependencies, routes, migrations, authentication/profile integration, tests, README, architecture, API contracts, and previous implementation notes before changing code.
- `git branch --show-current` returned `feature/courses-rag`. `git status --short` showed extensive pre-existing modified and untracked work, including essentially the entire backend and courses implementation. This work was preserved. No branch switch, reset, merge, commit, or push was performed.
- No applicable `AGENTS.md` was found in the repository inspection or checked ancestor directories. No subagents were used.
- Installed Dart reported **3.13.5**. Android testing used **`emulator-5554`**, the existing Medium Phone API 37.0 emulator. A physical Android device was not tested.
- Ollama was initially stopped. Both configured models were already installed: `embeddinggemma:300m` and `qwen3:4b`. Started the existing local service; did not buy services, download new models, or use cloud credentials.
- Tests used dedicated temporary storage. The manual Android audit used a unique `studymate-audit-*` directory under the operating system temporary directory, with a separate backend at `127.0.0.1:18081`. It did not use `backend/data/studymate.db` or development PDFs. The machine-specific absolute path was removed for publication.
- Synthetic accounts were `audit-a@example.com` and `audit-b@example.com`. The PDF was generated from the repository's two-page test fixture. Existing emulator files and application data were not cleared.
- The APK was built with `API_BASE_URL=http://10.0.2.2:18081`; this is the **audit endpoint**, not a deployment configuration.
- At the audit handoff, the isolated audit backend and local Ollama service were left running for the emulator demonstration. During subsequent publication checks, that temporary backend was stopped to release its SQLite DLL; its data was preserved. Use the normal backend setup and rebuild with its intended URL when returning to development. No teammate should depend on that temporary audit environment.
- [HTTP persistence/isolation evidence](audit_evidence/http_checks.json) contains response statuses and assertions, without tokens or passwords. [Android citation screenshot](audit_evidence/android_citation_page_2.png) shows the actual source text and **Page 2 / 2**.

## A. Requirements compliance matrix

`COMPLETE` means the named capability exists and passed the stated representative tests. It does not mean exhaustive verification of every possible input. `PARTIAL` identifies a specific implementation or verification limitation. No core capability is classified as missing merely because a deterministic test substitutes an AI provider; real-model tests are identified separately.

| Requirement | Status | Evidence | Test result | Remaining work |
|---|---|---|---|---|
| PDF import | COMPLETE | `PdfImportService.pick`, `PdfValidation`, `Application.upload`, `CourseService.upload` | Native Android picker and multipart upload passed; real PDF stored/downloaded; invalid extension/signature, oversized upload, duplicate, and foreign-owner checks passed | Broaden platform coverage; no claim of malware-proof native parsing |
| Course organization | COMPLETE | `CourseEditorScreen`, `CoursesViewModel`, `CourseService.save/deleteCourse`, owner-scoped queries | Custom subject and course created on Android; edit regression passed; HTTP CRUD/ownership/deletion passed | Subjects are course labels, not a separate course-subject management resource; profile subjects are separate |
| Text extraction | PARTIAL | `PdfService.extract`, `CourseService.process` | Real two-page text PDF, blank PDF, mixed blank/text pages, accented Latin text, corruption failure and retry passed | No OCR; real encrypted and image-only fixtures, complex Unicode fonts, tables/multicolumn reading order, and resource-limit boundaries not executed |
| Chunking | PARTIAL | `pdf_service.dart:38`, frontend `chunkPages`, transactional `document_chunks` writes | Page boundaries, ordering, 900-unit size, no word loss in test text, supplementary Unicode boundary, restart persistence and deletion passed | Sentence/paragraph-aware segmentation and context continuity across chunk boundaries; IDs remain stable while persisted but are regenerated on reprocessing |
| Embeddings | COMPLETE | `OllamaProvider.embed/checkReady`, `RagService._index`, migration 002 | Real **768-dimensional** vectors generated and stored; model/digest namespace, provider error tests, reuse/reindex-on-key-change, deletion tests passed | Large-corpus and model replacement under concurrent traffic not evaluated |
| Semantic search | COMPLETE | `RagService._search`, normalized dot product/cosine, owner/course SQL scope | French query retrieved English page 2; Android query ranked page 2 first; actual uploaded passages returned | Calibrate threshold 0.25 and ranking on representative academic PDFs; current exact scan capped at 5,000 chunks/course |
| Real RAG pipeline | COMPLETE | `RagService.ask`, `OllamaProvider.generate`, `/api/rag/ask`, connected chat | Real query embedding → retrieval → LLM → validated citations executed over HTTP and Android; unrelated question refused | Reliability limitations in the next row remain; this is not a claim that every generated answer is correct |
| Grounded answers / robust RAG behavior | PARTIAL | `rag_service.dart:241–286`, `ollama_provider.dart:187–246` | Known-document English/French answers grounded correctly; invalid citations and deleted sources rejected in deterministic tests | Per-claim support is not checked; no tokenizer-aware context assembly; real adversarial prompt-injection and long-context evaluation absent |
| Source references | COMPLETE | `SourceReferenceCard.open`, `PdfViewerScreen`, DB-rechecked source records | Generated citation matched the stored passage/document/page; Android opened cited page 2 of 2; invalid/foreign/deleted sources rejected | Exact quotations prove provenance, not entailment of every claim; no passage highlighting beyond displayed excerpt |
| SQLite persistence | COMPLETE | `AppDatabase`, migrations 001/002, `Store`, `file_cleanup` | Migration upgrade, reopen, actual process restart, logout/login, unchanged PDF SHA-256, two persisted vectors; integrity `ok`, FK check empty | Crash between file write and DB insert can leave orphan files; backup/quotas/garbage collection remain operational improvements |
| Flutter/backend integration | COMPLETE | `StudyMateApp`, `AuthApi`, `CoursesApiService`, connected view models/screens | Real Android registration, upload, search, chat, PDF navigation, logout/restart/login passed; scoped tests/build passed | Expired sessions require explicit login; no physical-device, iOS, or release-build validation |

### Important distinctions

- Connected semantic search explicitly sends `mode: "semantic"` and uses query/document embeddings. The backend also supports a separate FTS5/keyword mode for compatibility. That mode is **not** counted as semantic search.
- `LocalCoursesRepository` is an explicitly selected in-memory demo with keyword retrieval and no generated RAG answers. It is **not** evidence of persistent storage or real AI.
- The provider contract/protocol tests use deterministic vectors and an HTTP stub. The successful `bin/verify_rag.dart` run and Android journey used the installed real models.
- A textless document is rejected with an OCR explanation. This is honest failure handling, not successful extraction. Whether OCR is required for grading should be settled against the evaluator's supported-document scope; OCR was not silently added to the official eight-item list.

## B. Technical audit

### Architecture and backend

The backend is a real Dart package with Dart Frog dependencies, conventional `routes/`, dependency injection in `_middleware.dart`, and an executable `bin/server.dart` using Dart Frog `serve`. Route files delegate to the shared `Application`. HTTP decoding/dispatch, auth, repository access, PDF processing, and RAG services are separated.

The tested startup route was `dart run bin/server.dart`, not the optional Dart Frog development CLI. The centralized dispatcher is sizeable and method errors usually return 404 rather than a uniform 405. These are maintainability/API consistency issues, not evidence of missing endpoints.

JSON bodies are bounded to 32 KiB; multipart requests are bounded, one file is accepted, PDF size is limited to 20 MiB, and upload concurrency is limited. File names supplied by clients are metadata; actual storage names are random UUIDs constrained by a server-side pattern. Processing is queued serially and exposes uploaded/processing/ready/failed states. A failed PDF remains downloadable and can be retried. Restart marks interrupted PDF jobs failed. AI failure does not erase extracted text.

RAG indexing uses batches of eight, persisted normalized vectors, model name/digest/version keys, queued work, concurrency limits, and explicit failures. Different embedding keys cause missing vectors to be regenerated. Searches check ownership before AI calls and select only ready documents belonging to the requested course/user. Deletion during async embedding/generation is rechecked, preventing deleted sources from being recreated or cited.

### Frontend

My Courses, Course Details, editor, native upload, PDF viewer, semantic search, and Ask AI have connected actions rather than decorative buttons. Loading, empty, failure, retry, processing, and unavailable-provider states exist. The course editor now accepts a custom subject without a dropdown assertion. The native picker selected the synthetic file from Android Downloads.

View models protect against stale refresh results and disposed sessions. `CoursesApiService` sends bearer tokens, waits for indexing, validates source metadata against course documents, and does not fall back to demo success. Source navigation passes the original page to `PdfViewer.data(initialPageNumber: ...)`. The source excerpt is separately visible in the viewer.

Small-screen/dark-theme behavior is covered by widget tests. Actual emulator rendering and citation navigation were inspected. Rotation, accessibility completeness, physical-device storage providers, very long filenames, and iOS were not exhaustively tested. The profile's subject choices and course subject labels are independent; creating a course subject does not add a profile subject automatically.

### SQLite and filesystem

Schema version 2 is real and persisted. Tables include users, subjects, user_subjects, courses, documents, document_chunks, chunk_embeddings, and file_cleanup; FTS5 is created opportunistically. Foreign keys, WAL, busy timeout, unique email and per-course PDF hash constraints, chunk position uniqueness, owner/document indexes, and parameterized statements are present. Course/document deletion cascades to chunks/vectors and queues physical deletion in the DB transaction.

The audit database contained two extracted chunks on original pages 1 and 2, with two 768-dimensional vectors under `embeddinggemma:300m/<digest>/retrieval-v1`. SQLite integrity and foreign-key checks passed. PDF bytes after process restart matched the original SHA-256. Schema migration from version 1 preserves an existing account in the executed test.

Storage is single-process. A crash after file write but before metadata insertion can leave an orphan; a failed physical deletion is retried at startup. FTS rebuilds on startup, which can become expensive for larger corpora. These limitations should be documented for deployment rather than misrepresented as absent persistence.

### Security

- Bcrypt cost 12 and 8-character/72-UTF-8-byte password limits are implemented. Hashing runs in isolates; password hashes are not returned in profile JSON.
- JWT HS256 signature, issuer, subject, and required expiration are checked. Tokens expire after 30 minutes. Tampered, absent, and expired tokens were rejected in tests; actual expiry also appeared during the interrupted Android audit.
- Flutter uses `flutter_secure_storage` for the token. Logout removes the locally stored token. Secure storage abstraction tests and real logout/login passed. No hardware-level storage audit was performed.
- User IDs from request bodies are not trusted for course/document ownership. Student B saw `[]`, and foreign course/document/metadata/download/index/search/RAG requests returned 404. Unauthorized deletion returned 404; no-auth course listing returned 401.
- A SQL-looking course title remained ordinary text; tables remained intact. A traversal-looking upload filename was reduced to display basename while physical storage remained inside the temporary PDF directory.
- Errors do not expose provider credentials or raw internal exception messages. `.gitignore` excludes local DB/storage/JWT-secret paths; these exclusions were checked. No live secret values were printed. This was source/configuration review, not an exhaustive Git-history secret scan.
- Local Ollama URLs are restricted to loopback HTTP; redirects are not followed. PDF text is placed in user data, not the system prompt; the model has no tools. Prompt separation is tested with a stub. **Real adversarial injection resistance is not established by that test.**
- Remaining deployment limitations: no JWT revocation on logout, refresh tokens, OCR sandbox worker/hard extraction timeout, per-user storage quotas, antivirus integration, or persistent distributed rate limiting. These are not all part of the official module, but should constrain claims about public deployment readiness.

### Coverage quality

The tests cover actual HTTP/SQLite/PDFium paths as well as deterministic provider and Flutter behavior. The strongest evidence is the additional Android journey plus real Ollama run. Coverage is still scenario-based; no code-coverage percentage or broad retrieval benchmark was measured. Existing notes claiming older passing totals were treated as history, not proof.

## C. Bugs and limitations identified

Line references below refer to the final audited files. For replaced code, the listed location is where the fix now lives.

| ID / severity | File and line | Finding and impact | Action/result |
|---|---|---|---|
| F1 — Medium, fixed | `lib/features/courses/presentation/screens/course_editor_screen.dart:87`; `data/local_courses_repository.dart:47` | The API accepts arbitrary subject labels, but the editor's fixed dropdown could assert when editing such a course. Users also could not create their own subject from the editor. Demo validation rejected the same new input. | Replaced only the subject control with a validated text field, retained the existing visual style, trimmed values, and aligned demo validation. Widget regression and actual Android custom-subject creation passed. |
| F2 — Medium, fixed | `lib/features/courses/data/courses_api_service.dart:72` | Every HTTP 413 was described as an oversized PDF, including `INDEX_LIMIT` from semantic indexing. This sent users toward the wrong remedy. | Preserve the bounded server explanation; use a generic size-limit fallback. Regression passed. |
| F3 — Medium, fixed | `backend/lib/src/services/rag_service.dart:275` | `int.parse` on a very large model-generated citation marker could throw instead of rejecting the unsupported answer; HTTP handling could misclassify provider output as a malformed client request. | Use `int.tryParse`; out-of-range markers fail citation verification. Added oversized-marker case to the invalid-citation test; passed. |
| F4 — Medium, fixed | `backend/lib/src/services/pdf_service.dart:43`; `lib/features/courses/data/pdf_import_service.dart:99` | The hard 900 UTF-16-unit boundary could split a surrogate pair. UTF-8 encoding of the separated chunks could replace the character, corrupting source/embedding text. | Move the boundary before the surrogate pair in both chunkers. Round-trip and reconstruction regression assertions passed. |
| O1 — Medium, open | `backend/lib/src/services/pdf_service.dart:38` | Chunking normalizes all whitespace and splits near a character limit. It can divide a sentence or remove paragraph/list structure; there is no overlap. This only partially satisfies “meaningful chunks” for arbitrary course material. | Implement paragraph/sentence-aware splitting with preserved page metadata; evaluate questions whose evidence spans boundaries. Existing text-conservation tests must remain green. |
| O2 — Medium, open | `backend/lib/src/services/ollama_provider.dart:187` and `:193`; `rag_service.dart:232` | Up to five 900-unit excerpts plus question/system prompt are sent with `num_ctx=4096` and `num_predict=700`, without measuring input tokens. Character limits do not guarantee that multilingual text fits the context. | Add model-appropriate token budgeting and a long-context regression/evaluation corpus. A specific overflow failure was not induced in this audit; this finding is from source inspection. |
| O3 — Medium, open verification gap | `backend/lib/src/services/rag_service.dart:241` and `:259` | Existing quote, source number, and inline marker validation proves provenance. A response containing a valid quotation plus an unsupported factual assertion is not semantically checked. | Evaluate claim support and adversarial documents against a representative corpus; consider per-claim evidence/verification. Do not describe current checks as proof that every sentence is true. No real-model hallucination is alleged from the successful sample. |
| O4 — Medium, open | `backend/lib/src/services/pdf_service.dart:4` and `:26` | No OCR or hard native extraction timeout. The audit did not execute real encrypted/image-only PDFs or complex layout/Unicode-font cases. A pathological native parse can stall the queue. | Add dedicated fixtures and resource-limit tests; use an isolated extraction worker for stronger resilience. OCR requires an explicit supported-document scope decision. |
| O5 — Low, documentation | `docs/module1_frontend.md:5`; `docs/architecture.md:15`; `backend/README.md:155` | Older demo/architecture prose remains alongside newer implementation notes; the documented HTTP 501/503 cases are not uniformly described in all summaries. | Treat current code and this report as evidence. Consolidate obsolete notes in a separate documentation cleanup; unrelated historical prose was preserved. |

## D. Changes made in this audit

The working tree was already dirty; `git diff` against HEAD includes earlier work and is not a list of changes authored by this audit. The audit's changes are:

1. `lib/features/courses/presentation/screens/course_editor_screen.dart` — custom subject entry, validation, controller disposal.
2. `lib/features/courses/data/local_courses_repository.dart` — accept trimmed custom subjects and enforce the server's title/subject/description length limits in demo mode.
3. `lib/features/courses/data/courses_api_service.dart` — retain the real HTTP 413 explanation.
4. `lib/features/courses/data/pdf_import_service.dart` — preserve surrogate pairs at chunk boundaries.
5. `backend/lib/src/services/pdf_service.dart` — same Unicode-preserving boundary fix for persisted backend chunks.
6. `backend/lib/src/services/rag_service.dart` — reject unparseable/overflow citation numbers safely.
7. `test/features/courses/courses_widget_test.dart` — custom-subject edit regression.
8. `test/features/courses/courses_repository_test.dart` — index-limit message regression and Unicode chunk assertions.
9. `test/features/courses/pdf_fixture.dart` — parameterized real PDF fixture with correct dynamic page/font references, Latin-1/WinAnsi text, escaped literal strings, and recalculated xref offsets.
10. `backend/test/api_test.dart` — real blank/mixed/accented PDF upload and extraction, safe filename, SQL-looking title, and Unicode chunk assertions.
11. `backend/test/rag_test.dart` — oversized citation-marker rejection case.
12. `docs/courses_rag_audit_report.md` — this report.
13. `docs/audit_evidence/android_citation_page_2.png` — observed Android citation destination using only synthetic material.
14. `docs/audit_evidence/http_checks.json` — real HTTP isolation and restart evidence without authentication secrets.

Dependency resolution/builds also refresh generated local build/cache outputs. No intentional dependency upgrade, shared authentication redesign, teammate-module change, commit, or push was made. The final debug APK is at `build/app/outputs/flutter-apk/app-debug.apk`.

## E. Executed tests and results

### Commands

Commands ran from the project root unless `backend/` is specified. Windows SDK/cache/local-socket operations required approved execution outside the restricted filesystem/network sandbox.

| Command / procedure | Result |
|---|---|
| `git branch --show-current`; `git status --short`; source/documentation/dependency inspection | Branch verified; pre-existing work preserved |
| `dart --version` via installed SDK executable | Dart 3.13.5 |
| `flutter pub get` | Passed; available newer versions were informational, not upgraded deliberately |
| `dart analyze` in `backend/` | Passed initially and after final fixes, no issues |
| `dart test` in `backend/` | Baseline 17 passed; final **18 passed**, including real HTTP/PDF/SQLite regressions |
| `flutter analyze lib test` | Passed after final fixes, no issues |
| `flutter test` | Final **30 passed** |
| `flutter analyze` | Failed: **1,783 issues**, all reported under `template_reference`; no errors reported outside that legacy tree in the captured output |
| `flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:18081` | Passed; rebuilt after final Unicode fix; installed with `adb install -r` |
| `dart run bin/verify_rag.dart` in `backend/` | Passed with real EmbeddingGemma/Qwen3: PDF extraction, embeddings, cross-language retrieval, generated cited answer, unrelated-question refusal, isolation, DB reopen/vector persistence, vector deletion |
| Android UI through `adb shell input`, native picker, UI hierarchy capture, screenshot | Registration, custom subject/course, native PDF upload, semantic search, RAG answer, citation page navigation, logout, restart, login and restored library observed |
| Real HTTP checks on audit backend before/after distinct process restart | Passed; see JSON evidence |
| SQLite read-only integrity/FK/chunk/vector inspection on audit DB | `integrity_check=ok`, no foreign-key violations, 2 page-aware chunks and 2 vectors of dimension 768 |
| PDF download SHA-256 after restart | Exact match to synthetic uploaded file |
| `dart format` on edited Dart files | Completed; final formatting check reported no further changes |

### Actual real-model observations

- Backend French question returned: `L'apprentissage non supervisé découvre des motifs sans étiquettes [1].`
- Citation pointed to page 2 and the exact persisted excerpt: `Unsupervised learning discovers patterns without labels.`
- Android question `What does unsupervised learning discover` returned `Unsupervised learning discovers patterns without labels [1].`
- Android's citation card displayed document name, page 2, and exact excerpt; its button opened the PDF at **Page 2 / 2**.
- The real-model script refused `What is the capital of Australia?` for these course passages.
- The manual Android search text was `apprendre ans etiquettes` (an adb text-entry typo); page 2 still ranked first. The separate real-model script used the correctly formed French query `Comment apprendre sans etiquettes ?` and also passed. The typo is not concealed as a different executed query.

### Twenty-step integration scenario

This was a **combined manual Android + real HTTP + SQLite inspection journey**, not one automated Android integration test. Student B was registered/tested through HTTP, not through the Android registration UI.

| Step | Result / execution surface |
|---|---|
| 1. Start Dart Frog backend | Passed, isolated data root and port 18081 |
| 2. Start Flutter Android application | Passed, built APK installed on existing emulator |
| 3. Register Student A | Passed through actual Android registration form |
| 4. Log in | Registration established a real session; explicit Android login also passed after restart |
| 5. Create subject | Passed as custom course label `AuditSubject`; there is no separate course-subject CRUD screen |
| 6. Create course | Passed, `AuditML` |
| 7. Import real PDF | Passed through native Downloads picker and multipart upload |
| 8. Verify stored PDF | Passed, filesystem-backed download and SHA-256 |
| 9. Verify extraction | Passed, exact real PDF text from pages 1 and 2 |
| 10. Verify SQLite chunks | Passed, two rows with original page references |
| 11. Semantic search | Passed on Android and separate real-model HTTP script |
| 12. Ask RAG question | Passed with actual local LLM |
| 13. Answer/citations | Passed against known text and persisted references |
| 14. Open cited PDF page | Passed on Android; screenshot records page 2 |
| 15. Log out | Passed through profile confirmation |
| 16. Restart Flutter | Passed using process stop/relaunch without clearing application data; final APK installed preserving data |
| 17. Restart backend | Passed by stopping verified audit process and launching a distinct process against the same temporary root |
| 18. Log in again | Passed through Android sign-in form |
| 19. Verify data persists | Passed: same course/subject/PDF visible; exact file bytes and vectors retained |
| 20. Student B isolation | Passed over real HTTP: empty own library; foreign metadata/download/index/search/RAG/delete rejected |

### Failures and interruptions, not hidden

- Initial restricted SDK wrapper invocations produced no useful completion output; they are not counted as passing checks. Approved SDK/cache/socket execution produced the results above.
- An intermediate Flutter run overlapped source edits and reported two failures: the new HTTP 413 regression encountered the old compiled message, and the new custom-subject test exposed demo repository validation still rejecting custom labels. Demo validation was corrected and a fresh complete run passed, followed by another final complete run after the Unicode change.
- The Windows computer-use runtime and its fallback failed to initialize with `failed to write kernel assets ... path not found`, including retry/reset. Android CLI tooling provided the actual device evidence instead. No desktop-automation success is claimed.
- An approval-review usage-limit failure interrupted one emulator screenshot command. It was a review-service failure, not a safety determination. After the user requested continuation, normal approved execution resumed.
- One manual PowerShell harness incorrectly interpreted an empty JSON array as a one-element pipeline wrapper. The raw Student B response was HTTP 200 `[]`, and DB ownership inspection agreed. A Python harness with explicit JSON parsing reran the assertions successfully and produced the evidence file. This was a test-harness failure, not a cross-user data leak.

### Not executed / not established

- Real encrypted/password-protected and actual scanned/image-only PDF fixtures. Blank real PDFs were executed, and mock textless-PDF tests exist, but neither is mislabeled as a real scanned-PDF test.
- Full Unicode/font coverage, multilingual scripts beyond accented Latin PDF text, multi-column extraction ordering, tables/equations, 250-page and million-character boundary fixtures.
- Real malicious/pathological PDF CPU/resource behavior, forced disk failure, large-corpus load/concurrency, and crash at every file/DB boundary.
- Real adversarial prompt-injection corpus, long-token context overflow, quantitative semantic ranking/answer-grounding benchmark.
- Physical device, iOS, release signing/HTTPS deployment, and optional `dart_frog dev` CLI.
- Exhaustive click-by-click Android course editing/deletion/processing retry; these have unit/widget/real HTTP coverage as identified above.

## F. Remaining work, prioritized

### Critical blockers

No missing provider, model, credential, backend, or database blocks the demonstrated local text-PDF workflow. The obstacle to a **100% completion claim** is incomplete semantic segmentation and robustness/verification of extraction and grounded answers, not an absent AI implementation.

### High priority for academic sign-off

1. Implement and test paragraph/sentence-aware chunking while preserving original page references and text fidelity. Include questions requiring neighboring chunks.
2. Add token-budgeted context assembly with multilingual/long-document cases. Explicitly reserve room for prompt and answer rather than relying only on character counts.
3. Run a representative known-answer corpus and adversarial document tests. Measure whether generated claims are supported, not merely whether quotations occur in the source. Keep unsupported-answer behavior explicit.
4. Add real encrypted, image-only, complex-font, and malformed-document fixtures; confirm failure/retry behavior and document which PDFs the academic submission supports. OCR is conditional on that agreed scope.

### Medium priority

- Isolate native PDF extraction with cancellation/hard time limits so a pathological document cannot indefinitely block the processing queue.
- Add a repeatable Android integration test for the demonstrated journey, including restored sessions and native picker behavior where feasible.
- Test concurrent model replacement, cross-batch dimension consistency, interrupted indexing, and resource exhaustion on realistic corpora.
- Improve session-expiry navigation and distinguish method-not-allowed errors consistently.
- Consolidate outdated architecture/demo notes and document independent profile subjects versus course labels.

### Optional / deployment enhancements

Storage quotas, pagination, orphan-file cleanup, backups, monitoring, TLS deployment, stronger rate limiting, token refresh/revocation, vector indexing for larger libraries, citation highlighting, and persisted chat history. These should not be invented as already implemented or automatically treated as academic requirements.

## G. Final verdict

**NO — the module should not yet be described as “100% complete, correct, and fully verified.”**

All eight official capability areas have real implementation; embeddings, semantic search, and LLM RAG are **not missing**. The main positive result is a successful course-to-answer-to-original-PDF-page journey on Android with persistence and ownership checks.

For the strict completion standard requested here, **meaningful chunking (requirement 3)** is still only a character/word-boundary approximation, and **robust RAG/grounded-answer behavior (requirements 6–7)** lacks token-aware context assembly and broader claim-support/adversarial validation. **Text extraction (requirement 2)** works on executed text-PDF cases but has explicit unsupported formats and unexecuted edge cases. These are the precise reasons for withholding a full-completion certificate. This does not mean the demonstrated basic text-PDF pipeline failed, nor does it imply an observed cross-user leak or fabricated citation.

The project is ready for a supervised demonstration of its tested text-PDF workflow. Complete the high-priority items and rerun the documented checks before claiming comprehensive academic completion.
