import { appendFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { config } from "./config.js";

type LogLevel = "info" | "warn" | "error";
type LogContext = Record<string, unknown>;

const systemLogPath = resolve(process.cwd(), config.systemLogPath);
let ensuredDirectory = false;
let writeQueue: Promise<void> = Promise.resolve();

function normalizeError(error: unknown): Record<string, unknown> {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: error.stack ?? null
    };
  }

  return { message: String(error) };
}

async function ensureDirectory(): Promise<void> {
  if (ensuredDirectory) {
    return;
  }

  await mkdir(dirname(systemLogPath), { recursive: true });
  ensuredDirectory = true;
}

function enqueueWrite(line: string): void {
  writeQueue = writeQueue
    .then(async () => {
      await ensureDirectory();
      await appendFile(systemLogPath, line, "utf8");
    })
    .catch((error) => {
      // Fall back to stderr when writing to the system log fails.
      console.error(
        JSON.stringify({
          timestamp: new Date().toISOString(),
          level: "error",
          event: "system_log_write_failed",
          error: normalizeError(error)
        })
      );
    });
}

function emit(level: LogLevel, event: string, context: LogContext = {}): void {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    event,
    ...context
  };
  const line = `${JSON.stringify(entry)}\n`;

  enqueueWrite(line);

  if (level === "error") {
    console.error(line.trim());
    return;
  }

  if (level === "warn") {
    console.warn(line.trim());
    return;
  }

  console.log(line.trim());
}

export function logInfo(event: string, context: LogContext = {}): void {
  emit("info", event, context);
}

export function logWarn(event: string, context: LogContext = {}): void {
  emit("warn", event, context);
}

export function logError(event: string, error: unknown, context: LogContext = {}): void {
  emit("error", event, {
    ...context,
    error: normalizeError(error)
  });
}
