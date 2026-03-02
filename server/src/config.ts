import dotenv from "dotenv";

dotenv.config();

const DEFAULT_PORT = 3000;
const DEFAULT_MONGO_URI = "mongodb://127.0.0.1:27017/bazooka";
const DEFAULT_OREF_FEED_URL = "https://www.oref.org.il/warningMessages/alert/Alerts.json";
const DEFAULT_OREF_POLL_INTERVAL_MS = 3000;
const DEFAULT_OREF_REQUEST_TIMEOUT_MS = 2000;

function parsePort(rawPort: string | undefined): number {
  if (!rawPort) {
    return DEFAULT_PORT;
  }

  const parsedPort = Number.parseInt(rawPort, 10);
  if (!Number.isInteger(parsedPort) || parsedPort <= 0) {
    throw new Error(`Invalid PORT value: "${rawPort}"`);
  }

  return parsedPort;
}

function parsePositiveInt(rawValue: string | undefined, fieldName: string, fallback: number): number {
  if (!rawValue || rawValue.trim().length === 0) {
    return fallback;
  }

  const parsed = Number.parseInt(rawValue, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`Invalid ${fieldName} value: "${rawValue}"`);
  }

  return parsed;
}

function parseMongoUri(rawUri: string | undefined): string {
  if (!rawUri || rawUri.trim().length === 0) {
    return DEFAULT_MONGO_URI;
  }

  return rawUri.trim();
}

function parseOrefFeedUrl(rawUrl: string | undefined): string {
  if (!rawUrl || rawUrl.trim().length === 0) {
    return DEFAULT_OREF_FEED_URL;
  }

  return rawUrl.trim();
}

function parseBoolean(rawValue: string | undefined, fallback: boolean): boolean {
  if (!rawValue || rawValue.trim().length === 0) {
    return fallback;
  }

  const normalized = rawValue.trim().toLowerCase();
  if (normalized === "true") {
    return true;
  }

  if (normalized === "false") {
    return false;
  }

  throw new Error(`Invalid boolean value: "${rawValue}"`);
}

function parseOptionalString(rawValue: string | undefined): string | null {
  if (!rawValue || rawValue.trim().length === 0) {
    return null;
  }

  return rawValue.trim();
}

export const config = {
  port: parsePort(process.env.PORT),
  mongoUri: parseMongoUri(process.env.MONGO_URI),
  orefFeedUrl: parseOrefFeedUrl(process.env.OREF_FEED_URL),
  orefPollIntervalMs: parsePositiveInt(
    process.env.OREF_POLL_INTERVAL_MS,
    "OREF_POLL_INTERVAL_MS",
    DEFAULT_OREF_POLL_INTERVAL_MS
  ),
  orefRequestTimeoutMs: parsePositiveInt(
    process.env.OREF_REQUEST_TIMEOUT_MS,
    "OREF_REQUEST_TIMEOUT_MS",
    DEFAULT_OREF_REQUEST_TIMEOUT_MS
  ),
  orefPollerEnabled: parseBoolean(process.env.OREF_POLLER_ENABLED, true),
  fcmEnabled: parseBoolean(process.env.FCM_ENABLED, true),
  firebaseServiceAccountPath: parseOptionalString(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
};
