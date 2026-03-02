# Bazooka App

## Firebase FCM Setup

1. Put your Firebase Android config at:
   - `app/android/app/google-services.json`
2. Confirm package name in Firebase matches:
   - `com.bazooka.alerts.app`
3. Install deps:
   - `cd app && flutter pub get`
4. Run app with backend URL:
   - `flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000`

The app already includes:
- `firebase_core` initialization on startup.
- `firebase_messaging` token retrieval and refresh sync.
- Background message registration (`FirebaseMessaging.onBackgroundMessage`).
- Backend sync calls to:
  - `POST /register-device`
  - `PUT /subscription`

## Backend FCM Dependency

Backend fanout requires Firebase Admin credentials.  
Set in `server/.env`:

- `FCM_ENABLED=true`
- `FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json`
