import { cn } from '@/utils/cn';

interface BrandMarkProps {
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

/** 以朱砂印章为品牌符号，中间保留一个「族」字。 */
export function BrandMark({ size = 'md', className }: BrandMarkProps) {
  return (
    <span className={cn('brand-mark', `brand-mark--${size}`, className)} aria-hidden>
      <span>族</span>
    </span>
  );
}

export function BrandLockup({ compact = false }: { compact?: boolean }) {
  return (
    <div className={`brand-lockup ${compact ? 'brand-lockup--compact' : ''}`}>
      <BrandMark size="sm" />
      <div className="brand-lockup__text">
        <strong>家族族谱</strong>
        {!compact ? <span>寻根溯源 · 传承家风</span> : null}
      </div>
    </div>
  );
}
