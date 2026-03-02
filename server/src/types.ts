export interface RawOrefAlert {
  id?: string | number;
  alertId?: string | number;
  title?: string;
  cat?: string | number;
  category?: string | number;
  desc?: string;
  description?: string;
  data?: unknown;
  alerts?: unknown;
  cities?: unknown;
  alertDate?: string;
  sourceTimestamp?: string;
  [key: string]: unknown;
}

export interface NormalizedAlert {
  alertId: string;
  title: string;
  category: string;
  areas: string[];
  desc: string;
  sourceTimestamp: Date | null;
}
