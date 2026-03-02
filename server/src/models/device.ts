import { Schema, model } from "mongoose";

interface Device {
  deviceId: string;
  fcmToken: string;
  platform: "android";
  appVersion: string;
  locale: string;
  updatedAt: Date;
}

const deviceSchema = new Schema<Device>(
  {
    deviceId: { type: String, required: true, unique: true, index: true },
    fcmToken: { type: String, required: true },
    platform: { type: String, required: true, default: "android", enum: ["android"] },
    appVersion: { type: String, required: true },
    locale: { type: String, required: true },
    updatedAt: { type: Date, required: true, default: Date.now }
  },
  {
    versionKey: false
  }
);

export const DeviceModel = model<Device>("Device", deviceSchema, "devices");
