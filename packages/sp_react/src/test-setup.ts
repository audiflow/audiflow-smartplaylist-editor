import '@testing-library/jest-dom/vitest';

// Node.js 22+ ships a native localStorage that lacks the standard Web Storage
// API methods (setItem, getItem, removeItem, clear). This polyfill replaces it
// with a spec-compliant in-memory implementation so tests can use localStorage
// the same way browser code does.
if (typeof globalThis.localStorage?.setItem !== 'function') {
  const store = new Map<string, string>();
  const storage = {
    getItem(key: string): string | null {
      return store.get(key) ?? null;
    },
    setItem(key: string, value: string): void {
      store.set(key, String(value));
    },
    removeItem(key: string): void {
      store.delete(key);
    },
    clear(): void {
      store.clear();
    },
    get length(): number {
      return store.size;
    },
    key(index: number): string | null {
      const keys = [...store.keys()];
      return keys[index] ?? null;
    },
  };

  Object.defineProperty(globalThis, 'localStorage', {
    value: storage,
    writable: true,
    configurable: true,
  });
  Object.defineProperty(window, 'localStorage', {
    value: storage,
    writable: true,
    configurable: true,
  });
}
