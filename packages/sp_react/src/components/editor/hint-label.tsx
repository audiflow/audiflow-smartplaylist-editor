import type { ComponentProps } from 'react';
import { useTranslation } from 'react-i18next';
import { Label } from '@/components/ui/label.tsx';
import {
  Tooltip,
  TooltipTrigger,
  TooltipContent,
} from '@/components/ui/tooltip.tsx';
import { CircleHelp } from 'lucide-react';

interface HintLabelProps extends ComponentProps<typeof Label> {
  hint?: string;
}

export function HintLabel({ hint, children, ...props }: HintLabelProps) {
  const { t } = useTranslation('hints');
  const { t: tCommon } = useTranslation('common');

  if (!hint) {
    return <Label {...props}>{children}</Label>;
  }

  return (
    <div className="flex items-center gap-1">
      <Label {...props}>{children}</Label>
      <Tooltip>
        <TooltipTrigger type="button" tabIndex={-1} className="text-muted-foreground hover:text-foreground">
          <CircleHelp className="h-3.5 w-3.5" />
          <span className="sr-only">{tCommon('help')}</span>
        </TooltipTrigger>
        <TooltipContent side="top">{t(hint)}</TooltipContent>
      </Tooltip>
    </div>
  );
}
