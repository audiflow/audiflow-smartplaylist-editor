import '@testing-library/jest-dom/vitest';
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

import commonEn from '@/locales/en/common.json';
import editorEn from '@/locales/en/editor.json';
import hintsEn from '@/locales/en/hints.json';
import previewEn from '@/locales/en/preview.json';
import settingsEn from '@/locales/en/settings.json';
import feedEn from '@/locales/en/feed.json';

void i18n
  .use(initReactI18next)
  .init({
    resources: {
      en: {
        common: commonEn,
        editor: editorEn,
        hints: hintsEn,
        preview: previewEn,
        settings: settingsEn,
        feed: feedEn,
      },
    },
    lng: 'en',
    defaultNS: 'common',
    interpolation: { escapeValue: false },
  });

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
