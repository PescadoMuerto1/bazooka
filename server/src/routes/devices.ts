import { Router } from "express";
import { DeviceModel } from "../models/device.js";
import { SubscriptionModel } from "../models/subscription.js";

const SUPPORTED_LANGUAGES = new Set(["he", "en", "ru", "ar"]);

function getRequiredString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`"${fieldName}" is required and must be a non-empty string`);
  }

  return value.trim();
}

const devicesRouter = Router();

devicesRouter.post("/register-device", async (req, res) => {
  try {
    const deviceId = getRequiredString(req.body?.deviceId, "deviceId");
    const fcmToken = getRequiredString(req.body?.fcmToken, "fcmToken");
    const locale = getRequiredString(req.body?.locale, "locale");
    const appVersion = getRequiredString(req.body?.appVersion, "appVersion");

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

    return res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof Error && error.message.includes("required")) {
      return res.status(400).json({ ok: false, error: error.message });
    }

    console.error("Failed to register device", error);
    return res.status(500).json({ ok: false, error: "Internal server error" });
  }
});

devicesRouter.put("/subscription", async (req, res) => {
  try {
    const deviceId = getRequiredString(req.body?.deviceId, "deviceId");
    const cityKey = getRequiredString(req.body?.cityKey, "cityKey");
    const cityDisplay = getRequiredString(req.body?.cityDisplay, "cityDisplay");
    const lang = getRequiredString(req.body?.lang, "lang");

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

    return res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof Error && error.message.includes("required")) {
      return res.status(400).json({ ok: false, error: error.message });
    }

    console.error("Failed to update subscription", error);
    return res.status(500).json({ ok: false, error: "Internal server error" });
  }
});

export default devicesRouter;
