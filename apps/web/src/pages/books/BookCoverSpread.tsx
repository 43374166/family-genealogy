import { forwardRef } from 'react';
import { coverOption, bookSpineMm, type BookProject } from './bookModel';
import { BookPageView } from './BookPageView';

export const COVER_TRIM_WIDTH = 430;
export const COVER_TRIM_HEIGHT = 610;
export const COVER_BLEED = 8;

export const BookCoverSpread = forwardRef<
  HTMLDivElement,
  {
    project: BookProject;
    pageCount: number;
    familyName: string;
    surname: string;
    branchName: (id?: string) => string;
  }
>(function BookCoverSpread({ project, pageCount, familyName, surname, branchName }, ref) {
  const cover = coverOption(project.coverId);
  const spinePx = Math.max(10, Math.round(bookSpineMm(pageCount) * 2.05));
  const width = COVER_BLEED * 2 + COVER_TRIM_WIDTH * 2 + spinePx;
  const height = COVER_BLEED * 2 + COVER_TRIM_HEIGHT;

  return (
    <div
      ref={ref}
      className={`book-cover-spread book-cover-spread--${cover.id}`}
      style={
        {
          width,
          height,
          padding: COVER_BLEED,
          '--cover-bg': cover.background,
          '--cover-bg-dark': cover.backgroundDark,
          '--cover-accent': cover.accent,
          '--cover-ink': cover.ink,
          '--spine-width': `${spinePx}px`,
        } as React.CSSProperties
      }
    >
      <span className="book-cover-spread__crop book-cover-spread__crop--tl" />
      <span className="book-cover-spread__crop book-cover-spread__crop--tr" />
      <span className="book-cover-spread__crop book-cover-spread__crop--bl" />
      <span className="book-cover-spread__crop book-cover-spread__crop--br" />

      <div className="book-cover-spread__back">
        <span className="book-cover-spread__back-family">{familyName}</span>
        <div className="book-cover-spread__back-mark">{surname || '家'}氏</div>
        <p>{project.hallName || project.subtitle}</p>
        <small>家藏 · {new Date().getFullYear()}</small>
      </div>

      <div className="book-cover-spread__spine">
        <span>{project.title}</span>
        <i />
        <small>{familyName}</small>
      </div>

      <div className="book-cover-spread__front">
        <BookPageView
          page={{ id: 'cover', kind: 'cover' }}
          project={project}
          familyName={familyName}
          surname={surname}
          branchName={branchName}
        />
      </div>
    </div>
  );
});
