# Run the integrated Android app

## USB phone APK

Enable USB debugging and authorize this computer on the phone. Build a sideloadable release APK:

```powershell
flutter build apk --release --no-pub --dart-define=USB_LOCAL_BACKEND=true --dart-define=API_BASE_URL=http://127.0.0.1:18080 --dart-define=LEARNING_AI_URL=http://127.0.0.1:18081
./run-phone.ps1
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. The project currently signs release builds with the development key for local sideloading. The phone launcher starts both services, configures `adb reverse` for their ports, installs without clearing data, and opens StudyMate AI. Run it again after reconnecting USB. This build permits HTTP only to loopback in release mode; other release backend addresses must use HTTPS. Accounts and AI need the computer running and USB connected. Local course data and flashcards remain on the phone. A standalone online release requires hosted HTTPS services and production signing.

## Wireless phone

The direct Wi-Fi APK uses the PC's Wi-Fi address. Start the local services and relay with `./start-phone-wifi.ps1`. The relay forwards ports 18080 and 18081 for the configured phone address while both devices are on the same network. This APK works without an ADB connection after installation. If the PC address changes, update the allowed Android domain and rebuild with matching `WIFI_BACKEND_HOST`, `API_BASE_URL`, and `LEARNING_AI_URL` values. If the phone address changes, restart the relay with the new `-PhoneAddress`.

### Wireless ADB alternative

The same phone APK also works through wireless ADB forwarding. With the authorized phone still on USB, connect it and the PC to the same trusted Wi-Fi network, run `adb -s SERIAL tcpip 5555`, and use its Wi-Fi address:

```powershell
./run-wireless.ps1 -PhoneAddress 192.168.1.20:5555 -Install
```

This connects over Wi-Fi, forwards both backend ports, and optionally installs the APK. USB can then be removed. Subsequent reconnects use `./run-wireless.ps1` with the last address saved under ignored `.dart_tool`. If the phone IP changes, provide the new address. Rebooting the phone may require enabling wireless debugging again. The PC must stay running and on the same network; this is not a hosted, anywhere-access service. Backend ports remain bound to loopback. Disable network debugging when no longer needed using `adb -s IP:5555 usb`.

## Emulator setup

From the project root:

```powershell
python -m venv .venv
./.venv/Scripts/python.exe -m pip install -r backend/requirements.txt
./run-android.ps1
```

The launcher starts the account API on port 18080 and the local Python learning AI service on port 18081, checks their health, generates Android plugins, and launches the emulator app. Desktop plugin symlink generation is disabled only for that command. Both services bind to loopback. Android reaches them using `10.0.2.2`.

Store provider settings in the ignored `backend/.env` file:

```dotenv
ANTHROPIC_API_KEY=your-key
ANTHROPIC_MODEL=claude-sonnet-5-5
GEMINI_API_KEY=your-key
GEMINI_MODEL=gemini-3.1-flash-lite
PORT=18081
```

Restart the Python service after changing settings. Provider keys stay on the computer and are not compiled into Flutter. `LEARNING_AI_URL` overrides the app's AI-service address; `API_BASE_URL` overrides the account API address.

Courses and PDFs remain in the existing local SQLite database. Asking a course question sends up to 60,000 characters of relevant local passages to Claude; source indices and exact supporting quotations are validated before displaying an answer. Keyword search examines all stored passages, rather than just the first 12. This is bounded local retrieval, not semantic vector search. Scanned PDFs still require OCR.

Gemini generates course quizzes. Claude provides optional feedback on open-ended answers in practice mode: answer, choose **Vérifier ma réponse**, then **Obtenir une correction Claude**. This feedback does not change the automatic score. Claude generates flashcards and explanations. Provider access/quota errors are displayed without silently replacing AI output with demo content.

This is a loopback-only development service. Do not expose the Python service publicly without authentication and rate limiting. Logs are ignored by Git. Existing accounts and local study data are preserved.
