import { createHash } from "node:crypto";
import { appendFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { config } from "../config.js";
import { logError, logInfo, logWarn } from "../logger.js";
import { AlertModel } from "../models/alert.js";
import { fanoutAlertToSubscribedDevices } from "./fcmFanout.js";
import type { NormalizedAlert, RawOrefAlert } from "../types.js";

let pollTimer: NodeJS.Timeout | null = null;
let isPolling = false;
const alertsLogPath = resolve(process.cwd(), config.orefAlertsLogPath);

function asNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function coerceToString(value: unknown): string | null {
  if (typeof value === "string") {
    return asNonEmptyString(value);
  }

  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }

  return null;
}

function normalizeAreas(raw: RawOrefAlert): string[] {
  const source = raw.data ?? raw.alerts ?? raw.cities;
  if (!Array.isArray(source)) {
    return [];
  }

  return source
    .map((item) => (typeof item === "string" ? item.trim() : ""))
    .filter((item) => item.length > 0);
}

function parseSourceTimestamp(raw: RawOrefAlert): Date | null {
  const timestampCandidate = asNonEmptyString(raw.alertDate) ?? asNonEmptyString(raw.sourceTimestamp);
  if (!timestampCandidate) {
    return null;
  }

  const parsed = new Date(timestampCandidate);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return parsed;
}

function buildAlertHash(parts: string[]): string {
  const joined = parts.join("|");
  return createHash("sha256").update(joined).digest("hex").slice(0, 20);
}

function deriveAlertId(raw: RawOrefAlert, normalized: Omit<NormalizedAlert, "alertId">): string {
  const explicitId = coerceToString(raw.id) ?? coerceToString(raw.alertId);
  if (explicitId) {
    return explicitId;
  }

  const sourceTime = normalized.sourceTimestamp ? normalized.sourceTimestamp.toISOString() : "no-ts";
  const hash = buildAlertHash([
    normalized.title,
    normalized.category,
    normalized.desc,
    sourceTime
  ]);
  return `hash-${hash}`;
}

function normalizeAlert(raw: RawOrefAlert): NormalizedAlert | null {
  const title = asNonEmptyString(raw.title) ?? "Home Front Alert";
  const category = coerceToString(raw.cat) ?? coerceToString(raw.category) ?? "unknown";
  const desc = asNonEmptyString(raw.desc) ?? asNonEmptyString(raw.description) ?? "";
  const areas = normalizeAreas(raw);
  const sourceTimestamp = parseSourceTimestamp(raw);

  const base = { title, category, desc, areas, sourceTimestamp };
  const alertId = deriveAlertId(raw, base);

  return {
    alertId,
    ...base
  };
}

function toRawAlerts(payload: unknown): RawOrefAlert[] {
  if (Array.isArray(payload)) {
    return payload.filter((item): item is RawOrefAlert => typeof item === "object" && item !== null);
  }

  if (typeof payload === "object" && payload !== null) {
    return [payload as RawOrefAlert];
  }

  return [];
}

async function fetchOrefPayload(): Promise<unknown> {
  const abortController = new AbortController();
  const timeout = setTimeout(() => abortController.abort(), config.orefRequestTimeoutMs);

  try {
    logInfo("oref_fetch_started", {
      feedUrl: config.orefFeedUrl,
      timeoutMs: config.orefRequestTimeoutMs
    });

    const response = await fetch(config.orefFeedUrl, {
      signal: abortController.signal,
      headers: {
        Referer: "https://www.oref.org.il/",
        "X-Requested-With": "XMLHttpRequest"
      }
    });

    if (!response.ok) {
      throw new Error(`Oref feed request failed with status ${response.status}`);
    }

    const body = await response.text();
    const normalizedBody = body.trim().replace(/^\uFEFF/, "");
    if (normalizedBody.length === 0) {
      return [];
    }

    try {
      return JSON.parse(normalizedBody);
    } catch {
      const contentType = response.headers.get("content-type") ?? "unknown";
      const bodyPreview = normalizedBody.slice(0, 120);
      logWarn("oref_fetch_invalid_json", {
        status: response.status,
        contentType,
        bodyPreview
      });
      return [];
    }
  } finally {
    clearTimeout(timeout);
  }
}

function toAlertLogLine(alert: NormalizedAlert): string {
  const logEntry = {
    loggedAt: new Date().toISOString(),
    alertId: alert.alertId,
    title: alert.title,
    category: alert.category,
    areas: alert.areas,
    desc: alert.desc,
    sourceTimestamp: alert.sourceTimestamp ? alert.sourceTimestamp.toISOString() : null
  };

  return `${JSON.stringify(logEntry)}\n`;
}

async function appendAlertToLog(alert: NormalizedAlert): Promise<void> {
  await mkdir(dirname(alertsLogPath), { recursive: true });
  await appendFile(alertsLogPath, toAlertLogLine(alert), "utf8");
}

const DEDUP_WINDOW_MS = 2 * 60 * 1000; // 2 minutes

