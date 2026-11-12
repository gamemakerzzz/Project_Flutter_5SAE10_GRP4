# API configuration

Connected mode is the default. `API_BASE_URL` is a compile-time dart-define.
Debug defaults to http://10.0.2.2:8080 for the Android emulator. Only localhost,
127.0.0.1 and 10.0.2.2 may use HTTP in debug; release requires HTTPS.
Explicit demo mode: `--dart-define=DEMO_MODE=true`.
JWTs are stored using flutter_secure_storage; passwords are never persisted.
See ../../backend/README.md for the server and database contracts.
