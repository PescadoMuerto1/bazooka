# Bazooka App

## Firebase FCM Setup

1. Put your Firebase Android config at:
   - `app/android/app/google-services.json`
2. Confirm package name in Firebase matches:
   - `com.bazooka.alerts.app`
3. Configure backend URL in:
   - `app/.env`
   - Copy from `app/.env.example` if needed
3. Install deps:
   - `cd app && flutter pub get`
4. Run app:
   - `flutter run`

## Custom Alert Song (Android)

To use a custom notification song, place your audio file at:

- `app/android/app/src/main/res/raw/alert_song.mp3`

Notes:
- Resource name must be `alert_song`.
- Supported raw formats include `.wav`, `.mp3`, and `.ogg`.
- After changing channel sound, uninstall/reinstall the app (Android caches channel settings).
- If file is missing, Android may fall back to default behavior.

The app already includes:
- `firebase_core` initialization on startup.
- `firebase_messaging` token retrieval and refresh sync.
- Background message registration (`FirebaseMessaging.onBackgroundMessage`) that
  triggers local full-screen notifications on Android.
- Backend sync calls to:
  - `POST /register-device`
  - `PUT /subscription`

## Closed-App Alert Behavior (Android)

- Backend sends high-priority FCM data payloads.
- The app creates a local notification with:
  - custom sound (`alert_song`)
  - full-screen intent
- This allows alerts to appear prominently even when app UI is not open.

Important:
- Android/OS policy can still suppress full-screen launch in some situations.
- iOS does not support forcing a full-screen app popup from a terminated state.

## Backend FCM Dependency

Backend fanout requires Firebase Admin credentials.  
Set in `server/.env`:

- `FCM_ENABLED=true`
- `FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json`

## Backend URL Precedence

1. `ApiClient(baseUrl: ...)` constructor override
2. `--dart-define=BACKEND_BASE_URL=...`
3. `app/.env` (`BACKEND_BASE_URL=...`)
4. Default fallback: `http://10.0.2.2:3000`
