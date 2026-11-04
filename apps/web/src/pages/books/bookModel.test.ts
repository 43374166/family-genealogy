import { describe, expect, it } from 'vitest';
import type { FamilyTree, PersonSummary } from '@/types/api';
import {
  COVER_OPTIONS,
  LAYOUT_OPTIONS,
  bookGenerations,
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
  it('ships multiple cover and layout presets', () => {
    expect(COVER_OPTIONS.length).toBeGreaterThanOrEqual(3);
    expect(LAYOUT_OPTIONS.map((item) => item.id)).toContain('classic');
  });

  it('builds a complete book from cover through colophon', () => {
    const book = newBook('family-1', '凌氏家族', '凌');
    book.fromGeneration = 1;
    book.toGeneration = 3;
    const pages = formBookPages(book, tree);
    expect(pages[0].kind).toBe('cover');
    expect(pages.some((page) => page.kind === 'preface')).toBe(true);
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
});
