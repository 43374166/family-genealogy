import { Spin } from '@douyinfe/semi-ui';
import { BrandMark } from './BrandMark';

export function LoadingScreen({ label = '正在整理家族记忆…' }: { label?: string }) {
  return (
    <div className="loading-screen">
      <div className="loading-screen__seal">
        <BrandMark size="lg" />
      </div>
      <Spin size="large" />
      <p>{label}</p>
    </div>
  );
}

export function SectionSkeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div className="section-skeleton" aria-label="加载中">
      {Array.from({ length: rows }).map((_, index) => (
        <div className="section-skeleton__row" key={index}>
          <span className="section-skeleton__avatar" />
          <span className="section-skeleton__lines">
            <span style={{ width: `${68 - index * 8}%` }} />
            <span style={{ width: `${42 + index * 6}%` }} />
          </span>
        </div>
      ))}
    </div>
  );
}
