import express from "express";
import { config } from "./config.js";
import { connectToDatabase } from "./db.js";
import devicesRouter from "./routes/devices.js";
import healthRouter from "./routes/health.js";

const app = express();

app.use(express.json());
app.use("/health", healthRouter);
app.use("/", devicesRouter);

app.get("/", (_req, res) => {
  res.status(200).json({
    ok: true,
    message: "Bazooka server is running"
  });
});

async function startServer(): Promise<void> {
  await connectToDatabase();

  app.listen(config.port, () => {
    console.log(`Bazooka server listening on port ${config.port}`);
  });
}

startServer().catch((error) => {
  console.error("Failed to start server", error);
  process.exit(1);
});
