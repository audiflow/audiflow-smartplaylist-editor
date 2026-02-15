type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

interface MergeParams {
  base: JsonValue;
  latest: JsonValue;
  modified: JsonValue;
}

function isObject(value: unknown): value is Record<string, JsonValue> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function deepEquals(a: JsonValue, b: JsonValue): boolean {
  if (a === b) return true;
  if (typeof a !== typeof b) return false;
  if (a === null || b === null) return a === b;

  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    return a.every((item, i) => deepEquals(item, b[i]));
  }

  if (isObject(a) && isObject(b)) {
    const keysA = Object.keys(a);
    const keysB = Object.keys(b);
    if (keysA.length !== keysB.length) return false;
    return keysA.every((key) => key in b && deepEquals(a[key], b[key]));
  }

  return false;
}

function mergeMaps(
  base: Record<string, JsonValue>,
  latest: Record<string, JsonValue>,
  modified: Record<string, JsonValue>,
): Record<string, JsonValue> {
  const result: Record<string, JsonValue> = {};
  const allKeys = new Set([
    ...Object.keys(base),
    ...Object.keys(latest),
    ...Object.keys(modified),
  ]);

  for (const key of allKeys) {
    const inBase = key in base;
    const inLatest = key in latest;
    const inModified = key in modified;

    if (inBase && !inModified) {
      // User removed this key - user wins
      continue;
    }

    if (!inBase && inLatest && !inModified) {
      // Upstream added a new key, user didn't touch it - accept upstream
      result[key] = latest[key];
      continue;
    }

    if (inModified) {
      const baseVal = inBase ? base[key] : undefined;
      const latestVal = inLatest ? latest[key] : undefined;
      const modifiedVal = modified[key];

      if (baseVal !== undefined && deepEquals(baseVal, modifiedVal)) {
        // User didn't change this key - take latest
        result[key] = latestVal ?? modifiedVal;
      } else {
        // User changed this key - merge recursively
        if (latestVal !== undefined && baseVal !== undefined) {
          result[key] = mergeValue(baseVal, latestVal, modifiedVal);
        } else {
          result[key] = modifiedVal;
        }
      }
    }
  }

  return result;
}

function mergeLists(
  base: JsonValue[],
  latest: JsonValue[],
  modified: JsonValue[],
): JsonValue[] {
  const hasIds = (arr: JsonValue[]): boolean =>
    arr.every((item) => isObject(item) && 'id' in item);

  if (hasIds(base) && hasIds(latest) && hasIds(modified)) {
    return mergeIdLists(
      base as Record<string, JsonValue>[],
      latest as Record<string, JsonValue>[],
      modified as Record<string, JsonValue>[],
    );
  }
  return mergeIndexLists(base, latest, modified);
}

function mergeIdLists(
  base: Record<string, JsonValue>[],
  latest: Record<string, JsonValue>[],
  modified: Record<string, JsonValue>[],
): Record<string, JsonValue>[] {
  const baseMap = new Map(base.map((item) => [item['id'], item]));
  const latestMap = new Map(latest.map((item) => [item['id'], item]));

  return modified.map((modItem) => {
    const id = modItem['id'];
    const baseItem = baseMap.get(id);
    const latestItem = latestMap.get(id);

    if (baseItem && latestItem) {
      return mergeMaps(baseItem, latestItem, modItem);
    }
    return modItem;
  });
}

function mergeIndexLists(
  base: JsonValue[],
  latest: JsonValue[],
  modified: JsonValue[],
): JsonValue[] {
  const maxLen = Math.max(base.length, latest.length, modified.length);
  const result: JsonValue[] = [];

  for (let i = 0; i < maxLen; i++) {
    if (i < modified.length) {
      if (i < base.length && i < latest.length) {
        result.push(mergeValue(base[i], latest[i], modified[i]));
      } else {
        result.push(modified[i]);
      }
    } else if (i < latest.length) {
      result.push(latest[i]);
    }
  }

  return result;
}

function mergeValue(
  base: JsonValue,
  latest: JsonValue,
  modified: JsonValue,
): JsonValue {
  if (deepEquals(base, modified)) return latest;
  if (isObject(base) && isObject(latest) && isObject(modified)) {
    return mergeMaps(base, latest, modified);
  }
  if (Array.isArray(base) && Array.isArray(latest) && Array.isArray(modified)) {
    return mergeLists(base, latest, modified);
  }
  return modified;
}

export function merge(params: MergeParams): JsonValue {
  return mergeValue(params.base, params.latest, params.modified);
}
