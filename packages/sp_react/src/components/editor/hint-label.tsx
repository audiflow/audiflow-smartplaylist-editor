import type { ComponentProps } from 'react';
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
  if (!hint) {
    return <Label {...props}>{children}</Label>;
  }

  return (
    <div className="flex items-center gap-1">
      <Label {...props}>{children}</Label>
      <Tooltip>
        <TooltipTrigger type="button" tabIndex={-1} className="text-muted-foreground hover:text-foreground">
          <CircleHelp className="h-3.5 w-3.5" />
          <span className="sr-only">Help</span>
        </TooltipTrigger>
        <TooltipContent side="top">{hint}</TooltipContent>
      </Tooltip>
    </div>
  );
}
