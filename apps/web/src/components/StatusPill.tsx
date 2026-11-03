import type { ReactNode } from 'react';
import { cn } from '@/utils/cn';
import { lifeStatusLabel, roleLabel } from '@/utils/format';
import type { Role } from '@/types/api';

interface PillProps {
  children: ReactNode;
  tone?: 'blue' | 'green' | 'amber' | 'red' | 'gray' | 'violet' | 'cinnabar';
  dot?: boolean;
  className?: string;
}

export function StatusPill({ children, tone = 'gray', dot = false, className }: PillProps) {
  return (
    <span className={cn('status-pill', `status-pill--${tone}`, className)}>
      {dot ? <span className="status-pill__dot" aria-hidden /> : null}
      {children}
    </span>
  );
}

export function RolePill({ role }: { role?: Role | string }) {
  const tone = role === 'owner' ? 'cinnabar' : role === 'admin' ? 'blue' : 'gray';
  return <StatusPill tone={tone}>{roleLabel(role)}</StatusPill>;
}

export function LifeStatusPill({ status }: { status?: string }) {
  return (
    <StatusPill tone={status === 'living' ? 'green' : status === 'deceased' ? 'gray' : 'gray'} dot>
      {lifeStatusLabel(status)}
    </StatusPill>
  );
}

export function RequestStatusPill({ status }: { status: string }) {
  const map: Record<string, { tone: PillProps['tone']; label: string }> = {
    pending: { tone: 'amber', label: '待审核' },
    approved: { tone: 'green', label: '已通过' },
    rejected: { tone: 'red', label: '已拒绝' },
    cancelled: { tone: 'gray', label: '已取消' },
  };
  const entry = map[status] ?? { tone: 'gray', label: status };
  return (
    <StatusPill tone={entry.tone} dot>
      {entry.label}
    </StatusPill>
  );
}
