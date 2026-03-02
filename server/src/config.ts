import dotenv from "dotenv";

dotenv.config();

const DEFAULT_PORT = 3000;
const DEFAULT_MONGO_URI = "mongodb://127.0.0.1:27017/bazooka";

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

function parseMongoUri(rawUri: string | undefined): string {
  if (!rawUri || rawUri.trim().length === 0) {
    return DEFAULT_MONGO_URI;
  }

  return rawUri.trim();
}

export const config = {
  port: parsePort(process.env.PORT),
  mongoUri: parseMongoUri(process.env.MONGO_URI)
};
