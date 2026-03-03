import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging, type Messaging } from "firebase-admin/messaging";
import { config } from "../config.js";
import { mapAlertAreasToCityKeys } from "../data/cities.js";
import { logError, logInfo, logWarn } from "../logger.js";
import { DeliveryModel } from "../models/delivery.js";
import { DeviceModel } from "../models/device.js";
import { SubscriptionModel } from "../models/subscription.js";
import type { NormalizedAlert } from "../types.js";

let messagingClient: Messaging | null | undefined;
const SERVER_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const MAX_TITLE_LENGTH = 120;
const MAX_BODY_LENGTH = 220;

function getFirstExistingPath(candidates: string[]): string | null {
  for (const candidate of candidates) {
    if (existsSync(candidate)) {
      return candidate;
    }
  }

  return null;
}

function getServiceAccountPath(): string | null {
  if (config.firebaseServiceAccountPath) {
    const configuredPath = config.firebaseServiceAccountPath;
    const candidates = path.isAbsolute(configuredPath)
      ? [configuredPath]
      : [path.resolve(SERVER_ROOT, configuredPath), path.resolve(process.cwd(), configuredPath)];

    const resolved = getFirstExistingPath(candidates);
    if (resolved) {
      return resolved;
    }

    logWarn("fcm_service_account_path_not_found", {
      configuredPath,
      cwd: process.cwd(),
      candidates
    });
  }

  const defaultPath = getFirstExistingPath([
    path.resolve(SERVER_ROOT, "serviceAccountKey.json"),
    path.resolve(process.cwd(), "serviceAccountKey.json")
  ]);
  if (defaultPath) {
    return defaultPath;
  }

  return null;
}

function initFirebaseMessaging(): Messaging | null {
  if (!config.fcmEnabled) {
    logInfo("fcm_disabled_by_config");
    return null;
  }

  if (messagingClient !== undefined) {
    return messagingClient;
  }

  try {
    if (getApps().length === 0) {
      const serviceAccountPath = getServiceAccountPath();
      if (serviceAccountPath) {
        logInfo("fcm_init_using_service_account_file", { serviceAccountPath });
        const fileContent = readFileSync(serviceAccountPath, "utf8");
        const serviceAccountJson = JSON.parse(fileContent) as Record<string, unknown>;
        initializeApp({
          credential: cert(serviceAccountJson as {
            projectId: string;
            clientEmail: string;
            privateKey: string;
          })
        });
      } else {
        logInfo("fcm_init_using_default_credentials");
        initializeApp();
      }
    }

    messagingClient = getMessaging();
    logInfo("fcm_init_succeeded");
    return messagingClient;
  } catch (error) {
    logError("fcm_init_failed", error);
    messagingClient = null;
    return null;
  }
}

function buildDeliveryId(alertId: string, deviceId: string): string {
  return `${alertId}:${deviceId}`;
}

function sanitizeError(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  return String(error);
}

function truncateText(value: string, maxLength: number): string {
  if (value.length <= maxLength) {
    return value;
  }

  if (maxLength <= 3) {
    return value.slice(0, maxLength);
  }

  return `${value.slice(0, maxLength - 3)}...`;
}

function deriveAlertType(alert: NormalizedAlert): "rocket_active" | "uav_active" | "pre_alert" | "all_clear" | "update" {
  if (alert.category === "1") {
    return "rocket_active";
  }

  if (alert.category === "6") {
    return "uav_active";
  }

  if (alert.category === "10") {
    const title = alert.title.trim();
    if (title.includes("בדקות הקרובות")) {
      return "pre_alert";
    }
    if (title.includes("האירוע הסתיים")) {
      return "all_clear";
    }
    return "update";
  }

  return "update";
}

async function createDeliveryLog(input: {
  alertId: string;
  deviceId: string;
  status: "sent" | "failed";
  error?: string | null;
}): Promise<void> {
  await DeliveryModel.create({
    deliveryId: buildDeliveryId(input.alertId, input.deviceId),
    alertId: input.alertId,
    deviceId: input.deviceId,
    status: input.status,
    error: input.error ?? null,
    createdAt: new Date()
  });
}

