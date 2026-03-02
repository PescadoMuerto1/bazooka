import { Schema, model } from "mongoose";

interface Alert {
  alertId: string;
  title: string;
  category: string;
  areas: string[];
  desc: string;
  sourceTimestamp: Date | null;
  ingestedAt: Date;
}

const alertSchema = new Schema<Alert>(
  {
    alertId: { type: String, required: true, unique: true, index: true },
    title: { type: String, required: true },
    category: { type: String, required: true },
    areas: { type: [String], required: true, default: [] },
    desc: { type: String, required: true, default: "" },
    sourceTimestamp: { type: Date, required: false, default: null },
    ingestedAt: { type: Date, required: true, default: Date.now, index: true }
  },
  {
    versionKey: false
  }
);

export const AlertModel = model<Alert>("Alert", alertSchema, "alerts");
