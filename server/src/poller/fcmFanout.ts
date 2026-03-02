import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging, type Messaging } from "firebase-admin/messaging";
import { config } from "../config.js";
import { mapAlertAreasToCityKeys } from "../data/cities.js";
import { DeliveryModel } from "../models/delivery.js";
import { DeviceModel } from "../models/device.js";
import { SubscriptionModel } from "../models/subscription.js";
import type { NormalizedAlert } from "../types.js";

let messagingClient: Messaging | null | undefined;

function getServiceAccountPath(): string | null {
  if (config.firebaseServiceAccountPath) {
    const absolute = path.resolve(config.firebaseServiceAccountPath);
    if (existsSync(absolute)) {
      return absolute;
    }
  }

  const defaultPath = path.resolve(process.cwd(), "serviceAccountKey.json");
  if (existsSync(defaultPath)) {
    return defaultPath;
  }

  return null;
}

function initFirebaseMessaging(): Messaging | null {
  if (!config.fcmEnabled) {
    return null;
  }

  if (messagingClient !== undefined) {
    return messagingClient;
  }

  try {
    if (getApps().length === 0) {
      const serviceAccountPath = getServiceAccountPath();
      if (serviceAccountPath) {
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
        initializeApp();
      }
    }

    messagingClient = getMessaging();
    return messagingClient;
  } catch (error) {
    console.error("FCM initialization failed", error);
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
    return { matchedSubscriptions: 0, sent: 0, failed: 0 };
  }

  const subscriptions = await SubscriptionModel.find({
    cityKey: { $in: candidateCityKeys }
  }).exec();

  if (subscriptions.length === 0) {
    return { matchedSubscriptions: 0, sent: 0, failed: 0 };
  }

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
      continue;
    }

    const device = devicesById.get(subscription.deviceId);
    if (!device) {
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
      await messaging.send({
        token: device.fcmToken,
        notification: {
          title: alert.title,
          body: alert.desc.length > 0 ? alert.desc : "New Home Front alert"
        },
        data: {
          alertId: alert.alertId,
          category: alert.category,
          areas: alert.areas.join(",")
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
      sent += 1;
    } catch (error) {
      await createDeliveryLog({
        alertId: alert.alertId,
        deviceId: subscription.deviceId,
        status: "failed",
        error: sanitizeError(error)
      });
      failed += 1;
    }
  }

  return {
    matchedSubscriptions: subscriptions.length,
    sent,
    failed
  };
}