export async function fanoutAlertToSubscribedDevices(
  alert: NormalizedAlert
): Promise<{ matchedSubscriptions: number; sent: number; failed: number }> {
  const candidateCityKeys = mapAlertAreasToCityKeys(alert.areas);
  if (candidateCityKeys.length === 0) {
    logInfo("fanout_skipped_no_candidate_city_keys", { alertId: alert.alertId });
    return { matchedSubscriptions: 0, sent: 0, failed: 0 };
  }

  const subscriptions = await SubscriptionModel.find({
    cityKey: { $in: candidateCityKeys }
  }).exec();

  if (subscriptions.length === 0) {
    logInfo("fanout_skipped_no_subscriptions", {
      alertId: alert.alertId,
      candidateCityKeys
    });
    return { matchedSubscriptions: 0, sent: 0, failed: 0 };
  }

  logInfo("fanout_started", {
    alertId: alert.alertId,
    subscriptionCount: subscriptions.length
  });

  const deviceIds = subscriptions.map((subscription) => subscription.deviceId);
  const devices = await DeviceModel.find({ deviceId: { $in: deviceIds } }).exec();
  const devicesById = new Map<string, (typeof devices)[number]>(
    devices.map((device) => [device.deviceId, device])
  );

  const messaging = initFirebaseMessaging();

  let sent = 0;
  let failed = 0;

  for (const subscription of subscriptions) {
    const deliveryId = buildDeliveryId(alert.alertId, subscription.deviceId);
    const deliveryExists = await DeliveryModel.exists({ deliveryId });
    if (deliveryExists) {
      logInfo("fanout_delivery_skipped_already_exists", {
        alertId: alert.alertId,
        deviceId: subscription.deviceId
      });
      continue;
    }

    const device = devicesById.get(subscription.deviceId);
    if (!device) {
      logWarn("fanout_device_missing", {
        alertId: alert.alertId,
        deviceId: subscription.deviceId
      });
      await createDeliveryLog({
        alertId: alert.alertId,
        deviceId: subscription.deviceId,
        status: "failed",
        error: "Registered device record was not found for this subscription"
      });
      failed += 1;
      continue;
    }

    if (!messaging) {
      logWarn("fanout_skipped_fcm_not_initialized", {
        alertId: alert.alertId,
        deviceId: subscription.deviceId
      });
      await createDeliveryLog({
        alertId: alert.alertId,
        deviceId: subscription.deviceId,
        status: "failed",
        error: "FCM is not initialized"
      });
      failed += 1;
      continue;
    }

    try {
      const messageTitle = truncateText(alert.title, MAX_TITLE_LENGTH);
      const messageBody = truncateText(
        alert.desc.length > 0 ? alert.desc : "New Home Front alert",
        MAX_BODY_LENGTH
      );
      const alertType = deriveAlertType(alert);

      await messaging.send({
        token: device.fcmToken,
        data: {
          alertId: alert.alertId,
          type: alertType,
          title: messageTitle,
          body: messageBody,
          areasCount: String(alert.areas.length),
          matchedCityKey: subscription.cityKey
        },
        android: {
          priority: "high"
        }
      });

      await createDeliveryLog({
        alertId: alert.alertId,
        deviceId: subscription.deviceId,
        status: "sent"
      });
      logInfo("fanout_send_succeeded", {
        alertId: alert.alertId,
        deviceId: subscription.deviceId
      });
      sent += 1;
    } catch (error) {
      logWarn("fanout_send_failed", {
        alertId: alert.alertId,
        deviceId: subscription.deviceId,
        error: sanitizeError(error)
      });
      await createDeliveryLog({
        alertId: alert.alertId,
        deviceId: subscription.deviceId,
        status: "failed",
        error: sanitizeError(error)
      });
      failed += 1;
    }
  }

  const result = {
    matchedSubscriptions: subscriptions.length,
    sent,
    failed
  };
  logInfo("fanout_completed", {
    alertId: alert.alertId,
    ...result
  });
  return result;
}
