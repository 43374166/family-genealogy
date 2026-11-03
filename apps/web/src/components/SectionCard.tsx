import type { ReactNode } from 'react';
import { cn } from '@/utils/cn';

interface SectionCardProps {
  title?: ReactNode;
  eyebrow?: string;
  extra?: ReactNode;
  children: ReactNode;
  className?: string;
  bodyClassName?: string;
  icon?: ReactNode;
}

export function SectionCard({
  title,
  eyebrow,
  extra,
  children,
  className,
  bodyClassName,
  icon,
}: SectionCardProps) {
  return (
    <section className={cn('surface-card', className)}>
      {title || extra ? (
        <header className="section-heading">
          <div className="section-heading__main">
            {icon ? <span className="section-heading__icon">{icon}</span> : <span className="section-heading__bar" />}
            <div>
              {eyebrow ? <p className="eyebrow">{eyebrow}</p> : null}
              {title ? <h2 className="section-heading__title">{title}</h2> : null}
            </div>
          </div>
          {extra ? <div className="section-heading__extra">{extra}</div> : null}
        </header>
      ) : null}
      <div className={cn('surface-card__body', bodyClassName)}>{children}</div>
    </section>
  );
}
