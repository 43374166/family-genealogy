import { PersonAvatar } from '@/components/PersonAvatar';
import type { PersonSummary } from '@/types/api';
import { dualCalendarDate } from '@/utils/calendar';
import { generationShort, lifeYears } from '@/utils/format';
import { coverOption, type BookPage, type BookProject } from './bookModel';
import { BookLineageDiagram } from './BookLineageDiagram';

function generationText(value?: number): string {
  if (!value) return '';
  const numerals = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  if (value <= 10) return value === 10 ? '十' : numerals[value] ?? String(value);
  if (value < 20) return `十${numerals[value % 10]}`;
  if (value < 100) {
    const tens = Math.floor(value / 10);
    const ones = value % 10;
    return `${numerals[tens]}十${ones ? numerals[ones] : ''}`;
  }
  return String(value);
}

function PersonEntry({
  person,
  branchName,
}: {
  person: PersonSummary;
  branchName: string;
}) {
  const birth = dualCalendarDate(person.birth);
  const death = dualCalendarDate(person.death);
  return (
    <div className="book-person">
      <PersonAvatar person={person} size={50} eager />
      <div className="book-person__text">
        <div className="book-person__name">
          <strong>{person.fullName}</strong>
          <span>{generationShort(person.generationNo)}</span>
        </div>
        <p className="book-person__years">
          {lifeYears(person)}
          {branchName ? ` · ${branchName}` : ''}
        </p>
        <p className="book-person__dates">
          {birth ? <span>生 {birth.primary}</span> : <span>生卒未详</span>}
          {death ? <span>卒 {death.primary}</span> : null}
        </p>
        {person.courtesyName || person.alias ? (
          <p className="book-person__alias">
            {[person.courtesyName ? `字 ${person.courtesyName}` : '', person.alias ? `号 ${person.alias}` : '']
              .filter(Boolean)
              .join(' · ')}
          </p>
        ) : null}
      </div>
    </div>
  );
}

export function BookPageView({
  page,
  project,
  familyName,
  surname,
  branchName,
}: {
  page: BookPage;
  project: BookProject;
  familyName: string;
  surname: string;
  branchName: (id?: string) => string;
}) {
  const cover = coverOption(project.coverId);
  const pageClass = `book-page book-page--${page.kind} book-layout--${project.layoutId}`;

  if (page.kind === 'cover') {
    return (
      <div
        className={`${pageClass} book-cover book-cover--${cover.id}`}
        style={
          {
            '--cover-bg': cover.background,
            '--cover-bg-dark': cover.backgroundDark,
            '--cover-accent': cover.accent,
            '--cover-ink': cover.ink,
          } as React.CSSProperties
        }
      >
        <div className="book-cover__grain" />
        <div className="book-cover__frame">
          <span className="book-cover__family">{familyName}</span>
          {project.hallName ? (
            <span className="book-cover__hall">{project.hallName}</span>
          ) : null}
          <div className="book-cover__rule" />
          <h1>{project.title}</h1>
          <p>{project.subtitle}</p>
          <div className="book-cover__seal">{surname || '家'}氏</div>
          <small>{project.compiler}</small>
        </div>
        <span className="book-cover__spine">FAMILY CHRONICLE</span>
      </div>
    );
  }

  if (page.kind === 'blank') {
    return <div className={`${pageClass} book-page--blank`} />;
  }

  return (
    <div
      className={pageClass}
      style={{ '--book-accent': cover.accent } as React.CSSProperties}
    >
      <div className="book-page__inner">
        <header className="book-page__header">
          <span>{familyName}谱书</span>
          <span>{project.subtitle}</span>
        </header>

        {page.kind === 'title' ? (
          <div className="book-title-page">
            <span className="book-title-page__eyebrow">FAMILY GENEALOGY</span>
            <div className="book-title-page__seal">{surname || '家'}</div>
            <h2>{project.title}</h2>
            <p>{project.subtitle}</p>
            <div className="book-title-page__rule" />
            <small>{project.compiler}</small>
            <small>{new Date().getFullYear()} 年 · 家藏</small>
          </div>
        ) : null}

        {page.kind === 'preface' ? (
          <div className="book-preface">
            <span className="book-preface__eyebrow">序 · PREFACE</span>
            <h3>修谱序</h3>
            <div className="book-preface__text">
              {project.preface.split(/\n+/).map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
            </div>
            <div className="book-preface__sign">
              <span>{project.compiler}</span>
              <span>{new Date().getFullYear()} 年</span>
            </div>
          </div>
        ) : null}

        {page.kind === 'lineage' ? (
          <div className="book-lineage">
            <div className="book-people__heading">
              <span>世系图</span>
              <small>{page.persons?.length ?? 0} 人 · 按世代排列</small>
            </div>
            <BookLineageDiagram
              persons={page.persons ?? []}
              edges={page.parentChild ?? []}
            />
          </div>
        ) : null}

        {page.kind === 'chapter' ? (
          <div className="book-chapter">
            <span className="book-chapter__index">
              {generationText(page.generation).padStart(1, '0')}
            </span>
            <span className="book-chapter__eyebrow">GENERATION</span>
            <h2>第{generationText(page.generation)}世</h2>
            {page.generationName ? <p>{page.generationName}字辈</p> : null}
            <div className="book-chapter__rule" />
            <span className="book-chapter__count">{page.persons?.length ?? 0} 位家人</span>
            <div className="book-chapter__names">
              {(page.persons ?? []).map((person) => (
                <span key={person.id}>{person.fullName}</span>
              ))}
            </div>
          </div>
        ) : null}

        {page.kind === 'people' ? (
          <div className="book-people">
            <div className="book-people__heading">
              <span>第{generationText(page.generation)}世</span>
              <small>
                {page.generationName ? `${page.generationName}字辈 · ` : ''}
                {page.persons?.length ?? 0} 人
              </small>
            </div>
            <div
              className={`book-people__grid book-people__grid--${project.layoutId} book-people__grid--count-${page.persons?.length ?? 0}`}
            >
              {(page.persons ?? []).map((person) => (
                <PersonEntry
                  key={person.id}
                  person={person}
                  branchName={branchName(person.branchId)}
                />
              ))}
            </div>
          </div>
        ) : null}

        {page.kind === 'colophon' ? (
          <div className="book-colophon">
            <span className="book-colophon__seal">{surname || '家'}</span>
            <h3>谱成</h3>
            <p>本谱由 {familyName} 家族成员共同整理。</p>
            <p>愿世系有序，家风有承。</p>
            <div className="book-colophon__meta">
              <span>{project.compiler}</span>
              <span>{new Date().toLocaleDateString('zh-CN')}</span>
            </div>
          </div>
        ) : null}

        <footer className="book-page__footer">
          <span>{project.title}</span>
          <span>{page.pageNo ? String(page.pageNo).padStart(2, '0') : ''}</span>
        </footer>
      </div>
    </div>
  );
}
