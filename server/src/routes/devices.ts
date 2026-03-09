import { type NextFunction, type Request, type Response, Router } from "express";
import { config } from "../config.js";
import { mapAlertAreasToCityKeys } from "../data/cities.js";
import { logError, logInfo, logWarn } from "../logger.js";
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

function getOptionalString(value: unknown, fieldName: string, maxLength: number): string | null {
  if (value === undefined || value === null) {
    return null;
  }

  if (typeof value !== "string") {
    throw new Error(`"${fieldName}" must be a string`);
  }

  const trimmedValue = value.trim();
  if (trimmedValue.length === 0) {
    return null;
  }

  if (trimmedValue.length > maxLength) {
    throw new Error(`"${fieldName}" must be at most ${maxLength} chars`);
  }

  return trimmedValue;
}

function resolveCityKeyForStorage(rawCityKey: string): string {
  const mappedCityKeys = mapAlertAreasToCityKeys([rawCityKey]).filter(
    (candidate) => candidate !== rawCityKey
  );

  if (mappedCityKeys.length === 0) {
    return rawCityKey;
  }

  return mappedCityKeys[0];
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
    logWarn("write_rate_limit_exceeded", {
      key,
      path: req.path,
      method: req.method,
      ip: req.ip,
      retryAfterSeconds
    });
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

    logInfo("register_device_requested", {
      deviceId,
      locale,
      appVersion
    });

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

    logInfo("register_device_succeeded", { deviceId });
    return res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof Error && error.message.includes("required")) {
      logWarn("register_device_bad_request", {
        reason: error.message
      });
      return res.status(400).json({ ok: false, error: error.message });
    }

    if (error instanceof Error && (error.message.includes("at most") || error.message.includes("JSON object"))) {
      logWarn("register_device_bad_request", {
        reason: error.message
      });
      return res.status(400).json({ ok: false, error: error.message });
    }

    logError("register_device_failed", error);
    return res.status(500).json({ ok: false, error: "Internal server error" });
  }
});

devicesRouter.put("/subscription", async (req, res) => {
  try {
    enforceJsonBody(req);
    const deviceId = getRequiredString(req.body.deviceId, "deviceId", 128);
    const rawCityKey = getRequiredString(req.body.cityKey, "cityKey", 120);
    const cityKey = resolveCityKeyForStorage(rawCityKey);
    const providedCityDisplay = getOptionalString(req.body.cityDisplay, "cityDisplay", 120);
    const cityDisplay = providedCityDisplay ?? cityKey;
    const lang = getRequiredString(req.body.lang, "lang", 8).toLowerCase();

    logInfo("subscription_upsert_requested", {
      deviceId,
      rawCityKey,
      cityKey,
      cityDisplay,
      lang
    });

    if (!SUPPORTED_LANGUAGES.has(lang)) {
      logWarn("subscription_upsert_bad_request", {
        reason: "\"lang\" must be one of he/en/ru/ar",
        deviceId,
        rawCityKey,
        cityKey,
        lang
      });
      return res.status(400).json({ ok: false, error: "\"lang\" must be one of he/en/ru/ar" });
    }

    const deviceExists = await DeviceModel.exists({ deviceId });
    if (!deviceExists) {
      logWarn("subscription_upsert_device_missing", {
        deviceId,
        rawCityKey,
        cityKey
      });
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

    logInfo("subscription_upsert_succeeded", {
      deviceId,
      cityKey,
      cityDisplay,
      lang
    });
    return res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof Error && error.message.includes("required")) {
      logWarn("subscription_upsert_bad_request", {
        reason: error.message
      });
      return res.status(400).json({ ok: false, error: error.message });
    }

    if (error instanceof Error && (error.message.includes("at most") || error.message.includes("JSON object"))) {
      logWarn("subscription_upsert_bad_request", {
        reason: error.message
      });
      return res.status(400).json({ ok: false, error: error.message });
    }

    logError("subscription_upsert_failed", error);
    return res.status(500).json({ ok: false, error: "Internal server error" });
  }
});

export default devicesRouter;
