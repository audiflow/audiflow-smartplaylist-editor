/**
 * Converts empty strings to undefined in a config object before sending
 * to the server. React Hook Form converts null/undefined default values
 * to "" for registered <Input> fields, but the Dart server treats "" as
 * a valid regex (e.g., excludeFilter: "" excludes all episodes).
 */
export function sanitizeConfig(config: unknown): unknown {
  if (config === null || config === undefined) return config;
  if (typeof config === 'string') return config === '' ? undefined : config;
  if (Array.isArray(config)) return config.map(sanitizeConfig);
  if (typeof config === 'object') {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(config)) {
      const sanitized = sanitizeConfig(value);
      if (sanitized !== undefined) {
        result[key] = sanitized;
      }
    }
    return result;
  }
  return config;
}
