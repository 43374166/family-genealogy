import { useEffect, useMemo, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { Button, Input, TextArea, Toast } from '@douyinfe/semi-ui';
import { SafeSelect as Select } from '@/components/SafeSelect';
import {
  IconArrowLeft,
  IconArrowRight,
  IconBook,
  IconClose,
  IconDelete,
  IconEdit,
  IconEyeOpened,
  IconPlus,
  IconSave,
} from '@douyinfe/semi-icons';
import { PageHeader } from '@/components/PageHeader';
import { useAsync } from '@/hooks/useAsync';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { useAppSelector } from '@/store/hooks';
import { personsApi } from '@/api/persons';
import { familyApi } from '@/api/family';
import {
  COVER_OPTIONS,
  LAYOUT_OPTIONS,
  bookGenerations,
  bookPeoplePerPage,
  coverOption,
  formBookPages,
  layoutOption,
  loadBooks,
  newBook,
  saveBooks,
  type BookProject,
  type BookWritingSection,
} from './bookModel';
import { BookPreview } from './BookPreview';
import { BookCoverSpread } from './BookCoverSpread';
import { BookPageView } from './BookPageView';
import { BookWritingEditor } from './BookWritingEditor';
import './BooksPage.scss';

type StudioSection = 'cover' | 'layout' | 'pages' | 'write';

const SECTION_META: Record<StudioSection, { title: string; eyebrow: string; description: string }> = {
  cover: {
    title: '封面设计',
    eyebrow: 'BOOK COVER',
    description: '先确定封面气质、堂号与书名，再查看封底、书脊和封面展开图。',
  },
  layout: {
    title: '排版设计',
    eyebrow: 'BOOK LAYOUT',
    description: '选择内页母版和字号密度，谱书会按版式自动分页。',
  },
  pages: {
    title: '页内设计',
    eyebrow: 'PAGE DESIGN',
    description: '决定序、世系图、人物页和谱成页的取舍，并检查每一页的版面。',
  },
  write: {
    title: '谱书书写',
    eyebrow: 'BOOK WRITING',
    description: '自己写谱序、世系源流、家训和后记，也可以插入现有家族内容。竖排时从左往右成列。',
  },
};

const STEPS = ['封面选择', '版式设计', '编辑内容', '制作成谱书'];

export default function BooksPage() {
  const { pathname } = useLocation();
  const section: StudioSection = pathname.endsWith('/cover')
    ? 'cover'
    : pathname.endsWith('/layout')
      ? 'layout'
      : pathname.endsWith('/pages')
        ? 'pages'
        : 'write';
  const meta = SECTION_META[section];
  useDocumentTitle(meta.title);
  const auth = useAppSelector((state) => state.auth);
  const familyId = auth.family?.id ?? '';
  const familyName = auth.family?.name ?? '家族';
  const surname = auth.family?.surname ?? '';
  const query = useAsync(
    async () => {
      const [tree, branches] = await Promise.all([personsApi.getTree(), familyApi.listBranches()]);
      return { tree, branches: branches.items };
    },
    [familyId],
    { enabled: Boolean(familyId) },
  );
  const [books, setBooks] = useState<BookProject[]>(() =>
    familyId ? loadBooks(familyId) : [],
  );
  const [editor, setEditor] = useState<BookProject | null>(null);
  const [step, setStep] = useState(0);
  const [preview, setPreview] = useState<BookProject | null>(null);
  const [building, setBuilding] = useState(false);
  const [selectedId, setSelectedId] = useState('');
  const [activeSectionId, setActiveSectionId] = useState('');

  useEffect(() => {
    if (familyId) setBooks(loadBooks(familyId));
  }, [familyId]);

  useEffect(() => {
    if (familyId) saveBooks(familyId, books);
  }, [books, familyId]);

  const generations = useMemo(() => bookGenerations(query.data?.tree ?? null), [query.data]);
  const selected = useMemo(
    () => books.find((book) => book.id === selectedId) ?? books[0] ?? null,
    [books, selectedId],
  );
  const pages = useMemo(
    () => (selected ? formBookPages(selected, query.data?.tree ?? null) : []),
    [query.data?.tree, selected],
  );
  const activeSection = useMemo(
    () =>
      selected?.writing.find((item) => item.id === activeSectionId) ??
      selected?.writing[0] ??
      null,
    [activeSectionId, selected],
  );

  useEffect(() => {
    if (!books.length) {
      setSelectedId('');
      return;
    }
    if (!books.some((book) => book.id === selectedId)) {
      setSelectedId(books[0].id);
    }
  }, [books, selectedId]);

  useEffect(() => {
    if (!selected?.writing.length) {
      setActiveSectionId('');
      return;
    }
    if (!selected.writing.some((item) => item.id === activeSectionId)) {
      setActiveSectionId(selected.writing[0].id);
    }
  }, [activeSectionId, selected]);

  const startCreate = () => {
    const draft = newBook(familyId, familyName, surname);
    draft.fromGeneration = generations[0] ?? 1;
    draft.toGeneration = generations[generations.length - 1] ?? draft.fromGeneration;
    setEditor(draft);
    setStep(0);
  };

  const startEdit = (book: BookProject) => {
    setEditor({ ...book });
    setStep(0);
  };

  const updateEditor = (patch: Partial<BookProject>) => {
    setEditor((current) => (current ? { ...current, ...patch } : current));
  };

  const persist = (book: BookProject): BookProject => {
    const saved = { ...book, updatedAt: new Date().toISOString() };
    setBooks((current) => {
      const exists = current.some((item) => item.id === saved.id);
      return exists
        ? current.map((item) => (item.id === saved.id ? saved : item))
        : [saved, ...current];
    });
    return saved;
  };

  const finish = () => {
    if (!editor) return;
    if (!editor.title.trim()) {
      Toast.warning('请先填写谱书名称');
      setStep(2);
      return;
    }
    setBuilding(true);
    window.setTimeout(() => {
      const saved = persist({ ...editor, builtAt: new Date().toISOString() });
      setBuilding(false);
      setEditor(null);
      setSelectedId(saved.id);
      setPreview(saved);
      Toast.success('谱书已制作完成');
    }, 700);
  };

  const removeBook = (book: BookProject) => {
    if (!window.confirm(`确定删除《${book.title}》吗？`)) return;
    setBooks((current) => current.filter((item) => item.id !== book.id));
    Toast.success('已删除谱书');
  };

  const updateSelected = (patch: Partial<BookProject>) => {
    if (!selected) return;
    persist({ ...selected, ...patch });
  };

  const updateWriting = (next: BookWritingSection[]) => {
    updateSelected({ writing: next });
  };

  const addWritingSection = () => {
    if (!selected) return;
    const section: BookWritingSection = {
      id: `section-${Date.now()}`,
      title: '新章节',
      body: '',
    };
    updateWriting([...selected.writing, section]);
    setActiveSectionId(section.id);
  };

  const removeWritingSection = (id: string) => {
    if (!selected) return;
    updateWriting(selected.writing.filter((item) => item.id !== id));
  };

  const patchWritingSection = (id: string, patch: Partial<BookWritingSection>) => {
    if (!selected) return;
    updateWriting(
      selected.writing.map((item) => (item.id === id ? { ...item, ...patch } : item)),
    );
  };

  const insertExisting = (kind: 'family' | 'generations' | 'people') => {
    if (!activeSection || !query.data?.tree) return;
    const tree = query.data.tree;
    let text = '';
    if (kind === 'family') {
      text = `${familyName}，${auth.family?.region || '世代聚居'}。${auth.family?.description || '家族世系绵延，家风相承。'}`;
    } else if (kind === 'generations') {
      text = generations
        .map((generation) => {
          const names = tree.persons
            .filter((person) => person.generationNo === generation)
            .map((person) => person.fullName);
          return `第${generation}世：${names.join('、')}。`;
        })
        .join('\n');
    } else {
      text = tree.persons
        .filter((person) => person.status !== 'merged')
        .slice(0, 40)
        .map((person) => {
          const years = [
            person.birth?.year ? `生${person.birth.year}` : '',
            person.death?.year ? `卒${person.death.year}` : '',
          ]
            .filter(Boolean)
            .join('，');
          return `${person.fullName}，${person.generationLabel}${years ? `，${years}` : ''}。`;
        })
        .join('\n');
    }
    const current = activeSection.body;
    patchWritingSection(activeSection.id, {
      body: current ? `${current}\n${text}` : text,
    });
  };

  const branchName = (id?: string) =>
    (query.data?.branches ?? []).find((branch) => branch.id === id)?.name ?? '';

  return (
    <div className="app-page books-page">
      <PageHeader
        eyebrow={meta.eyebrow}
        title={meta.title}
        description={meta.description}
        actions={
          <>
            {selected && query.data?.tree ? (
              <Button
                theme="borderless"
                icon={<IconEyeOpened />}
                onClick={() => setPreview(selected)}
              >
                翻书预览
              </Button>
            ) : null}
            <Button theme="solid" type="primary" icon={<IconPlus />} onClick={startCreate}>
              新建谱书
            </Button>
          </>
        }
      />

      {!books.length ? (
        <section className="books-empty surface-card">
          <div className="books-empty__icon">
            <IconBook />
          </div>
          <h2>还没有谱书</h2>
          <p>先创建一部谱书，再选择封面、版式并开始书写。</p>
          <Button theme="solid" type="primary" icon={<IconPlus />} onClick={startCreate}>
            新建第一部谱书
          </Button>
        </section>
      ) : (
        <>
          <section className="studio-bookbar" aria-label="我的谱书">
            <div className="studio-bookbar__list">
              {books.map((book) => {
                const cover = coverOption(book.coverId);
                return (
                  <button
                    type="button"
                    key={book.id}
                    className={`studio-book ${selected?.id === book.id ? 'is-active' : ''}`}
                    onClick={() => setSelectedId(book.id)}
                    title={book.title}
                  >
                    <span
                      className="studio-book__cover"
                      style={
                        {
                          '--cover-bg': cover.background,
                          '--cover-bg-dark': cover.backgroundDark,
                          '--cover-accent': cover.accent,
                          '--cover-ink': cover.ink,
                        } as React.CSSProperties
                      }
                    >
                      <i>{surname || '家'}氏</i>
                      <strong>{book.title}</strong>
                    </span>
                    <span className="studio-book__title">{book.title}</span>
                  </button>
                );
              })}
            </div>
            <Button theme="light" icon={<IconPlus />} onClick={startCreate}>
              新建
            </Button>
          </section>

          {selected ? (
            <div className="book-studio">
              <div className="book-studio__heading">
                <div>
                  <span className="book-studio__kicker">{layoutOption(selected.layoutId).name}</span>
                  <h2>{selected.title}</h2>
                  <p>
                    {selected.hallName || '未填写堂号'} · 第{selected.fromGeneration}—
                    {selected.toGeneration}世 · {pages.length} 页 ·{' '}
                    {selected.builtAt ? '已制作' : '草稿'}
                  </p>
                </div>
                <div className="book-studio__heading-actions">
                  <Button theme="borderless" icon={<IconEdit />} onClick={() => startEdit(selected)}>
                    编辑信息
                  </Button>
                  <Button
                    theme="borderless"
                    icon={<IconDelete />}
                    onClick={() => removeBook(selected)}
                  >
                    删除
                  </Button>
                </div>
              </div>

              {section === 'cover' ? (
                <section className="studio-panel">
                  <div className="studio-panel__head">
                    <div>
                      <span>STEP 01</span>
                      <h3>封面模板</h3>
                      <p>选择封面材质与颜色，堂号和书名会同步到封面展开图。</p>
                    </div>
                    <label className="studio-inline-field">
                      <span>堂号 / 宗祠</span>
                      <Input
                        value={selected.hallName}
                        onChange={(value) => updateSelected({ hallName: value })}
                        placeholder="例如：四知堂"
                      />
                    </label>
                  </div>
                  <div className="book-cover-options">
                    {COVER_OPTIONS.map((option) => (
                      <button
                        type="button"
                        key={option.id}
                        className={selected.coverId === option.id ? 'is-active' : ''}
                        onClick={() => updateSelected({ coverId: option.id })}
                      >
                        <span
                          className="book-cover-swatch"
                          style={
                            {
                              '--cover-bg': option.background,
                              '--cover-bg-dark': option.backgroundDark,
                              '--cover-accent': option.accent,
                              '--cover-ink': option.ink,
                            } as React.CSSProperties
                          }
                        >
                          <i>{surname || '家'}氏</i>
                          <strong>{selected.title}</strong>
                          <small>{selected.hallName || familyName}</small>
                        </span>
                        <b>{option.name}</b>
                        <small>{option.description}</small>
                      </button>
                    ))}
                  </div>
                  <div className="studio-cover-stage">
                    <div className="studio-cover-stage__label">封面展开图 · 封底 / 书脊 / 封面</div>
                    <BookCoverSpread
                      project={selected}
                      pageCount={pages.length}
                      familyName={familyName}
                      surname={surname}
                      branchName={branchName}
                    />
                  </div>
                </section>
              ) : null}

              {section === 'layout' ? (
                <section className="studio-panel">
                  <div className="studio-panel__head">
                    <div>
                      <span>STEP 02</span>
                      <h3>内页母版</h3>
                      <p>
                        当前按每页 {bookPeoplePerPage(selected.layoutId)} 人自动分页；下例为实际内页预览。
                      </p>
                    </div>
                  </div>
                  <div className="book-layout-options">
                    {LAYOUT_OPTIONS.map((option) => (
                      <button
                        type="button"
                        key={option.id}
                        className={selected.layoutId === option.id ? 'is-active' : ''}
                        onClick={() => updateSelected({ layoutId: option.id })}
                      >
                        <span className={`book-layout-preview book-layout-preview--${option.id}`}>
                          <i />
                          <i />
                          <i />
                          <i />
                        </span>
                        <b>{option.name}</b>
                        <small>{option.description}</small>
                      </button>
                    ))}
                  </div>
                  <div className="studio-layout-samples">
                    {pages
                      .filter((page) => page.kind === 'chapter' || page.kind === 'people')
                      .slice(0, 2)
                      .map((page) => (
                        <div className="studio-page-sample" key={page.id}>
                          <BookPageView
                            page={page}
                            project={selected}
                            familyName={familyName}
                            surname={surname}
                            branchName={branchName}
                          />
                        </div>
                      ))}
                  </div>
                </section>
              ) : null}

              {section === 'pages' ? (
                <section className="studio-panel">
                  <div className="studio-panel__head">
                    <div>
                      <span>STEP 03</span>
                      <h3>页内结构</h3>
                      <p>选择是否加入世系图和谱成页；竖排文字页会按内容自动续页。</p>
                    </div>
                    <div className="studio-page-toggles">
                      <button
                        type="button"
                        className={selected.includeLineage !== false ? 'is-active' : ''}
                        onClick={() => updateSelected({ includeLineage: selected.includeLineage === false })}
                      >
                        世系图
                      </button>
                      <button
                        type="button"
                        className={selected.includeColophon !== false ? 'is-active' : ''}
                        onClick={() => updateSelected({ includeColophon: selected.includeColophon === false })}
                      >
                        谱成页
                      </button>
                    </div>
                  </div>
                  <div className="studio-page-grid">
                    {pages.map((page, index) => (
                      <div className="studio-page-thumb" key={page.id}>
                        <BookPageView
                          page={page}
                          project={selected}
                          familyName={familyName}
                          surname={surname}
                          branchName={branchName}
                        />
                        <span>
                          {String(index + 1).padStart(2, '0')} ·{' '}
                          {page.kind === 'people'
                            ? '人物'
                            : page.kind === 'chapter'
                              ? '世系章节'
                              : page.kind === 'writing'
                                ? '书写页'
                                : page.kind === 'lineage'
                                  ? '世系图'
                                  : page.kind}
                        </span>
                      </div>
                    ))}
                  </div>
                </section>
              ) : null}

              {section === 'write' ? (
                <section className="studio-write">
                  <aside className="studio-write__sections">
                    <div className="studio-write__sections-head">
                      <span>书写章节</span>
                      <button type="button" onClick={addWritingSection} aria-label="新增章节">
                        <IconPlus />
                      </button>
                    </div>
                    {selected.writing.map((item) => (
                      <button
                        type="button"
                        key={item.id}
                        className={`studio-writing-tab ${activeSection?.id === item.id ? 'is-active' : ''}`}
                        onClick={() => setActiveSectionId(item.id)}
                      >
                        <span>{item.title || '未命名章节'}</span>
                        <small>{item.body.length} 字</small>
                        {selected.writing.length > 1 ? (
                          <i
                            role="button"
                            tabIndex={0}
                            aria-label={`删除${item.title}`}
                            onClick={(event) => {
                              event.stopPropagation();
                              removeWritingSection(item.id);
                            }}
                            onKeyDown={(event) => {
                              if (event.key === 'Enter') removeWritingSection(item.id);
                            }}
                          >
                            <IconDelete />
                          </i>
                        ) : null}
                      </button>
                    ))}
                    <p className="studio-write__auto">
                      <IconSave /> 自动保存到本机
                    </p>
                  </aside>

                  <div className="studio-write__editor">
                    {activeSection ? (
                      <>
                        <div className="studio-write__toolbar">
                          <Input
                            value={activeSection.title}
                            onChange={(value) =>
                              patchWritingSection(activeSection.id, { title: value })
                            }
                            placeholder="章节标题"
                          />
                          <div>
                            <button type="button" onClick={() => insertExisting('family')}>
                              家族简介
                            </button>
                            <button type="button" onClick={() => insertExisting('generations')}>
                              世系名单
                            </button>
                            <button type="button" onClick={() => insertExisting('people')}>
                              人物名录
                            </button>
                          </div>
                        </div>
                        <div className="writing-editor__controls">
                          <span>
                            {activeSection.body.length} 字 · 约{' '}
                            {Math.max(1, Math.ceil(activeSection.body.length / 420))} 页
                          </span>
                          <div>
                            <button
                              type="button"
                              className={selected.writingDirection !== 'rtl' ? 'is-active' : ''}
                              onClick={() => updateSelected({ writingDirection: 'ltr' })}
                            >
                              从左往右
                            </button>
                            <button
                              type="button"
                              className={selected.writingDirection === 'rtl' ? 'is-active' : ''}
                              onClick={() => updateSelected({ writingDirection: 'rtl' })}
                            >
                              从右往左
                            </button>
                          </div>
                        </div>
                        <BookWritingEditor
                          key={activeSection.id}
                          project={selected}
                          familyName={familyName}
                          surname={surname}
                          sectionTitle={activeSection.title}
                          value={activeSection.body}
                          pageCount={Math.max(1, Math.ceil(activeSection.body.length / 420))}
                          onChange={(value) =>
                            patchWritingSection(activeSection.id, { body: value })
                          }
                        />
                      </>
                    ) : (
                      <div className="studio-write__empty">
                        <p>还没有书写章节。</p>
                        <Button theme="light" icon={<IconPlus />} onClick={addWritingSection}>
                          新增章节
                        </Button>
                      </div>
                    )}
                  </div>
                </section>
              ) : null}
            </div>
          ) : null}
        </>
      )}

      {editor ? (
        <BookEditor
          book={editor}
          step={step}
          familyName={familyName}
          surname={surname}
          generations={generations}
          building={building}
          onStep={setStep}
          onChange={updateEditor}
          onClose={() => setEditor(null)}
          onSave={() => {
            const saved = persist(editor);
            setEditor(saved);
            Toast.success('谱书草稿已保存');
          }}
          onFinish={finish}
        />
      ) : null}

      {preview && query.data ? (
        <BookPreview
          project={preview}
          tree={query.data.tree}
          branches={query.data.branches}
          familyName={familyName}
          surname={surname}
          onClose={() => setPreview(null)}
        />
      ) : null}
    </div>
  );
}

function BookEditor({
  book,
  step,
  familyName,
  surname,
  generations,
  building,
  onStep,
  onChange,
  onClose,
  onSave,
  onFinish,
}: {
  book: BookProject;
  step: number;
  familyName: string;
  surname: string;
  generations: number[];
  building: boolean;
  onStep: (step: number) => void;
  onChange: (patch: Partial<BookProject>) => void;
  onClose: () => void;
  onSave: () => void;
  onFinish: () => void;
}) {
  const cover = coverOption(book.coverId);
  const layout = layoutOption(book.layoutId);
  const generationOptions = generations.map((generation) => ({
    label: `第${generation}世`,
    value: generation,
  }));

  return (
    <div className="book-editor" role="dialog" aria-modal="true" aria-label="谱书制作">
      <header className="book-editor__bar">
        <div>
          <span className="book-editor__eyebrow">BOOK WORKSHOP</span>
          <h2>{book.title || '未命名谱书'}</h2>
        </div>
        <div className="book-editor__bar-actions">
          <Button theme="borderless" onClick={onSave}>
            保存草稿
          </Button>
          <button type="button" className="book-editor__close" onClick={onClose} aria-label="关闭">
            <IconClose />
          </button>
        </div>
      </header>

      <ol className="book-editor__steps">
        {STEPS.map((label, index) => (
          <li key={label} className={index === step ? 'is-active' : index < step ? 'is-done' : ''}>
            <button type="button" onClick={() => onStep(index)}>
              <span>{index < step ? '✓' : String(index + 1).padStart(2, '0')}</span>
              <strong>{label}</strong>
            </button>
          </li>
        ))}
      </ol>

      <div className="book-editor__body">
        {step === 0 ? (
          <div className="book-step">
            <div className="book-step__heading">
              <span>STEP 01</span>
              <h3>选择封面</h3>
              <p>封面颜色会贯穿整本谱书的章节页与细节。</p>
            </div>
            <div className="book-cover-options">
              {COVER_OPTIONS.map((option) => (
                <button
                  type="button"
                  key={option.id}
                  className={book.coverId === option.id ? 'is-active' : ''}
                  onClick={() => onChange({ coverId: option.id })}
                >
                  <span
                    className="book-cover-swatch"
                    style={
                      {
                        '--cover-bg': option.background,
                        '--cover-bg-dark': option.backgroundDark,
                        '--cover-accent': option.accent,
                        '--cover-ink': option.ink,
                      } as React.CSSProperties
                    }
                  >
                    <i>{surname || '家'}氏</i>
                    <strong>{book.title || '家族谱书'}</strong>
                    <small>{familyName}</small>
                  </span>
                  <b>{option.name}</b>
                  <small>{option.description}</small>
                </button>
              ))}
            </div>
          </div>
        ) : null}

        {step === 1 ? (
          <div className="book-step">
            <div className="book-step__heading">
              <span>STEP 02</span>
              <h3>版式设计</h3>
              <p>决定内页的字体、留白和信息密度。</p>
            </div>
            <div className="book-layout-options">
              {LAYOUT_OPTIONS.map((option) => (
                <button
                  type="button"
                  key={option.id}
                  className={book.layoutId === option.id ? 'is-active' : ''}
                  onClick={() => onChange({ layoutId: option.id })}
                >
                  <span className={`book-layout-preview book-layout-preview--${option.id}`}>
                    <i />
                    <i />
                    <i />
                    <i />
                  </span>
                  <b>{option.name}</b>
                  <small>{option.description}</small>
                </button>
              ))}
            </div>
          </div>
        ) : null}

        {step === 2 ? (
          <div className="book-step book-step--form">
            <div className="book-step__heading">
              <span>STEP 03</span>
              <h3>编辑内容</h3>
              <p>谱书会按所选世代自动整理人物，序言与书名可随时修改。</p>
            </div>
            <div className="book-form">
              <label>
                <span>谱书名称</span>
                <Input
                  value={book.title}
                  onChange={(value) => onChange({ title: value })}
                  placeholder="例如：凌氏家谱"
                />
              </label>
              <label>
                <span>副标题</span>
                <Input
                  value={book.subtitle}
                  onChange={(value) => onChange({ subtitle: value })}
                  placeholder="例如：世系、人物与家风"
                />
              </label>
              <label>
                <span>堂号 / 宗祠</span>
                <Input
                  value={book.hallName}
                  onChange={(value) => onChange({ hallName: value })}
                  placeholder="例如：四知堂"
                />
              </label>
              <label>
                <span>纂修署名</span>
                <Input
                  value={book.compiler}
                  onChange={(value) => onChange({ compiler: value })}
                  placeholder="例如：凌氏修谱委员会"
                />
              </label>
              <div className="book-form__range">
                <label>
                  <span>起始世代</span>
                  <Select
                    value={book.fromGeneration}
                    optionList={generationOptions}
                    onChange={(value) =>
                      onChange({ fromGeneration: typeof value === 'number' ? value : book.fromGeneration })
                    }
                  />
                </label>
                <label>
                  <span>结束世代</span>
                  <Select
                    value={book.toGeneration}
                    optionList={generationOptions}
                    onChange={(value) =>
                      onChange({ toGeneration: typeof value === 'number' ? value : book.toGeneration })
                    }
                  />
                </label>
              </div>
              <div className="book-form__page-options">
                <span>页内内容</span>
                <div>
                  <button
                    type="button"
                    className={book.includeLineage !== false ? 'is-active' : ''}
                    onClick={() => onChange({ includeLineage: book.includeLineage === false })}
                  >
                    世系图页
                  </button>
                  <button
                    type="button"
                    className={book.includeColophon !== false ? 'is-active' : ''}
                    onClick={() => onChange({ includeColophon: book.includeColophon === false })}
                  >
                    谱成页
                  </button>
                </div>
                <div className="book-form__direction">
                  <span>书写方向</span>
                  <button
                    type="button"
                    className={book.writingDirection !== 'rtl' ? 'is-active' : ''}
                    onClick={() => onChange({ writingDirection: 'ltr' })}
                  >
                    左 → 右
                  </button>
                  <button
                    type="button"
                    className={book.writingDirection === 'rtl' ? 'is-active' : ''}
                    onClick={() => onChange({ writingDirection: 'rtl' })}
                  >
                    右 → 左
                  </button>
                </div>
              </div>
              <label className="book-form__preface">
                <span>谱序</span>
                <TextArea
                  value={book.preface}
                  autosize={{ minRows: 6, maxRows: 12 }}
                  onChange={(value) => onChange({ preface: value })}
                  placeholder="写下这次修谱的缘起、家族迁徙或想对后人说的话…"
                />
              </label>
            </div>
          </div>
        ) : null}

        {step === 3 ? (
          <div className="book-step book-step--finish">
            <div className="book-step__heading">
              <span>STEP 04</span>
              <h3>制作成谱书</h3>
              <p>确认封面和版式后生成可翻页的谱书，预览满意即可导出印刷文件。</p>
            </div>
            <div className="book-finish">
              <div
                className="book-finish__cover"
                style={
                  {
                    '--cover-bg': cover.background,
                    '--cover-bg-dark': cover.backgroundDark,
                    '--cover-accent': cover.accent,
                    '--cover-ink': cover.ink,
                  } as React.CSSProperties
                }
              >
                <span>{familyName}</span>
                {book.hallName ? <em>{book.hallName}</em> : null}
                <strong>{book.title || '家族谱书'}</strong>
                <small>{book.subtitle}</small>
                <i>{surname || '家'}氏</i>
              </div>
              <div className="book-finish__summary">
                <div>
                  <span>封面</span>
                  <strong>{cover.name}</strong>
                </div>
                <div>
                  <span>堂号</span>
                  <strong>{book.hallName || '未填写'}</strong>
                </div>
                <div>
                  <span>版式</span>
                  <strong>{layout.name}</strong>
                </div>
                <div>
                  <span>收录世代</span>
                  <strong>
                    第{book.fromGeneration}—{book.toGeneration}世
                  </strong>
                </div>
                <div>
                  <span>输出</span>
                  <strong>5x PNG / A4 印刷 PDF</strong>
                </div>
              </div>
            </div>
            <div className="book-finish__actions">
              <Button
                theme="solid"
                type="primary"
                size="large"
                loading={building}
                icon={<IconBook />}
                onClick={onFinish}
              >
                {building ? '正在装订…' : '制作并预览谱书'}
              </Button>
            </div>
          </div>
        ) : null}
      </div>

      <footer className="book-editor__footer">
        <Button
          theme="borderless"
          icon={<IconArrowLeft />}
          disabled={step === 0}
          onClick={() => onStep(step - 1)}
        >
          上一步
        </Button>
        <span>{step + 1} / {STEPS.length}</span>
        {step < STEPS.length - 1 ? (
          <Button
            theme="light"
            type="primary"
            icon={<IconArrowRight />}
            onClick={() => onStep(step + 1)}
          >
            下一步
          </Button>
        ) : (
          <Button
            theme="solid"
            type="primary"
            loading={building}
            icon={<IconBook />}
            onClick={onFinish}
          >
            制作谱书
          </Button>
        )}
      </footer>
    </div>
  );
}
