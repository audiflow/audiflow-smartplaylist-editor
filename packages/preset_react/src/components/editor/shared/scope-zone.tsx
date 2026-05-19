import type { ReactNode } from 'react';
import { cn } from '@/lib/utils.ts';

export type ScopeTone = 'playlist' | 'pergroup';

interface ScopeZoneProps {
  tone: ScopeTone;
  title: string;
  hint?: string;
  children: ReactNode;
  className?: string;
}

const TONE_CLASSES: Record<ScopeTone, string> = {
  playlist: 'scope-zone-playlist border-sky-300 bg-sky-50/50',
  pergroup: 'scope-zone-pergroup border-amber-300 bg-amber-50/50',
};

const TITLE_CLASSES: Record<ScopeTone, string> = {
  playlist: 'text-sky-700',
  pergroup: 'text-amber-800',
};

export function ScopeZone({ tone, title, hint, children, className }: ScopeZoneProps) {
  return (
    <section
      data-scope={tone}
      className={cn('rounded-lg border px-4 py-3 space-y-3', TONE_CLASSES[tone], className)}
    >
      <header className="flex items-baseline gap-3">
        <h4 className={cn('text-xs font-semibold uppercase tracking-wider', TITLE_CLASSES[tone])}>
          {title}
        </h4>
        {hint ? <span className="text-xs text-muted-foreground">{hint}</span> : null}
      </header>
      <div className="space-y-3">{children}</div>
    </section>
  );
}
