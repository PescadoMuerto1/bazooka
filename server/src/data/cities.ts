type CityAliasGroup = {
  keys: string[];
  aliases: string[];
};

const CITY_ALIAS_GROUPS: CityAliasGroup[] = [
  {
    keys: ["תל אביב", "תל אביב - יפו"],
    aliases: [
      "תל אביב יפו",
      "תל אביב-יפו",
      "tel aviv",
      "tel aviv yafo",
      "tel-aviv"
    ]
  },
  {
    keys: ["ירושלים"],
    aliases: ["jerusalem"]
  },
  {
    keys: ["חיפה"],
    aliases: ["haifa"]
  },
  {
    keys: ["אשקלון"],
    aliases: ["ashkelon"]
  },
  {
    keys: ["אשדוד"],
    aliases: ["ashdod"]
  },
  {
    keys: ["בארשבע", "באר שבע"],
    aliases: ["באר-שבע", "be'er sheva", "beer sheva", "beersheba"]
  },
  {
    keys: ["רמתגן", "רמת גן"],
    aliases: ["רמת-גן", "ramat gan"]
  },
  {
    keys: ["פתחתקווה", "פתח תקווה"],
    aliases: ["פתח-תקווה", "petah tikva", "petach tikva"]
  },
  {
    keys: ["נתניה"],
    aliases: ["netanya"]
  },
  {
    keys: ["בית שמש"],
    aliases: ["beit shemesh"]
  }
];

function normalizeText(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/['"`]/g, "")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .replace(/\s+/g, " ");
}

const aliasToCityKeys = new Map<string, Set<string>>();
for (const group of CITY_ALIAS_GROUPS) {
  const groupKeys = Array.from(
    new Set(
      group.keys.map((key) => key.trim()).filter((key) => key.length > 0)
    )
  );
  if (groupKeys.length === 0) {
    continue;
  }

  const normalizedLookupTerms = Array.from(
    new Set(
      [...groupKeys, ...group.aliases]
        .map(normalizeText)
        .filter((value) => value.length > 0)
    )
  );

  for (const term of normalizedLookupTerms) {
    const existing = aliasToCityKeys.get(term);
    if (existing) {
      for (const key of groupKeys) {
        existing.add(key);
      }
      continue;
    }

    aliasToCityKeys.set(term, new Set(groupKeys));
  }
}

function lookupMappedCityKeys(rawArea: string): string[] {
  const normalizedArea = normalizeText(rawArea);
  if (!normalizedArea) {
    return [];
  }

  const exact = aliasToCityKeys.get(normalizedArea);
  if (exact) {
    return Array.from(exact);
  }

  const matches = new Set<string>();
  for (const [alias, keys] of aliasToCityKeys.entries()) {
    if (!normalizedArea.includes(alias) && !alias.includes(normalizedArea)) {
      continue;
    }
    for (const key of keys) {
      matches.add(key);
    }
  }

  return Array.from(matches);
}

export function mapAlertAreasToCityKeys(areas: string[]): string[] {
  const unique = new Set<string>();

  for (const area of areas) {
    const trimmedArea = area.trim();
    if (!trimmedArea) {
      continue;
    }

    unique.add(trimmedArea);
    const mappedKeys = lookupMappedCityKeys(trimmedArea);
    for (const key of mappedKeys) {
      unique.add(key);
    }
  }

  return Array.from(unique);
}
