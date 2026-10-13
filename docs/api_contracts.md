# API contracts

Agree on these contracts before implementing integrations. This file is a planning checklist, not an implemented API specification.

## Shared identifiers

Define formats and ownership for userId, courseId, lessonId, quizId, deckId, and studySessionId. Define timestamps, pagination, authentication, and error responses consistently.

## Feature connections

- Courses: course/lesson content and retrieval citations for RAG answers.
- Tutor: course/lesson context, conversation messages, and mind-map nodes/edges.
- Assessments: questions, submissions, scoring, exam timing, and learning progress.
- Planner: availability, deadlines, progress inputs, and recommendations.
- Flashcards: decks/cards, review grades, next review dates, and progress events.
- Auth/profile: active user identity, preferences, and learning goals.

For each endpoint record method/path, request JSON, response JSON, errors, access rules, and a mock example. Decide how assessment and flashcard results update planner recommendations.
