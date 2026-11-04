import type { FamilyTree, ParentChildEdge, PersonSummary } from '@/types/api';

export type CoverId =
  | 'ivory'
  | 'indigo'
  | 'jade'
  | 'cinnabar'
  | 'minimal'
  | 'thread';
export type BookLayoutId = 'classic' | 'modern' | 'lineage';

export interface CoverOption {
  id: CoverId;
  name: string;
  description: string;
  background: string;
  backgroundDark: string;
  accent: string;
  ink: string;
}

export const COVER_OPTIONS: CoverOption[] = [
  {
    id: 'ivory',
    name: '宣纸朱印',
    description: '米白宣纸、朱砂印章，最传统的家谱气质',
    background: '#f1ead8',
    backgroundDark: '#e5dbc3',
    accent: '#9d3e32',
    ink: '#3b342a',
  },
  {
    id: 'indigo',
    name: '靛蓝缃帙',
    description: '深靛布面、描金细线，庄重而克制',
    background: '#263b4e',
    backgroundDark: '#1d2d3c',
    accent: '#d5be8a',
    ink: '#f3ead5',
  },
  {
    id: 'jade',
    name: '松烟墨绿',
    description: '松烟墨绿、米色扉页，安静耐看',
    background: '#30473e',
    backgroundDark: '#24372f',
    accent: '#d8cba7',
    ink: '#f2ead8',
  },
  {
    id: 'cinnabar',
    name: '朱砂绢本',
    description: '朱砂绢面、泥金书名，适合总谱与庆典',
    background: '#853c33',
    backgroundDark: '#6d2f28',
    accent: '#e7ca91',
    ink: '#f8edda',
  },
  {
    id: 'minimal',
    name: '素白极简',
    description: '米白纸面、细黑线，现代排版与摄影都适合',
    background: '#f6f3ea',
    backgroundDark: '#e9e3d4',
    accent: '#3c423e',
    ink: '#2d332f',
  },
  {
    id: 'thread',
    name: '青布线装',
    description: '青灰布面、米色书签，传统线装书的安静气质',
    background: '#394b4c',
    backgroundDark: '#293a3b',
    accent: '#d7c59c',
    ink: '#f3ead7',
  },
];

export interface BookLayoutOption {
  id: BookLayoutId;
  name: string;
  description: string;
}

export const LAYOUT_OPTIONS: BookLayoutOption[] = [
  {
    id: 'classic',
    name: '传统世系',
    description: '竖排标题、朱线分隔，保留传统谱书版式',
  },
  {
    id: 'modern',
    name: '现代图文',
    description: '清晰网格、适度留白，适合照片与生平',
  },
  {
    id: 'lineage',
    name: '谱表编排',
    description: '以世次和支系为表，字号克制、信息密度高',
  },
];

export interface BookProject {
  id: string;
  familyId: string;
  title: string;
  subtitle: string;
  hallName: string;
  compiler: string;
  preface: string;
  coverId: CoverId;
  layoutId: BookLayoutId;
  fromGeneration: number;
  toGeneration: number;
  createdAt: string;
  updatedAt: string;
  builtAt?: string;
}

export type BookPageKind =
  | 'cover'
  | 'blank'
  | 'title'
  | 'preface'
  | 'lineage'
  | 'chapter'
  | 'people'
  | 'colophon';

export interface BookPage {
  id: string;
  kind: BookPageKind;
  pageNo?: number;
  generation?: number;
  generationName?: string;
  persons?: PersonSummary[];
  parentChild?: ParentChildEdge[];
}

export function coverOption(id: CoverId): CoverOption {
  return COVER_OPTIONS.find((option) => option.id === id) ?? COVER_OPTIONS[0];
}

export function layoutOption(id: BookLayoutId): BookLayoutOption {
  return LAYOUT_OPTIONS.find((option) => option.id === id) ?? LAYOUT_OPTIONS[0];
}

function storageKey(familyId: string): string {
  return `family-tree-books:v1:${familyId}`;
}

