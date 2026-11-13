# Architecture agreements

## Implemented backend decision — 16 October 2026

The shared backend is Dart Frog with persistent SQLite and filesystem PDF storage, entirely in Dart. Flutter uses JWT-authenticated REST requests and secure token storage. See [backend architecture, configuration and limitations](../backend/README.md). The earlier unassigned backend decisions below are superseded for auth/profile/courses/documents/search; other learning modules remain future integrations.

## Responsibilities

Screens and widgets display state and forward user actions to view models. View models manage screen state and call repositories. Repositories load/save feature data through services. Models describe the data. Add a domain folder for complex reusable business logic when needed.

Keep feature-specific code within its feature. Share widgets only when more than one feature needs them. Reuse agreed public models and repositories across features; do not import another feature's screens or view models for data access.

The Flutter app calls the Dart backend for AI operations. The backend embeds PDF passages with local Ollama, stores vectors in SQLite, ranks authorized course passages using cosine similarity, and generates answers with verified source references. No model or provider credential is shipped in Flutter. See [RAG architecture](courses_rag.md).

## Decisions to make together

- Exact Flutter version and one state-management approach.
- Backend stack, authentication provider, and database.
- Navigation routes, UI theme, and shared components.
- Shared identifiers, public models, and API contracts.
- Member ownership and review rotation.

## First milestone

Runnable login/profile flow, navigation, and placeholder screens for the five modules. Develop feature UIs against agreed mock data while backend endpoints are implemented.
