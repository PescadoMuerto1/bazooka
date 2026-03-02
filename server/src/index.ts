import express from "express";
import { config } from "./config.js";
import { connectToDatabase } from "./db.js";
import { logError, logInfo } from "./logger.js";
import { startOrefPoller } from "./poller/orefPoller.js";
import alertsRouter from "./routes/alerts.js";
import devToolsRouter from "./routes/devTools.js";
import devicesRouter from "./routes/devices.js";
import healthRouter from "./routes/health.js";

const app = express();

app.use(express.json());
app.use((req, res, next) => {
  const startedAt = Date.now();
  res.on("finish", () => {
    const durationMs = Date.now() - startedAt;
    logInfo("http_request_completed", {
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs,
      ip: req.ip
    });
  });
  next();
});
app.use("/health", healthRouter);
app.use("/", devicesRouter);
app.use("/", alertsRouter);
if (config.devToolsEnabled) {
  app.use("/", devToolsRouter);
}

app.get("/", (_req, res) => {
  res.status(200).json({
    ok: true,
    message: "Bazooka server is running"
  });
});

async function startServer(): Promise<void> {
  logInfo("server_starting", {
    port: config.port,
    mongoUri: config.mongoUri,
    orefPollerEnabled: config.orefPollerEnabled
  });

  await connectToDatabase();
  startOrefPoller();

  app.listen(config.port, () => {
    logInfo("server_listening", { port: config.port });
  });
}

startServer().catch((error) => {
  logError("server_start_failed", error);
  process.exit(1);
});
