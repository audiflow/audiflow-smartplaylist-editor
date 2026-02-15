import { Fragment, useDeferredValue, useMemo, useState } from 'react';
import { ChevronDown, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button.tsx';

const SAMPLE_TITLES = [
  'Episode 1: The Beginning',
  'Episode 2: Rising Action',
  'S01E03 - The Plot Thickens',
  'Special: Behind the Scenes',
  'Bonus Episode: Interview',
  'Episode 10: Season Finale',
  'Trailer: Coming Soon',
  'S02E01 - New Season',
];

interface RegexTesterProps {
  pattern: string;
  variant: 'include' | 'exclude';
}

interface CompiledRegex {
  regex: RegExp | null;
  error: string | null;
}

function compilePattern(pattern: string): CompiledRegex {
  if (!pattern) return { regex: null, error: null };
  try {
    return { regex: new RegExp(pattern, 'i'), error: null };
  } catch (e) {
    return { regex: null, error: (e as Error).message };
  }
}

function countMatches(regex: RegExp | null, titles: readonly string[]): number {
  if (!regex) return 0;
  return titles.filter((title) => regex.test(title)).length;
}

export function RegexTester({ pattern, variant }: RegexTesterProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const deferredPattern = useDeferredValue(pattern);

  const compiled = useMemo(
    () => compilePattern(deferredPattern),
    [deferredPattern],
  );

  const matchCount = useMemo(
    () => countMatches(compiled.regex, SAMPLE_TITLES),
    [compiled.regex],
  );

  if (!pattern) return null;

  const toggleExpanded = () => setIsExpanded((prev) => !prev);

  return (
    <div className="mt-1">
      <Button
        variant="ghost"
        size="sm"
        className="h-auto px-1 py-0.5 text-xs text-muted-foreground"
        onClick={toggleExpanded}
      >
        {isExpanded ? (
          <ChevronDown className="mr-1 h-3 w-3" />
        ) : (
          <ChevronRight className="mr-1 h-3 w-3" />
        )}
        Test regex
        {compiled.regex && ` (${matchCount} matches)`}
      </Button>

      {isExpanded && (
        <div className="mt-1 rounded-md border p-2">
          {compiled.error ? (
            <p className="text-xs text-destructive">
              Invalid regex: {compiled.error}
            </p>
          ) : (
            <SampleTitleList regex={compiled.regex} variant={variant} />
          )}
        </div>
      )}
    </div>
  );
}

function SampleTitleList({
  regex,
  variant,
}: {
  regex: RegExp | null;
  variant: 'include' | 'exclude';
}) {
  return (
    <ul className="space-y-0.5">
      {SAMPLE_TITLES.map((title) => (
        <li key={title} className="text-xs font-mono">
          {regex ? (
            <HighlightedTitle title={title} regex={regex} variant={variant} />
          ) : (
            title
          )}
        </li>
      ))}
    </ul>
  );
}

function HighlightedTitle({
  title,
  regex,
  variant,
}: {
  title: string;
  regex: RegExp;
  variant: 'include' | 'exclude';
}) {
  // Build a global version of the regex for matchAll
  const globalRegex = new RegExp(regex.source, 'gi');
  const matchArray = [...title.matchAll(globalRegex)];

  if (matchArray.length === 0) return <>{title}</>;

  const highlightClass =
    variant === 'include'
      ? 'bg-green-200 dark:bg-green-900 rounded px-0.5'
      : 'bg-red-200 dark:bg-red-900 rounded px-0.5';

  const parts: React.ReactNode[] = [];
  let lastIndex = 0;

  for (let i = 0; i < matchArray.length; i++) {
    const match = matchArray[i];
    const matchStart = match.index;
    const matchText = match[0];

    // Text before this match
    if (lastIndex < matchStart) {
      parts.push(
        <Fragment key={`text-${i}`}>
          {title.slice(lastIndex, matchStart)}
        </Fragment>,
      );
    }

    // The matched text
    parts.push(
      <span key={`match-${i}`} className={highlightClass}>
        {matchText}
      </span>,
    );

    lastIndex = matchStart + matchText.length;
  }

  // Remaining text after last match
  if (lastIndex < title.length) {
    parts.push(
      <Fragment key="tail">{title.slice(lastIndex)}</Fragment>,
    );
  }

  return <>{parts}</>;
}
