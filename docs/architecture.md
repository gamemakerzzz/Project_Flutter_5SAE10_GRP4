# Architecture agreements

## Responsibilities

Screens and widgets display state and forward user actions to view models. View models manage screen state and call repositories. Repositories load/save feature data through services. Models describe the data. Add a domain folder for complex reusable business logic when needed.

Keep feature-specific code within its feature. Share widgets only when more than one feature needs them. Reuse agreed public models and repositories across features; do not import another feature's screens or view models for data access.

The Flutter app calls the team's backend for AI operations. Backend ownership, document ingestion, RAG retrieval, and AI provider integration still need assignment. Provider credentials belong on the backend.

## Decisions to make together

- Exact Flutter version and one state-management approach.
- Backend stack, authentication provider, and database.
- Navigation routes, UI theme, and shared components.
- Shared identifiers, public models, and API contracts.
- Member ownership and review rotation.

## First milestone

Runnable login/profile flow, navigation, and placeholder screens for the five modules. Develop feature UIs against agreed mock data while backend endpoints are implemented.
