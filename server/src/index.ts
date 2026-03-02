import express from "express";
import { config } from "./config.js";
import { connectToDatabase } from "./db.js";
import { startOrefPoller } from "./poller/orefPoller.js";
import alertsRouter from "./routes/alerts.js";
import devicesRouter from "./routes/devices.js";
import healthRouter from "./routes/health.js";

const app = express();

app.use(express.json());
app.use((req, res, next) => {
  const startedAt = Date.now();
  res.on("finish", () => {
    const durationMs = Date.now() - startedAt;
    console.log(`${req.method} ${req.originalUrl} -> ${res.statusCode} (${durationMs}ms)`);
  });
  next();
});
app.use("/health", healthRouter);
app.use("/", devicesRouter);
app.use("/", alertsRouter);

app.get("/", (_req, res) => {
  res.status(200).json({
    ok: true,
    message: "Bazooka server is running"
  });
});

async function startServer(): Promise<void> {
  await connectToDatabase();
  startOrefPoller();

  app.listen(config.port, () => {
    console.log(`Bazooka server listening on port ${config.port}`);
  });
}

startServer().catch((error) => {
  console.error("Failed to start server", error);
  process.exit(1);
});
