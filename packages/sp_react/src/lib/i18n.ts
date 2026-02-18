import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

// English
import commonEn from '@/locales/en/common.json';
import editorEn from '@/locales/en/editor.json';
import hintsEn from '@/locales/en/hints.json';
import previewEn from '@/locales/en/preview.json';
import settingsEn from '@/locales/en/settings.json';
import feedEn from '@/locales/en/feed.json';

// Japanese
import commonJa from '@/locales/ja/common.json';
import editorJa from '@/locales/ja/editor.json';
import hintsJa from '@/locales/ja/hints.json';
import previewJa from '@/locales/ja/preview.json';
import settingsJa from '@/locales/ja/settings.json';
import feedJa from '@/locales/ja/feed.json';

void i18n
  .use(LanguageDetector)
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
      ja: {
        common: commonJa,
        editor: editorJa,
        hints: hintsJa,
        preview: previewJa,
        settings: settingsJa,
        feed: feedJa,
      },
    },
    fallbackLng: 'en',
    defaultNS: 'common',
    interpolation: { escapeValue: false },
    detection: { order: ['navigator'] },
  });

export default i18n;
