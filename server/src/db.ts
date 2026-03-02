import mongoose from "mongoose";
import { config } from "./config.js";
import { logError, logInfo } from "./logger.js";

export async function connectToDatabase(): Promise<void> {
  if (mongoose.connection.readyState === 1) {
    logInfo("db_connect_skipped_already_connected");
    return;
  }

  logInfo("db_connect_started", { mongoUri: config.mongoUri });
  try {
    await mongoose.connect(config.mongoUri);
    logInfo("db_connect_succeeded");
  } catch (error) {
    logError("db_connect_failed", error, { mongoUri: config.mongoUri });
    throw error;
  }
}
