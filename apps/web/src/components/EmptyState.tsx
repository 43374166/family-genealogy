import type { ReactNode } from 'react';
import { Button } from '@douyinfe/semi-ui';

interface EmptyStateProps {
  title: string;
  description?: string;
  action?: ReactNode;
  actionText?: string;
  onAction?: () => void;
  compact?: boolean;
}

export function EmptyState({
  title,
  description,
  action,
  actionText,
  onAction,
  compact = false,
}: EmptyStateProps) {
  return (
    <div className={`empty-state ${compact ? 'empty-state--compact' : ''}`}>
      <div className="empty-state__art" aria-hidden>
        <span className="empty-state__sun" />
        <span className="empty-state__mountain empty-state__mountain--back" />
        <span className="empty-state__mountain empty-state__mountain--front" />
        <span className="empty-state__mist" />
      </div>
      <h3 className="empty-state__title">{title}</h3>
      {description ? <p className="empty-state__description">{description}</p> : null}
      {action ??
        (actionText && onAction ? (
          <Button theme="borderless" className="empty-state__action" onClick={onAction}>
            {actionText}
          </Button>
        ) : null)}
    </div>
  );
}
