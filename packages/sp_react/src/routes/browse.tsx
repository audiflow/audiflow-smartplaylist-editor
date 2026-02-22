import { createFileRoute, useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { usePatterns } from '@/api/queries.ts';
import { Button } from '@/components/ui/button.tsx';
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
} from '@/components/ui/card.tsx';
import { Badge } from '@/components/ui/badge.tsx';
import { Plus, Loader2 } from 'lucide-react';

export const Route = createFileRoute('/browse')({
  component: BrowseScreen,
});

function BrowseScreen() {
  const navigate = useNavigate();
  const { data: patterns, isLoading, error } = usePatterns();

  return (
    <div className="container mx-auto max-w-4xl p-6">
      <BrowseHeader navigate={navigate} />

      {isLoading && <LoadingState />}
      {error && <ErrorState message={error.message} />}
      {patterns && patterns.length === 0 && <EmptyState />}
      {patterns && 0 < patterns.length && (
        <PatternList patterns={patterns} navigate={navigate} />
      )}
    </div>
  );
}

function BrowseHeader({
  navigate,
}: {
  navigate: ReturnType<typeof useNavigate>;
}) {
  const { t } = useTranslation('common');

  return (
    <div className="flex items-center justify-between mb-6">
      <h1 className="text-2xl font-bold">{t('appTitle')}</h1>
      <div className="flex gap-2">
        <Button onClick={() => void navigate({ to: '/editor' })}>
          <Plus className="mr-2 h-4 w-4" />
          {t('createNew')}
        </Button>
      </div>
    </div>
  );
}

function LoadingState() {
  return (
    <div className="flex justify-center py-12">
      <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
    </div>
  );
}

function ErrorState({ message }: { message: string }) {
  const { t } = useTranslation('common');

  return (
    <div className="text-center py-12 text-destructive">
      {t('loadPatternsFailed', { error: message })}
    </div>
  );
}

function EmptyState() {
  const { t } = useTranslation('common');

  return (
    <div className="text-center py-12 text-muted-foreground">
      {t('noPatternsFound')}
    </div>
  );
}

function PatternList({
  patterns,
  navigate,
}: {
  patterns: Array<{
    id: string;
    displayName: string;
    feedUrlHint: string;
    playlistCount: number;
  }>;
  navigate: ReturnType<typeof useNavigate>;
}) {
  return (
    <div className="grid gap-4">
      {patterns.map((pattern) => (
        <PatternCard
          key={pattern.id}
          pattern={pattern}
          navigate={navigate}
        />
      ))}
    </div>
  );
}

function PatternCard({
  pattern,
  navigate,
}: {
  pattern: {
    id: string;
    displayName: string;
    feedUrlHint: string;
    playlistCount: number;
  };
  navigate: ReturnType<typeof useNavigate>;
}) {
  const { t } = useTranslation('feed');

  return (
    <Card
      className="cursor-pointer hover:bg-accent/50 transition-colors"
      onClick={() =>
        void navigate({ to: '/editor/$id', params: { id: pattern.id } })
      }
    >
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="text-lg">{pattern.displayName}</CardTitle>
          <Badge variant="secondary">
            {t('playlists', { count: pattern.playlistCount })}
          </Badge>
        </div>
        {pattern.feedUrlHint && (
          <CardDescription>{pattern.feedUrlHint}</CardDescription>
        )}
      </CardHeader>
    </Card>
  );
}
