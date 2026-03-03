import { randomUUID } from "node:crypto";
import { Router } from "express";
import { logError, logInfo, logWarn } from "../logger.js";
import { AlertModel } from "../models/alert.js";
import { DeliveryModel } from "../models/delivery.js";
import { DeviceModel } from "../models/device.js";
import { SubscriptionModel } from "../models/subscription.js";
import { fanoutAlertToSubscribedDevices } from "../poller/fcmFanout.js";
import type { NormalizedAlert } from "../types.js";

const devToolsRouter = Router();
const MAX_TEXT_FIELD_LENGTH = 200;
const MAX_AREAS_COUNT = 25;
type SupportedAlertType = "rocket_active" | "uav_active" | "pre_alert" | "all_clear";

const ALERT_TYPE_PRESETS: Record<
  SupportedAlertType,
  { category: string; title: string; desc: string }
> = {
  rocket_active: {
    category: "1",
    title: "ירי רקטות וטילים",
    desc: "היכנסו למרחב המוגן"
  },
  uav_active: {
    category: "6",
    title: "חדירת כלי טיס עוין",
    desc: "היכנסו מייד למרחב המוגן"
  },
  pre_alert: {
    category: "10",
    title: "בדקות הקרובות צפויות להתקבל התרעות באזורך",
    desc:
      "על תושבי האזורים הבאים לשפר את המיקום למיגון המיטבי בקרבתך. במקרה של קבלת התרעה, יש להיכנס למרחב המוגן."
  },
  all_clear: {
    category: "10",
    title: "ירי רקטות וטילים -  האירוע הסתיים",
    desc: "השוהים במרחב המוגן יכולים לצאת. בעת קבלת הנחיה או התרעה, יש לפעול בהתאם להנחיות פיקוד העורף."
  }
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function getOptionalString(value: unknown, fallback: string): string {
  if (typeof value !== "string") {
    return fallback;
  }

  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return fallback;
  }

  if (trimmed.length > MAX_TEXT_FIELD_LENGTH) {
    throw new Error(`Field is too long (max ${MAX_TEXT_FIELD_LENGTH} chars)`);
  }

  return trimmed;
}

function parseAreas(rawAreas: unknown): string[] {
  const values: string[] = [];

  if (typeof rawAreas === "string") {
    values.push(...rawAreas.split(/[,|\n]/g));
  } else if (Array.isArray(rawAreas)) {
    for (const item of rawAreas) {
      if (typeof item === "string") {
        values.push(item);
      }
    }
  }

  const unique = new Set<string>();
  for (const value of values) {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      continue;
    }
    if (trimmed.length > MAX_TEXT_FIELD_LENGTH) {
      throw new Error(`Area value is too long (max ${MAX_TEXT_FIELD_LENGTH} chars)`);
    }
    unique.add(trimmed);
    if (unique.size >= MAX_AREAS_COUNT) {
      break;
    }
  }

  return Array.from(unique);
}

function parsePersistToDatabase(rawValue: unknown): boolean {
  if (typeof rawValue === "boolean") {
    return rawValue;
  }

  if (typeof rawValue === "string") {
    const normalized = rawValue.trim().toLowerCase();
    if (normalized === "false" || normalized === "0" || normalized === "off") {
      return false;
    }
  }

  return true;
}

function resolveAlertTypePreset(
  rawType: unknown
): { type: SupportedAlertType; category: string; title: string; desc: string } | null {
  if (typeof rawType !== "string") {
    return null;
  }

  const normalized = rawType.trim() as SupportedAlertType;
  if (!(normalized in ALERT_TYPE_PRESETS)) {
    return null;
  }

  return {
    type: normalized,
    ...ALERT_TYPE_PRESETS[normalized]
  };
}

function isSyntheticAlertId(alertId: string): boolean {
  return alertId.startsWith("test-") || alertId.startsWith("dup-");
}

