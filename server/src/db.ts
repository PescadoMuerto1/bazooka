import mongoose from "mongoose";
import { config } from "./config.js";

export async function connectToDatabase(): Promise<void> {
  if (mongoose.connection.readyState === 1) {
    return;
  }

  await mongoose.connect(config.mongoUri);
}
