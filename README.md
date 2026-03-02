# Bazooka MVP

Node.js backend + Flutter Android app for city-based Home Front alerts with FCM push delivery.

## Project Structure

- `server/` Express + MongoDB + Oref poller + Firebase Admin fanout
- `app/` Flutter Android app with city onboarding, recent alerts, settings, and FCM token sync

## Prerequisites

- Node.js 20+
- MongoDB (`mongod`)
- Flutter SDK
- Firebase project for:
  - Android app (`google-services.json`)
  - Backend Admin SDK (`serviceAccountKey.json`)

## Firebase Setup

### Android app

Place file at:

- `app/android/app/google-services.json`

The package name in Firebase must match:

- `com.bazooka.alerts.app`

### Backend

Create `server/.env` from `server/.env.example` and set:

- `FCM_ENABLED=true`
- `FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json`

## Run Backend

```bash
cd server
npm install
npm run build
npm run lint
cp .env.example .env
npm run dev
```

## Run Android App

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000
```

## End-to-End Smoke Checklist

1. Register two devices with different cities (`/register-device` + `/subscription`).
2. Confirm `alerts` collection receives poller inserts.
3. Confirm matching device gets delivery logs in `deliveries`.
4. In app Settings, run **notification test** to re-sync token/subscription.
5. Verify alerts list refresh works and city/language updates persist.
