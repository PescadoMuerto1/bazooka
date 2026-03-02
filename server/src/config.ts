import dotenv from "dotenv";

dotenv.config();

const DEFAULT_PORT = 3000;

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

export const config = {
  port: parsePort(process.env.PORT)
};
