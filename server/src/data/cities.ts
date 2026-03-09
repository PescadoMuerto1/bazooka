import { cityEnglishNames } from "./cityNamePairs.js";

type CityAliasGroup = {
  keys: string[];
  aliases: string[];
};

const MANUAL_CITY_ALIAS_GROUPS: CityAliasGroup[] = [
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

function toCollapsed(normalizedValue: string): string {
  return normalizedValue.replace(/\s+/g, "");
}

function addAliasToMap(
  aliasMap: Map<string, Set<string>>,
  normalizedAlias: string,
  cityKeys: readonly string[]
): void {
  if (!normalizedAlias) {
    return;
  }

  const existing = aliasMap.get(normalizedAlias);
  if (existing) {
    for (const cityKey of cityKeys) {
      existing.add(cityKey);
    }
    return;
  }

  aliasMap.set(normalizedAlias, new Set(cityKeys));
}

function addLookupTerm(
  aliasMap: Map<string, Set<string>>,
  rawLookupTerm: string,
  cityKeys: readonly string[]
): void {
  const normalized = normalizeText(rawLookupTerm);
  if (!normalized) {
    return;
  }

  addAliasToMap(aliasMap, normalized, cityKeys);

  const collapsed = toCollapsed(normalized);
  if (collapsed !== normalized && collapsed.length >= 4) {
    addAliasToMap(aliasMap, collapsed, cityKeys);
  }
}

function uniqueTrimmed(values: readonly string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim()).filter((value) => value.length > 0)));
}

const aliasToCityKeys = new Map<string, Set<string>>();

for (const [hebrewName, englishName] of Object.entries(cityEnglishNames)) {
  const groupKeys = [hebrewName];
  addLookupTerm(aliasToCityKeys, hebrewName, groupKeys);
  addLookupTerm(aliasToCityKeys, englishName, groupKeys);
}

for (const group of MANUAL_CITY_ALIAS_GROUPS) {
  const groupKeys = uniqueTrimmed(group.keys);
  if (groupKeys.length === 0) {
    continue;
  }

  const lookupTerms = uniqueTrimmed([...groupKeys, ...group.aliases]);
  for (const term of lookupTerms) {
    addLookupTerm(aliasToCityKeys, term, groupKeys);
  }
}

const fuzzyAliasEntries = Array.from(aliasToCityKeys.entries()).filter(
  ([alias]) => alias.length >= 4 && alias.includes(" ")
);

function containsAliasAsWholeTerm(normalizedValue: string, normalizedAlias: string): boolean {
  return (
    normalizedValue === normalizedAlias ||
    normalizedValue.startsWith(`${normalizedAlias} `) ||
    normalizedValue.endsWith(` ${normalizedAlias}`) ||
    normalizedValue.includes(` ${normalizedAlias} `)
  );
}

function lookupMappedCityKeys(rawArea: string): string[] {
  const normalizedArea = normalizeText(rawArea);
  if (!normalizedArea) {
    return [];
  }

  const collapsedArea = toCollapsed(normalizedArea);
  const exact =
    aliasToCityKeys.get(normalizedArea) ??
    (collapsedArea.length >= 4 ? aliasToCityKeys.get(collapsedArea) : undefined);
  if (exact) {
    return Array.from(exact);
  }

  const matches = new Set<string>();
  for (const [alias, keys] of fuzzyAliasEntries) {
    if (!containsAliasAsWholeTerm(normalizedArea, alias)) {
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
