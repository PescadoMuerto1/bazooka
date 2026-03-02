const CITY_ALIASES: Record<string, string[]> = {
  "תל אביב": ["תל אביב", "תל אביב יפו", "תל אביב-יפו", "tel aviv", "tel aviv yafo", "tel-aviv"],
  ירושלים: ["ירושלים", "jerusalem"],
  חיפה: ["חיפה", "haifa"],
  אשקלון: ["אשקלון", "ashkelon"],
  אשדוד: ["אשדוד", "ashdod"],
  בארשבע: ["באר שבע", "באר-שבע", "be'er sheva", "beer sheva", "beersheba"],
  רמתגן: ["רמת גן", "רמת-גן", "ramat gan"],
  פתחתקווה: ["פתח תקווה", "פתח-תקווה", "petah tikva", "petach tikva"],
  נתניה: ["נתניה", "netanya"],
  "בית שמש": ["בית שמש", "beit shemesh"]
};

function normalizeText(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/['"`]/g, "")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .replace(/\s+/g, " ");
}

const aliasToCanonical = new Map<string, string>();
for (const [canonical, aliases] of Object.entries(CITY_ALIASES)) {
  const normalizedCanonical = normalizeText(canonical);
  aliasToCanonical.set(normalizedCanonical, canonical);

  for (const alias of aliases) {
    aliasToCanonical.set(normalizeText(alias), canonical);
  }
}

function lookupCanonicalCity(rawArea: string): string | null {
  const normalizedArea = normalizeText(rawArea);
  if (!normalizedArea) {
    return null;
  }

  const exact = aliasToCanonical.get(normalizedArea);
  if (exact) {
    return exact;
  }

  for (const [alias, canonical] of aliasToCanonical.entries()) {
    if (normalizedArea.includes(alias) || alias.includes(normalizedArea)) {
      return canonical;
    }
  }

  return null;
}

export function mapAlertAreasToCityKeys(areas: string[]): string[] {
  const unique = new Set<string>();

  for (const area of areas) {
    const trimmedArea = area.trim();
    if (!trimmedArea) {
      continue;
    }

    unique.add(trimmedArea);
    const canonical = lookupCanonicalCity(trimmedArea);
    if (canonical) {
      unique.add(canonical);
    }
  }

  return Array.from(unique);
}