async function findRecentMatchingAlert(normalized: NormalizedAlert) {
  // First check for exact alertId match
  const exactMatch = await AlertModel.findOne({ alertId: normalized.alertId }).exec();
  if (exactMatch) {
    return exactMatch;
  }

  // Then check for a recent alert with the same title+category (different Oref ID, same event)
  const windowStart = new Date(Date.now() - DEDUP_WINDOW_MS);
  return AlertModel.findOne({
    title: normalized.title,
    category: normalized.category,
    ingestedAt: { $gte: windowStart }
  }).sort({ ingestedAt: -1 }).exec();
}

export async function pollOrefOnce(): Promise<number> {
  const payload = await fetchOrefPayload();
  const rawAlerts = toRawAlerts(payload);

  if (rawAlerts.length === 0) {
    logInfo("oref_poll_no_alerts");
    return 0;
  }

  let insertedCount = 0;
  let updatedCount = 0;
  let duplicateCount = 0;
  for (const rawAlert of rawAlerts) {
    const normalized = normalizeAlert(rawAlert);
    if (!normalized) {
      continue;
    }

    const existingAlert = await findRecentMatchingAlert(normalized);

    if (existingAlert) {
      // Merge any new areas into the existing alert
      const existingAreasSet = new Set(existingAlert.areas);
      const newAreas = normalized.areas.filter((area) => !existingAreasSet.has(area));

      if (newAreas.length === 0) {
        duplicateCount += 1;
        continue;
      }

      // Update the stored alert with the merged areas
      const mergedAreas = [...existingAlert.areas, ...newAreas];
      await AlertModel.updateOne(
        { _id: existingAlert._id },
        { $set: { areas: mergedAreas } }
      );

      logInfo("oref_alert_areas_merged", {
        existingAlertId: existingAlert.alertId,
        incomingAlertId: normalized.alertId,
        previousAreasCount: existingAlert.areas.length,
        newAreasCount: newAreas.length,
        totalAreasCount: mergedAreas.length
      });

      // Fanout using the ORIGINAL alertId (so delivery log dedup works across waves)
      const mergedNormalized = {
        ...normalized,
        alertId: existingAlert.alertId,
        areas: mergedAreas
      };
      const fanoutResult = await fanoutAlertToSubscribedDevices(mergedNormalized, {
        limitToAreas: newAreas
      });
      if (fanoutResult.matchedSubscriptions > 0) {
        logInfo("alert_fanout_completed", {
          alertId: existingAlert.alertId,
          matchedSubscriptions: fanoutResult.matchedSubscriptions,
          sent: fanoutResult.sent,
          failed: fanoutResult.failed,
          newAreas
        });
      }

      updatedCount += 1;
      continue;
    }

    await AlertModel.create({
      alertId: normalized.alertId,
      title: normalized.title,
      category: normalized.category,
      areas: normalized.areas,
      desc: normalized.desc,
      sourceTimestamp: normalized.sourceTimestamp,
      ingestedAt: new Date()
    });

    try {
      await appendAlertToLog(normalized);
    } catch (error) {
      logWarn("oref_alert_file_append_failed", {
        alertId: normalized.alertId,
        error: error instanceof Error ? error.message : String(error)
      });
    }

    const fanoutResult = await fanoutAlertToSubscribedDevices(normalized);
    if (fanoutResult.matchedSubscriptions > 0) {
      logInfo("alert_fanout_completed", {
        alertId: normalized.alertId,
        matchedSubscriptions: fanoutResult.matchedSubscriptions,
        sent: fanoutResult.sent,
        failed: fanoutResult.failed
      });
    }

    logInfo("oref_alert_inserted", {
      alertId: normalized.alertId,
      category: normalized.category,
      areasCount: normalized.areas.length
    });

    insertedCount += 1;
  }

  logInfo("oref_poll_processed", {
    rawCount: rawAlerts.length,
    insertedCount,
    updatedCount,
    duplicateCount
  });

  return insertedCount;
}

export function startOrefPoller(): void {
  if (!config.orefPollerEnabled) {
    logInfo("oref_poller_disabled_by_config");
    return;
  }

  if (pollTimer) {
    logWarn("oref_poller_start_skipped_already_running");
    return;
  }

  const executePoll = async (): Promise<void> => {
    if (isPolling) {
      return;
    }

    isPolling = true;
    const startedAt = Date.now();
    try {
      const insertedCount = await pollOrefOnce();
      const durationMs = Date.now() - startedAt;
      logInfo("oref_poller_tick_completed", { insertedCount, durationMs });
    } catch (error) {
      logError("oref_poller_tick_failed", error);
    } finally {
      isPolling = false;
    }
  };

  logInfo("oref_poller_started", { intervalMs: config.orefPollIntervalMs });
  void executePoll();
  pollTimer = setInterval(() => {
    void executePoll();
  }, config.orefPollIntervalMs);
}

export function stopOrefPoller(): void {
  if (!pollTimer) {
    logWarn("oref_poller_stop_skipped_not_running");
    return;
  }

  clearInterval(pollTimer);
  pollTimer = null;
  logInfo("oref_poller_stopped");
}
