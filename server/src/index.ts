import express from "express";
import { config } from "./config.js";
import healthRouter from "./routes/health.js";

const app = express();

app.use(express.json());
app.use("/health", healthRouter);

app.get("/", (_req, res) => {
  res.status(200).json({
    ok: true,
    message: "Bazooka server is running"
  });
});

app.listen(config.port, () => {
  console.log(`Bazooka server listening on port ${config.port}`);
});
