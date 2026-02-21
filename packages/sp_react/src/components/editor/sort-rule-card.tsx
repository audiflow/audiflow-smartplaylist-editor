import { Controller, useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, SortCondition } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Card, CardContent } from '@/components/ui/card.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { Trash2 } from 'lucide-react';

export const SORT_FIELDS = [
  'playlistNumber',
  'newestEpisodeDate',
  'progress',
  'alphabetical',
] as const;

export const SORT_ORDERS = ['ascending', 'descending'] as const;

const DEFAULT_CONDITION: SortCondition = { type: 'sortKeyGreaterThan', value: 0 };

interface SortRuleCardProps {
  playlistIndex: number;
  ruleIndex: number;
  onRemove: () => void;
}

export function SortRuleCard({ playlistIndex, ruleIndex, onRemove }: SortRuleCardProps) {
  const { control, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${playlistIndex}.customSort.rules.${ruleIndex}` as const;

  const condition = watch(`${prefix}.condition`);
  const hasCondition = condition !== undefined && condition !== null;

  return (
    <Card className="py-4">
      <CardContent className="space-y-3 px-4">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">
            {t('addSortRule')} {ruleIndex + 1}
          </span>
          <Button variant="ghost" size="sm" type="button" onClick={onRemove}>
            <Trash2 className="h-4 w-4" />
            <span className="sr-only">{t('removeSortRule')}</span>
          </Button>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`sort-rule-${playlistIndex}-${ruleIndex}-field`}
              hint="sortField"
            >
              {t('sortField')}
            </HintLabel>
            <Controller
              control={control}
              name={`${prefix}.field`}
              render={({ field }) => (
                <Select
                  value={field.value}
                  onValueChange={field.onChange}
                >
                  <SelectTrigger
                    id={`sort-rule-${playlistIndex}-${ruleIndex}-field`}
                    className="w-full"
                  >
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {SORT_FIELDS.map((f) => (
                      <SelectItem key={f} value={f} disabled={f === 'progress'}>
                        {t(`sortField_${f}`)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </div>

          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`sort-rule-${playlistIndex}-${ruleIndex}-order`}
              hint="sortOrder"
            >
              {t('sortOrder')}
            </HintLabel>
            <Controller
              control={control}
              name={`${prefix}.order`}
              render={({ field }) => (
                <Select
                  value={field.value}
                  onValueChange={field.onChange}
                >
                  <SelectTrigger
                    id={`sort-rule-${playlistIndex}-${ruleIndex}-order`}
                    className="w-full"
                  >
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {SORT_ORDERS.map((o) => (
                      <SelectItem key={o} value={o}>
                        {t(`sortOrder_${o}`)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </div>
        </div>

        <div className="space-y-2">
          <div className="flex items-center gap-2">
            <Checkbox
              id={`sort-rule-${playlistIndex}-${ruleIndex}-condition`}
              checked={hasCondition}
              onCheckedChange={(checked) => {
                if (checked) {
                  setValue(`${prefix}.condition`, DEFAULT_CONDITION);
                } else {
                  setValue(`${prefix}.condition`, undefined);
                }
              }}
            />
            <HintLabel
              htmlFor={`sort-rule-${playlistIndex}-${ruleIndex}-condition`}
              hint="sortCondition"
            >
              {t('sortConditional')}
            </HintLabel>
          </div>

          {hasCondition && (
            <div className="space-y-1.5 pl-6">
              <HintLabel
                htmlFor={`sort-rule-${playlistIndex}-${ruleIndex}-condition-value`}
              >
                {t('sortConditionValue')}
              </HintLabel>
              <Input
                id={`sort-rule-${playlistIndex}-${ruleIndex}-condition-value`}
                type="number"
                value={condition?.value ?? 0}
                onChange={(e) => {
                  setValue(`${prefix}.condition`, {
                    type: 'sortKeyGreaterThan',
                    value: e.target.valueAsNumber,
                  });
                }}
                className="w-32"
              />
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