function buildTestAlert(input: {
  title?: unknown;
  desc?: unknown;
  category?: unknown;
  areas?: unknown;
  alertType?: unknown;
}): NormalizedAlert {
  const areas = parseAreas(input.areas);
  const resolvedAreas = areas.length > 0 ? areas : ["תל אביב"];
  const typePreset = resolveAlertTypePreset(input.alertType);
  const fallbackTitle = typePreset ? typePreset.title : "Bazooka Test Alert";
  const fallbackDesc = typePreset ? typePreset.desc : "Test notification from backend dev tools";
  const fallbackCategory = typePreset ? typePreset.category : "test";

  return {
    alertId: `test-${Date.now()}-${randomUUID().slice(0, 8)}`,
    title: getOptionalString(input.title, fallbackTitle),
    desc: getOptionalString(input.desc, fallbackDesc),
    category: getOptionalString(input.category, fallbackCategory),
    areas: resolvedAreas,
    sourceTimestamp: new Date()
  };
}

function renderDevToolsHtml(): string {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bazooka Dev Tools</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f4f6fb;
      --card: #ffffff;
      --ink: #0f172a;
      --muted: #475569;
      --border: #dbe3f0;
      --brand: #2563eb;
      --brand-2: #1d4ed8;
      --good: #166534;
      --bad: #991b1b;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 24px;
      font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
      background: radial-gradient(circle at 10% 0%, #e8efff 0%, var(--bg) 45%, #eef2ff 100%);
      color: var(--ink);
    }
    .wrap {
      max-width: 960px;
      margin: 0 auto;
      display: grid;
      gap: 16px;
    }
    .card {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 16px;
      box-shadow: 0 8px 24px rgba(15, 23, 42, 0.06);
    }
    h1, h2 { margin: 0 0 12px; }
    h1 { font-size: 24px; }
    h2 { font-size: 18px; color: var(--muted); }
    .row {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      margin-bottom: 10px;
    }
    button {
      border: 0;
      border-radius: 10px;
      padding: 10px 14px;
      cursor: pointer;
      font-weight: 700;
      background: var(--brand);
      color: white;
    }
    button:hover { background: var(--brand-2); }
    button.secondary {
      background: #e2e8f0;
      color: #0f172a;
    }
    input, textarea, select {
      width: 100%;
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 10px;
      font: inherit;
      margin-bottom: 10px;
      background: #fff;
    }
    .meta {
      margin: 0 0 12px;
      font-size: 13px;
      color: var(--muted);
    }
    pre {
      margin: 0;
      white-space: pre-wrap;
      word-break: break-word;
      border-radius: 10px;
      border: 1px solid var(--border);
      background: #0b1020;
      color: #dbeafe;
      padding: 12px;
      min-height: 140px;
    }
    .status {
      margin: 8px 0 0;
      font-size: 13px;
      font-weight: 700;
    }
    .status.good { color: var(--good); }
    .status.bad { color: var(--bad); }
  </style>
</head>
<body>
  <div class="wrap">
    <section class="card">
      <h1>Bazooka Backend Dev Tools</h1>
      <p class="meta">Use these buttons to send fake alerts through the real backend fanout and verify app notifications/popup flow.</p>
      <div class="row">
        <button id="btnTelAviv">Send Tel Aviv Test</button>
        <button id="btnHaifa">Send Haifa Test</button>
        <button id="btnJerusalem">Send Jerusalem Test</button>
        <button id="btnBeitShemesh">Send Beit Shemesh Test</button>
        <button id="btnMulti">Send Multi-City Test</button>
      </div>
      <div class="status" id="quickStatus"></div>
    </section>

    <section class="card">
      <h2>Custom Test Alert</h2>
      <label for="alertType">Alert Type Preset</label>
      <select id="alertType">
        <option value="rocket_active">rocket_active</option>
        <option value="uav_active">uav_active</option>
        <option value="pre_alert">pre_alert</option>
        <option value="all_clear">all_clear</option>
      </select>
      <label for="title">Title</label>
      <input id="title" value="Bazooka Manual Test" />
      <label for="desc">Description</label>
      <textarea id="desc" rows="2">Manual test alert triggered from /dev/tools</textarea>
      <label for="cityPreset">City Preset</label>
      <select id="cityPreset">
        <option value="תל אביב">תל אביב</option>
        <option value="חיפה">חיפה</option>
        <option value="ירושלים">ירושלים</option>
        <option value="בית שמש">בית שמש</option>
        <option value="__custom__">Custom (manual areas)</option>
      </select>
      <label for="areas">Areas (comma-separated)</label>
      <input id="areas" value="תל אביב" />
      <label for="category">Category</label>
      <input id="category" value="test" />
      <div class="row">
        <label><input type="checkbox" id="persist" checked /> Persist to alerts collection</label>
      </div>
      <div class="row">
        <button id="btnSendCustom">Send Custom Alert</button>
      </div>
      <div class="status" id="customStatus"></div>
    </section>

    <section class="card">
      <h2>Duplicate Real Alert</h2>
      <p class="meta">Clone a real ingested OREF alert and send it again with a new duplicate alertId.</p>
      <label for="duplicateAlertId">Source Alert</label>
      <select id="duplicateAlertId"></select>
      <div class="row">
        <label><input type="checkbox" id="persistDuplicate" checked /> Persist duplicate to alerts collection</label>
      </div>
      <div class="row">
        <button id="btnSendDuplicate">Send Duplicate of Selected Alert</button>
      </div>
      <div class="status" id="duplicateStatus"></div>
    </section>

    <section class="card">
      <h2>Backend State</h2>
      <div class="row">
        <button class="secondary" id="btnRefreshState">Refresh state</button>
      </div>
      <pre id="stateOutput"></pre>
    </section>

    <section class="card">
      <h2>Last API Response</h2>
      <pre id="apiOutput"></pre>
    </section>
  </div>

  <script>
    const apiOutput = document.getElementById("apiOutput");
    const stateOutput = document.getElementById("stateOutput");
    const quickStatus = document.getElementById("quickStatus");
    const customStatus = document.getElementById("customStatus");
    const duplicateStatus = document.getElementById("duplicateStatus");
    const cityPreset = document.getElementById("cityPreset");
    const areasInput = document.getElementById("areas");
    const presetCityValues = new Set(["תל אביב", "חיפה", "ירושלים", "בית שמש"]);
    const alertTypePresets = {
      rocket_active: {
        category: "1",
        title: "ירי רקטות וטילים",
        desc: "היכנסו למרחב המוגן"
      },
      uav_active: {
        category: "6",
        title: "חדירת כלי טיס עוין",
        desc: "היכנסו מייד למרחב המוגן"
      },
      pre_alert: {
        category: "10",
        title: "בדקות הקרובות צפויות להתקבל התרעות באזורך",
        desc: "על תושבי האזורים הבאים לשפר את המיקום למיגון המיטבי בקרבתך. במקרה של קבלת התרעה, יש להיכנס למרחב המוגן."
      },
      all_clear: {
        category: "10",
        title: "ירי רקטות וטילים -  האירוע הסתיים",
        desc: "השוהים במרחב המוגן יכולים לצאת. בעת קבלת הנחיה או התרעה, יש לפעול בהתאם להנחיות פיקוד העורף."
      }
    };

    async function sendAlert(payload) {
      const response = await fetch("/dev/tools/send-alert", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const data = await response.json();
      apiOutput.textContent = JSON.stringify(data, null, 2);
      return { ok: response.ok, data };
    }

    async function sendDuplicate(payload) {
      const response = await fetch("/dev/tools/duplicate-alert", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const data = await response.json();
      apiOutput.textContent = JSON.stringify(data, null, 2);
      return { ok: response.ok, data };
    }

    function populateRealAlerts(alerts) {
      const select = document.getElementById("duplicateAlertId");
      select.innerHTML = "";

      if (!Array.isArray(alerts) || alerts.length === 0) {
        const option = document.createElement("option");
        option.value = "";
        option.textContent = "No real alerts available";
        select.appendChild(option);
        select.disabled = true;
        return;
      }

      select.disabled = false;
      for (const alert of alerts) {
        const option = document.createElement("option");
        option.value = alert.alertId;
        option.textContent =
          alert.alertId +
          " | cat " + alert.category +
          " | " + alert.areasCount + " areas | " +
          (alert.title || "");
        select.appendChild(option);
      }
    }

    async function refreshState() {
      const response = await fetch("/dev/tools/state");
      const data = await response.json();
      stateOutput.textContent = JSON.stringify(data, null, 2);
      populateRealAlerts(data.recentRealAlerts || []);
    }

    function setStatus(node, ok, message) {
      node.textContent = message;
      node.className = "status " + (ok ? "good" : "bad");
    }

    function applyCityPresetToAreas() {
      const selectedCity = cityPreset.value;
      if (selectedCity === "__custom__") {
        return;
      }

      areasInput.value = selectedCity;
    }

    function syncCityPresetFromAreas() {
      const normalized = areasInput.value.trim();
      if (presetCityValues.has(normalized)) {
        cityPreset.value = normalized;
        return;
      }

      cityPreset.value = "__custom__";
    }

    function applyTypePresetToFields() {
      const selectedType = document.getElementById("alertType").value;
      const preset = alertTypePresets[selectedType];
      if (!preset) {
        return;
      }

      document.getElementById("title").value = preset.title;
      document.getElementById("desc").value = preset.desc;
      document.getElementById("category").value = preset.category;
    }

    document.getElementById("btnTelAviv").addEventListener("click", async () => {
      const result = await sendAlert({
        title: "Tel Aviv Test Alert",
        desc: "Quick test from backend dev tools",
        areas: ["תל אביב"],
        category: "test"
      });
      setStatus(quickStatus, result.ok, result.ok ? "Tel Aviv alert sent" : "Failed to send Tel Aviv alert");
      await refreshState();
    });

    document.getElementById("btnHaifa").addEventListener("click", async () => {
      const result = await sendAlert({
        title: "Haifa Test Alert",
        desc: "Quick test from backend dev tools",
        areas: ["חיפה"],
        category: "test"
      });
      setStatus(quickStatus, result.ok, result.ok ? "Haifa alert sent" : "Failed to send Haifa alert");
      await refreshState();
    });

    document.getElementById("btnJerusalem").addEventListener("click", async () => {
      const result = await sendAlert({
        title: "Jerusalem Test Alert",
        desc: "Quick test from backend dev tools",
        areas: ["ירושלים"],
        category: "test"
      });
      setStatus(quickStatus, result.ok, result.ok ? "Jerusalem alert sent" : "Failed to send Jerusalem alert");
      await refreshState();
    });

    document.getElementById("btnBeitShemesh").addEventListener("click", async () => {
      const result = await sendAlert({
        title: "Beit Shemesh Test Alert",
        desc: "Quick test from backend dev tools",
        areas: ["בית שמש"],
        category: "test"
      });
      setStatus(
        quickStatus,
        result.ok,
        result.ok ? "Beit Shemesh alert sent" : "Failed to send Beit Shemesh alert"
      );
      await refreshState();
    });

    document.getElementById("btnMulti").addEventListener("click", async () => {
      const result = await sendAlert({
        title: "Multi-city Test Alert",
        desc: "Quick test from backend dev tools",
        areas: ["תל אביב", "חיפה"],
        category: "test"
      });
      setStatus(quickStatus, result.ok, result.ok ? "Multi-city alert sent" : "Failed to send multi-city alert");
      await refreshState();
    });

    document.getElementById("btnSendCustom").addEventListener("click", async () => {
      const payload = {
        alertType: document.getElementById("alertType").value,
        title: document.getElementById("title").value,
        desc: document.getElementById("desc").value,
        areas: document.getElementById("areas").value,
        category: document.getElementById("category").value,
        persistToDatabase: document.getElementById("persist").checked
      };
      const result = await sendAlert(payload);
      setStatus(customStatus, result.ok, result.ok ? "Custom alert sent" : "Failed to send custom alert");
      await refreshState();
    });

    document.getElementById("btnSendDuplicate").addEventListener("click", async () => {
      const payload = {
        sourceAlertId: document.getElementById("duplicateAlertId").value,
        persistToDatabase: document.getElementById("persistDuplicate").checked
      };
      const result = await sendDuplicate(payload);
      setStatus(
        duplicateStatus,
        result.ok,
        result.ok ? "Duplicate real alert sent" : "Failed to send duplicate real alert"
      );
      await refreshState();
    });

    cityPreset.addEventListener("change", applyCityPresetToAreas);
    areasInput.addEventListener("input", syncCityPresetFromAreas);
    document.getElementById("alertType").addEventListener("change", applyTypePresetToFields);
    document.getElementById("btnRefreshState").addEventListener("click", refreshState);
    applyTypePresetToFields();
    syncCityPresetFromAreas();
    refreshState().catch((error) => {
      stateOutput.textContent = "Failed to load state: " + error;
    });
  </script>
</body>
</html>`;
}

devToolsRouter.get("/dev/tools", (_req, res) => {
  res.status(200).type("html").send(renderDevToolsHtml());
});

devToolsRouter.get("/dev/tools/state", async (_req, res) => {
  try {
    const [devices, subscriptions, deliveries, recentAlerts] = await Promise.all([
      DeviceModel.find({}).sort({ updatedAt: -1 }).limit(25).lean().exec(),
      SubscriptionModel.find({}).sort({ updatedAt: -1 }).limit(25).lean().exec(),
      DeliveryModel.find({}).sort({ createdAt: -1 }).limit(40).lean().exec(),
      AlertModel.find({}).sort({ ingestedAt: -1 }).limit(120).lean().exec()
    ]);
    const recentRealAlerts = recentAlerts
      .filter((alert) => typeof alert.alertId === "string" && !isSyntheticAlertId(alert.alertId))
      .slice(0, 30)
      .map((alert) => ({
        alertId: alert.alertId,
        title: alert.title,
        category: alert.category,
        areasCount: Array.isArray(alert.areas) ? alert.areas.length : 0,
        ingestedAt: alert.ingestedAt ?? null
      }));

    return res.status(200).json({
      ok: true,
      counts: {
        devices: devices.length,
        subscriptions: subscriptions.length,
        deliveries: deliveries.length,
        recentRealAlerts: recentRealAlerts.length
      },
      devices,
      subscriptions,
      deliveries,
      recentRealAlerts
    });
  } catch (error) {
    logError("dev_tools_state_failed", error);
    return res.status(500).json({ ok: false, error: "Could not fetch dev tools state" });
  }
});

devToolsRouter.post("/dev/tools/send-alert", async (req, res) => {
  try {
    if (!isRecord(req.body)) {
      return res.status(400).json({ ok: false, error: "Request body must be a JSON object" });
    }

    const alert = buildTestAlert({
      title: req.body.title,
      desc: req.body.desc,
      category: req.body.category,
      areas: req.body.areas,
      alertType: req.body.alertType
    });
    const resolvedTypePreset = resolveAlertTypePreset(req.body.alertType);
    const persistToDatabase = parsePersistToDatabase(req.body.persistToDatabase);

    if (persistToDatabase) {
      await AlertModel.create({
        alertId: alert.alertId,
        title: alert.title,
        category: alert.category,
        areas: alert.areas,
        desc: alert.desc,
        sourceTimestamp: alert.sourceTimestamp,
        ingestedAt: new Date()
      });
    }

    const fanout = await fanoutAlertToSubscribedDevices(alert);

    logInfo("dev_tools_test_alert_sent", {
      alertId: alert.alertId,
      title: alert.title,
      alertType: resolvedTypePreset?.type ?? null,
      category: alert.category,
      areas: alert.areas,
      persistToDatabase,
      matchedSubscriptions: fanout.matchedSubscriptions,
      sent: fanout.sent,
      failed: fanout.failed
    });

    return res.status(200).json({
      ok: true,
      alert: {
        alertId: alert.alertId,
        title: alert.title,
        type: resolvedTypePreset?.type ?? null,
        category: alert.category,
        areas: alert.areas,
        desc: alert.desc,
        sourceTimestamp: alert.sourceTimestamp
      },
      persistToDatabase,
      fanout
    });
  } catch (error) {
    if (error instanceof Error && error.message.includes("max")) {
      logWarn("dev_tools_test_alert_bad_request", { reason: error.message });
      return res.status(400).json({ ok: false, error: error.message });
    }

    logError("dev_tools_test_alert_failed", error);
    return res.status(500).json({ ok: false, error: "Could not send test alert" });
  }
});

devToolsRouter.post("/dev/tools/duplicate-alert", async (req, res) => {
  try {
    if (!isRecord(req.body)) {
      return res.status(400).json({ ok: false, error: "Request body must be a JSON object" });
    }

    const rawSourceAlertId = typeof req.body.sourceAlertId === "string" ? req.body.sourceAlertId.trim() : "";
    const sourceAlertId = rawSourceAlertId.length > 0 ? rawSourceAlertId : null;
    const persistToDatabase = parsePersistToDatabase(req.body.persistToDatabase);

    const sourceAlert = sourceAlertId
      ? await AlertModel.findOne({ alertId: sourceAlertId }).lean().exec()
      : await AlertModel.find({}).sort({ ingestedAt: -1 }).limit(120).lean().exec().then((alerts) =>
          alerts.find((alert) => typeof alert.alertId === "string" && !isSyntheticAlertId(alert.alertId)) ?? null
        );

    if (!sourceAlert) {
      return res.status(404).json({ ok: false, error: "Could not find source alert to duplicate" });
    }

    if (typeof sourceAlert.alertId !== "string") {
      return res.status(400).json({ ok: false, error: "Source alert has invalid alertId" });
    }

    const resolvedAreas = Array.isArray(sourceAlert.areas)
      ? sourceAlert.areas.filter((area): area is string => typeof area === "string")
      : [];
    const duplicatedAlert: NormalizedAlert = {
      alertId: `dup-${Date.now()}-${randomUUID().slice(0, 8)}`,
      title: typeof sourceAlert.title === "string" ? sourceAlert.title : "Duplicated Alert",
      desc: typeof sourceAlert.desc === "string" ? sourceAlert.desc : "",
      category: typeof sourceAlert.category === "string" ? sourceAlert.category : "unknown",
      areas: resolvedAreas,
      sourceTimestamp:
        sourceAlert.sourceTimestamp instanceof Date
          ? sourceAlert.sourceTimestamp
          : sourceAlert.sourceTimestamp
            ? new Date(sourceAlert.sourceTimestamp)
            : new Date()
    };

    if (persistToDatabase) {
      await AlertModel.create({
        alertId: duplicatedAlert.alertId,
        title: duplicatedAlert.title,
        category: duplicatedAlert.category,
        areas: duplicatedAlert.areas,
        desc: duplicatedAlert.desc,
        sourceTimestamp: duplicatedAlert.sourceTimestamp,
        ingestedAt: new Date()
      });
    }

    const fanout = await fanoutAlertToSubscribedDevices(duplicatedAlert);
    logInfo("dev_tools_duplicate_alert_sent", {
      sourceAlertId: sourceAlert.alertId,
      duplicatedAlertId: duplicatedAlert.alertId,
      category: duplicatedAlert.category,
      areasCount: duplicatedAlert.areas.length,
      persistToDatabase,
      matchedSubscriptions: fanout.matchedSubscriptions,
      sent: fanout.sent,
      failed: fanout.failed
    });

    return res.status(200).json({
      ok: true,
      sourceAlertId: sourceAlert.alertId,
      alert: {
        alertId: duplicatedAlert.alertId,
        title: duplicatedAlert.title,
        category: duplicatedAlert.category,
        areasCount: duplicatedAlert.areas.length,
        sourceTimestamp: duplicatedAlert.sourceTimestamp
      },
      persistToDatabase,
      fanout
    });
  } catch (error) {
    logError("dev_tools_duplicate_alert_failed", error);
    return res.status(500).json({ ok: false, error: "Could not duplicate and send alert" });
  }
});

export default devToolsRouter;
