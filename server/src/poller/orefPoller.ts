import { createHash } from "node:crypto";
import { config } from "../config.js";
import { AlertModel } from "../models/alert.js";
import type { NormalizedAlert, RawOrefAlert } from "../types.js";

let pollTimer: NodeJS.Timeout | null = null;
let isPolling = false;

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
    normalized.areas.join(","),
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

    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

export async function pollOrefOnce(): Promise<number> {
  const payload = await fetchOrefPayload();
  const rawAlerts = toRawAlerts(payload);

  if (rawAlerts.length === 0) {
    return 0;
  }

  let insertedCount = 0;
  for (const rawAlert of rawAlerts) {
    const normalized = normalizeAlert(rawAlert);
    if (!normalized) {
      continue;
    }

    const existing = await AlertModel.exists({ alertId: normalized.alertId });
    if (existing) {
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
    insertedCount += 1;
  }

  return insertedCount;
}

export function startOrefPoller(): void {
  if (!config.orefPollerEnabled) {
    console.log("Oref poller disabled by config");
    return;
  }

  if (pollTimer) {
    return;
  }

  const executePoll = async (): Promise<void> => {
    if (isPolling) {
      return;
    }

    isPolling = true;
    try {
      const insertedCount = await pollOrefOnce();
      if (insertedCount > 0) {
        console.log(`Oref poller ingested ${insertedCount} new alert(s)`);
      }
    } catch (error) {
      console.error("Oref poller run failed", error);
    } finally {
      isPolling = false;
    }
  };

  void executePoll();
  pollTimer = setInterval(() => {
    void executePoll();
  }, config.orefPollIntervalMs);
}

export function stopOrefPoller(): void {
  if (!pollTimer) {
    return;
  }

  clearInterval(pollTimer);
  pollTimer = null;
}
