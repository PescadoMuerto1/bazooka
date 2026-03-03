import { Router } from "express";
import { logInfo } from "../logger.js";

const healthRouter = Router();

healthRouter.get("/", (_req, res) => {
  logInfo("health_check_requested");
  res.status(200).json({
    ok: true,
    service: "bazooka-server",
    timestamp: new Date().toISOString()
  });
});

export default healthRouter;
