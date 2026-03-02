import { Schema, model } from "mongoose";

type DeliveryStatus = "sent" | "failed";

interface Delivery {
  deliveryId: string;
  alertId: string;
  deviceId: string;
  status: DeliveryStatus;
  error: string | null;
  createdAt: Date;
}

const deliverySchema = new Schema<Delivery>(
  {
    deliveryId: { type: String, required: true, unique: true, index: true },
    alertId: { type: String, required: true, index: true },
    deviceId: { type: String, required: true, index: true },
    status: { type: String, required: true, enum: ["sent", "failed"] },
    error: { type: String, required: false, default: null },
    createdAt: { type: Date, required: true, default: Date.now, index: true }
  },
  {
    versionKey: false
  }
);

export const DeliveryModel = model<Delivery>("Delivery", deliverySchema, "deliveries");
