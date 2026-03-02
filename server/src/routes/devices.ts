import { type NextFunction, type Request, type Response, Router } from "express";
import { config } from "../config.js";
import { DeviceModel } from "../models/device.js";
import { SubscriptionModel } from "../models/subscription.js";

const SUPPORTED_LANGUAGES = new Set(["he", "en", "ru", "ar"]);
const writeRateBuckets = new Map<string, { count: number; windowStartedAt: number }>();

function getRequiredString(value: unknown, fieldName: string, maxLength: number): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`"${fieldName}" is required and must be a non-empty string`);
  }

  const trimmedValue = value.trim();
  if (trimmedValue.length > maxLength) {
    throw new Error(`"${fieldName}" must be at most ${maxLength} chars`);
  }

  return trimmedValue;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function enforceJsonBody(req: Request): void {
  if (!isRecord(req.body)) {
    throw new Error("Request body must be a JSON object");
  }
}

function maybeRateLimitWrite(req: Request, res: Response, next: NextFunction): void {
  const key = `${req.ip}:${req.path}:${req.method}`;
  const now = Date.now();
  const existing = writeRateBuckets.get(key);

  if (!existing || now - existing.windowStartedAt >= config.writeRateLimitWindowMs) {
    writeRateBuckets.set(key, { count: 1, windowStartedAt: now });
    next();
    return;
  }

  if (existing.count >= config.writeRateLimitMax) {
    const retryAfterSeconds = Math.ceil((config.writeRateLimitWindowMs - (now - existing.windowStartedAt)) / 1000);
    res.setHeader("Retry-After", String(Math.max(1, retryAfterSeconds)));
    res.status(429).json({ ok: false, error: "Rate limit exceeded for write operations" });
    return;
  }

  existing.count += 1;
  next();
}

const devicesRouter = Router();
devicesRouter.use(maybeRateLimitWrite);

devicesRouter.post("/register-device", async (req, res) => {
  try {
    enforceJsonBody(req);
    const deviceId = getRequiredString(req.body.deviceId, "deviceId", 128);
    const fcmToken = getRequiredString(req.body.fcmToken, "fcmToken", 4096);
    const locale = getRequiredString(req.body.locale, "locale", 32);
    const appVersion = getRequiredString(req.body.appVersion, "appVersion", 32);

    await DeviceModel.findOneAndUpdate(
      { deviceId },
      {
        deviceId,
        fcmToken,
        locale,
        appVersion,
        platform: "android",
        updatedAt: new Date()
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    console.log(`Device registered or updated: deviceId=${deviceId}`);
    return res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof Error && error.message.includes("required")) {
      return res.status(400).json({ ok: false, error: error.message });
    }

    if (error instanceof Error && (error.message.includes("at most") || error.message.includes("JSON object"))) {
      return res.status(400).json({ ok: false, error: error.message });
    }

    console.error("Failed to register device", error);
    return res.status(500).json({ ok: false, error: "Internal server error" });
  }
});

devicesRouter.put("/subscription", async (req, res) => {
  try {
    enforceJsonBody(req);
    const deviceId = getRequiredString(req.body.deviceId, "deviceId", 128);
    const cityKey = getRequiredString(req.body.cityKey, "cityKey", 120);
    const cityDisplay = getRequiredString(req.body.cityDisplay, "cityDisplay", 120);
    const lang = getRequiredString(req.body.lang, "lang", 8);

    if (!SUPPORTED_LANGUAGES.has(lang)) {
      return res.status(400).json({ ok: false, error: "\"lang\" must be one of he/en/ru/ar" });
    }

    const deviceExists = await DeviceModel.exists({ deviceId });
    if (!deviceExists) {
      return res.status(404).json({ ok: false, error: "Device not registered" });
    }

    await SubscriptionModel.findOneAndUpdate(
      { deviceId },
      {
        deviceId,
        cityKey,
        cityDisplay,
        lang,
        updatedAt: new Date()
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    console.log(`Subscription upserted: deviceId=${deviceId}, cityKey=${cityKey}`);
    return res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof Error && error.message.includes("required")) {
      return res.status(400).json({ ok: false, error: error.message });
    }

    if (error instanceof Error && (error.message.includes("at most") || error.message.includes("JSON object"))) {
      return res.status(400).json({ ok: false, error: error.message });
    }

    console.error("Failed to update subscription", error);
    return res.status(500).json({ ok: false, error: "Internal server error" });
  }
});

export default devicesRouter;
