import { describe, expect, it } from 'vitest';
import type { FamilyTree, PersonSummary } from '@/types/api';
import {
  COVER_OPTIONS,
  LAYOUT_OPTIONS,
  bookGenerations,
  bookPeoplePerPage,
  bookSpineMm,
  formBookPages,
  newBook,
} from './bookModel';

const person = (
  id: string,
  generationNo: number,
  overrides: Partial<PersonSummary> = {},
): PersonSummary => ({
  id,
  fullName: `成员${id}`,
  surname: '凌',
  givenName: id,
  gender: 'male',
  generationNo,
  generationLabel: `第${generationNo}世`,
  lifeStatus: 'living',
  status: 'active',
  version: 1,
  hasAvatar: false,
  ...overrides,
});

const tree: FamilyTree = {
  familyId: 'family-1',
  version: 1,
  persons: [
    person('a', 1, { fullName: '凌一世', generationName: '洪' }),
    person('b', 2),
    person('c', 2),
    person('d', 2),
    person('e', 2),
    person('f', 3),
  ],
  parentChild: [],
  spouses: [],
};

describe('book model', () => {
  it('ships six covers, three layouts and density rules', () => {
    expect(COVER_OPTIONS).toHaveLength(6);
    expect(LAYOUT_OPTIONS).toHaveLength(3);
    expect(bookPeoplePerPage('classic')).toBe(4);
    expect(bookPeoplePerPage('modern')).toBe(6);
    expect(bookPeoplePerPage('lineage')).toBe(8);
    expect(bookSpineMm(16)).toBeGreaterThanOrEqual(3);
  });

  it('builds a complete book from cover through colophon', () => {
    const book = newBook('family-1', '凌氏家族', '凌');
    book.fromGeneration = 1;
    book.toGeneration = 3;
    const pages = formBookPages(book, tree);
    expect(pages[0].kind).toBe('cover');
    expect(pages.some((page) => page.kind === 'preface')).toBe(true);
    expect(pages.some((page) => page.kind === 'lineage')).toBe(true);
    expect(pages.filter((page) => page.kind === 'chapter')).toHaveLength(3);
    expect(pages.filter((page) => page.kind === 'people')).toHaveLength(3);
    expect(pages[pages.length - 1].kind).toBe('colophon');
    expect(
      pages
        .filter((page) => page.kind === 'people')
        .every((page) => (page.persons?.length ?? 0) <= 4),
    ).toBe(true);
  });

  it('honours the selected generation range', () => {
    const book = newBook('family-1', '凌氏家族', '凌');
    book.fromGeneration = 3;
    book.toGeneration = 3;
    const pages = formBookPages(book, tree);
    expect(bookGenerations(tree)).toEqual([1, 2, 3]);
    expect(pages.filter((page) => page.kind === 'chapter')).toHaveLength(1);
    expect(pages.some((page) => page.persons?.some((item) => item.id === 'a'))).toBe(false);
  });

  it('paginates by the selected interior layout', () => {
    const book = newBook('family-1', '凌氏家族', '凌');
    book.fromGeneration = 2;
    book.toGeneration = 2;
    book.layoutId = 'modern';
    const modern = formBookPages(book, tree).filter((page) => page.kind === 'people');
    book.layoutId = 'lineage';
    const lineage = formBookPages(book, tree).filter((page) => page.kind === 'people');
    expect(modern.every((page) => (page.persons?.length ?? 0) <= 6)).toBe(true);
    expect(lineage.every((page) => (page.persons?.length ?? 0) <= 8)).toBe(true);
  });

  it('turns self-written sections into vertical writing pages', () => {
    const book = newBook('family-1', '凌氏家族', '凌');
    book.writing[0].body = '甲'.repeat(500);
    const pages = formBookPages(book, tree);
    const writing = pages.filter((page) => page.kind === 'writing');
    expect(writing.length).toBe(2);
    expect(writing[0].pageNo).toBe(1);
    expect(writing[1].sectionTitle).toContain('续');
    book.includeLineage = false;
    book.includeColophon = false;
    const trimmed = formBookPages(book, tree);
    expect(trimmed.some((page) => page.kind === 'lineage')).toBe(false);
    expect(trimmed.some((page) => page.kind === 'colophon')).toBe(false);
  });
});
