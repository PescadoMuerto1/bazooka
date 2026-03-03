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

function buildTestAlert(input: {
  title?: unknown;
  desc?: unknown;
  category?: unknown;
  areas?: unknown;
}): NormalizedAlert {
  const areas = parseAreas(input.areas);
  const resolvedAreas = areas.length > 0 ? areas : ["תל אביב"];

  return {
    alertId: `test-${Date.now()}-${randomUUID().slice(0, 8)}`,
    title: getOptionalString(input.title, "Bazooka Test Alert"),
    desc: getOptionalString(input.desc, "Test notification from backend dev tools"),
    category: getOptionalString(input.category, "test"),
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
    input, textarea {
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
        <button id="btnMulti">Send Multi-City Test</button>
      </div>
      <div class="status" id="quickStatus"></div>
    </section>

    <section class="card">
      <h2>Custom Test Alert</h2>
      <label for="title">Title</label>
      <input id="title" value="Bazooka Manual Test" />
      <label for="desc">Description</label>
      <textarea id="desc" rows="2">Manual test alert triggered from /dev/tools</textarea>
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

    async function refreshState() {
      const response = await fetch("/dev/tools/state");
      const data = await response.json();
      stateOutput.textContent = JSON.stringify(data, null, 2);
    }

    function setStatus(node, ok, message) {
      node.textContent = message;
      node.className = "status " + (ok ? "good" : "bad");
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

    document.getElementById("btnRefreshState").addEventListener("click", refreshState);
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
    const [devices, subscriptions, deliveries] = await Promise.all([
      DeviceModel.find({}).sort({ updatedAt: -1 }).limit(25).lean().exec(),
      SubscriptionModel.find({}).sort({ updatedAt: -1 }).limit(25).lean().exec(),
      DeliveryModel.find({}).sort({ createdAt: -1 }).limit(40).lean().exec()
    ]);

    return res.status(200).json({
      ok: true,
      counts: {
        devices: devices.length,
        subscriptions: subscriptions.length,
        deliveries: deliveries.length
      },
      devices,
      subscriptions,
      deliveries
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
      areas: req.body.areas
    });
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

export default devToolsRouter;
