import { Schema, model } from "mongoose";

type SupportedLanguage = "he" | "en" | "ru" | "ar";

interface Subscription {
  deviceId: string;
  cityKey: string;
  cityDisplay: string;
  lang: SupportedLanguage;
  updatedAt: Date;
}

const subscriptionSchema = new Schema<Subscription>(
  {
    deviceId: { type: String, required: true, unique: true, index: true },
    cityKey: { type: String, required: true },
    cityDisplay: { type: String, required: true },
    lang: { type: String, required: true, enum: ["he", "en", "ru", "ar"] },
    updatedAt: { type: Date, required: true, default: Date.now }
  },
  {
    versionKey: false
  }
);

export const SubscriptionModel = model<Subscription>(
  "Subscription",
  subscriptionSchema,
  "subscriptions"
);