export function loadBooks(familyId: string): BookProject[] {
  try {
    const raw = window.localStorage.getItem(storageKey(familyId));
    if (!raw) return [];
    const parsed = JSON.parse(raw) as BookProject[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((book) => book && book.id)
      .map((book) => ({
        ...book,
        hallName: book.hallName ?? '',
        coverId: COVER_OPTIONS.some((option) => option.id === book.coverId)
          ? book.coverId
          : 'ivory',
        layoutId: LAYOUT_OPTIONS.some((option) => option.id === book.layoutId)
          ? book.layoutId
          : 'classic',
      }));
  } catch {
    return [];
  }
}

export function saveBooks(familyId: string, books: BookProject[]): void {
  try {
    window.localStorage.setItem(storageKey(familyId), JSON.stringify(books));
  } catch {
    // Private mode/storage quota failure must not break the book workshop.
  }
}

export function newBook(familyId: string, familyName: string, surname: string): BookProject {
  const now = new Date().toISOString();
  return {
    id:
      typeof crypto !== 'undefined' && 'randomUUID' in crypto
        ? crypto.randomUUID()
        : `book-${Date.now()}`,
    familyId,
    title: `${familyName || '家族'}谱书`,
    subtitle: '世系、人物与家风',
    hallName: surname ? `${surname}氏宗祠` : '',
    compiler: `${surname || ''}氏修谱`,
    preface:
      '谱者，家之史也。记录世系，也记录一个家族如何在时间里相互扶持、绵延生长。愿后来者翻开此册，知道自己的来处，也看见前人的温度。',
    coverId: 'ivory',
    layoutId: 'classic',
    fromGeneration: 0,
    toGeneration: 0,
    createdAt: now,
    updatedAt: now,
  };
}

export function bookPeoplePerPage(layoutId: BookLayoutId): number {
  if (layoutId === 'modern') return 6;
  if (layoutId === 'lineage') return 8;
  return 4;
}

/** Approximate spine width in mm for a 100g/m² paper block. */
export function bookSpineMm(pageCount: number): number {
  return Math.max(3, Math.ceil((pageCount / 2) * 0.12));
}

export function bookGenerations(tree: FamilyTree | null): number[] {
  if (!tree) return [];
  return Array.from(new Set(tree.persons.map((person) => person.generationNo))).sort(
    (a, b) => a - b,
  );
}

export function formBookPages(project: BookProject, tree: FamilyTree | null): BookPage[] {
  if (!tree) return [];
  const generations = bookGenerations(tree);
  const from = project.fromGeneration || generations[0] || 1;
  const to = project.toGeneration || generations[generations.length - 1] || from;
  const persons = tree.persons.filter(
    (person) =>
      person.status !== 'merged' &&
      person.generationNo >= from &&
      person.generationNo <= to,
  );
  const pages: BookPage[] = [
    { id: 'cover', kind: 'cover' },
    { id: 'blank', kind: 'blank' },
    { id: 'title', kind: 'title' },
    { id: 'preface', kind: 'preface' },
  ];
  let pageNo = 1;
  if (persons.length) {
    pages.push({
      id: 'lineage',
      kind: 'lineage',
      pageNo: pageNo++,
      persons,
      parentChild: tree.parentChild,
    });
  }
  const perPage = bookPeoplePerPage(project.layoutId);
  for (const generation of generations.filter((item) => item >= from && item <= to)) {
    const list = persons
      .filter((person) => person.generationNo === generation)
      .sort((a, b) => {
        const order = (a.birthOrder ?? 999) - (b.birthOrder ?? 999);
        return order || a.fullName.localeCompare(b.fullName, 'zh-CN');
      });
    if (!list.length) continue;
    const generationName = list.find((person) => person.generationName)?.generationName;
    pages.push({
      id: `chapter-${generation}`,
      kind: 'chapter',
      pageNo: pageNo++,
      generation,
      generationName,
      persons: list,
    });
    for (let index = 0; index < list.length; index += perPage) {
      pages.push({
        id: `people-${generation}-${index / perPage}`,
        kind: 'people',
        pageNo: pageNo++,
        generation,
        generationName,
        persons: list.slice(index, index + perPage),
      });
    }
  }
  pages.push({ id: 'colophon', kind: 'colophon', pageNo: pageNo++ });
  return pages;
}
