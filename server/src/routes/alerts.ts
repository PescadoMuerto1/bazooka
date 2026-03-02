import { Router } from "express";
import { mapAlertAreasToCityKeys } from "../data/cities.js";
import { AlertModel } from "../models/alert.js";

const alertsRouter = Router();
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

function parseCityKey(rawCityKey: unknown): string {
  if (typeof rawCityKey !== "string" || rawCityKey.trim().length === 0) {
    throw new Error("\"cityKey\" query param is required");
  }

  return rawCityKey.trim();
}

function parseLimit(rawLimit: unknown): number {
  if (rawLimit === undefined) {
    return DEFAULT_LIMIT;
  }

  const value = Array.isArray(rawLimit) ? rawLimit[0] : rawLimit;
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error("\"limit\" must be a positive integer");
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error("\"limit\" must be a positive integer");
  }

  return Math.min(parsed, MAX_LIMIT);
}

alertsRouter.get("/alerts/recent", async (req, res) => {
  try {
    const cityKey = parseCityKey(req.query.cityKey);
    const limit = parseLimit(req.query.limit);
    const queryCityKeys = new Set(mapAlertAreasToCityKeys([cityKey]));
    const fetchLimit = Math.min(limit * 20, 500);

    const alerts = await AlertModel.find({})
      .sort({ ingestedAt: -1 })
      .limit(fetchLimit)
      .lean()
      .exec();

    const matchingAlerts = alerts
      .filter((alert) => {
        const normalizedAlertKeys = mapAlertAreasToCityKeys(alert.areas);
        return normalizedAlertKeys.some((area) => queryCityKeys.has(area));
      })
      .slice(0, limit);

    return res.status(200).json(
      matchingAlerts.map((alert) => ({
        alertId: alert.alertId,
        title: alert.title,
        category: alert.category,
        areas: alert.areas,
        desc: alert.desc,
        sourceTimestamp: alert.sourceTimestamp,
        ingestedAt: alert.ingestedAt
      }))
    );
  } catch (error) {
    if (error instanceof Error && error.message.includes("query param")) {
      return res.status(400).json({ ok: false, error: error.message });
    }

    if (error instanceof Error && error.message.includes("positive integer")) {
      return res.status(400).json({ ok: false, error: error.message });
    }

    console.error("Failed to fetch recent alerts", error);
    return res.status(500).json({ ok: false, error: "Internal server error" });
  }
});

export default alertsRouter;
