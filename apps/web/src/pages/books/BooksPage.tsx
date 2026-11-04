import { useEffect, useMemo, useState } from 'react';
import { Button, Input, TextArea, Toast } from '@douyinfe/semi-ui';
import { SafeSelect as Select } from '@/components/SafeSelect';
import {
  IconArrowLeft,
  IconArrowRight,
  IconBook,
  IconCheckCircleStroked,
  IconClose,
  IconDelete,
  IconEdit,
  IconEyeOpened,
  IconPlus,
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
  coverOption,
  layoutOption,
  loadBooks,
  newBook,
  saveBooks,
  type BookProject,
} from './bookModel';
import { BookPreview } from './BookPreview';
import './BooksPage.scss';

const STEPS = ['封面选择', '版式设计', '编辑内容', '制作成谱书'];

export default function BooksPage() {
  useDocumentTitle('谱书工作区');
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

  useEffect(() => {
    if (familyId) setBooks(loadBooks(familyId));
  }, [familyId]);

  useEffect(() => {
    if (familyId) saveBooks(familyId, books);
  }, [books, familyId]);

  const generations = useMemo(() => bookGenerations(query.data?.tree ?? null), [query.data]);

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
      setPreview(saved);
      Toast.success('谱书已制作完成');
    }, 700);
  };

  const removeBook = (book: BookProject) => {
    if (!window.confirm(`确定删除《${book.title}》吗？`)) return;
    setBooks((current) => current.filter((item) => item.id !== book.id));
    Toast.success('已删除谱书');
  };

  return (
    <div className="app-page books-page">
      <PageHeader
        eyebrow="FAMILY BOOKS"
        title="谱书工作区"
        description="把族谱整理成一本可以翻阅、可以印刷的家谱。封面、版式、内容与成书都在这里完成。"
        actions={
          <Button theme="solid" type="primary" icon={<IconPlus />} onClick={startCreate}>
            新建谱书
          </Button>
        }
      />

      <section className="books-hero">
        <div className="books-hero__intro">
          <span className="books-hero__seal">谱</span>
          <div>
            <h2>从一张族谱，到一部家谱</h2>
            <p>
              选择封面与版式，补上序言和世系内容，制作成可在浏览器中翻页的谱书。
              所有页面都按印刷尺寸排版，可导出高分辨率 PNG 与 PDF。
            </p>
          </div>
        </div>
        <div className="books-flow">
          {STEPS.map((label, index) => (
            <div className="books-flow__step" key={label}>
              <span>{String(index + 1).padStart(2, '0')}</span>
              <strong>{label}</strong>
              {index < STEPS.length - 1 ? <IconArrowRight /> : null}
            </div>
          ))}
        </div>
      </section>

      {books.length ? (
        <section className="books-grid">
          {books.map((book) => {
            const cover = coverOption(book.coverId);
            return (
              <article className="book-card" key={book.id}>
                <div
                  className="book-mini-cover"
                  style={
                    {
                      '--cover-bg': cover.background,
                      '--cover-bg-dark': cover.backgroundDark,
                      '--cover-accent': cover.accent,
                      '--cover-ink': cover.ink,
                    } as React.CSSProperties
                  }
                >
                  <span className="book-mini-cover__family">{familyName}</span>
                  <strong>{book.title}</strong>
                  <small>{book.subtitle}</small>
                  <i>{surname || '家'}氏</i>
                  <span className="book-mini-cover__spine" />
                </div>
                <div className="book-card__body">
                  <div className="book-card__head">
                    <div>
                      <h3>{book.title}</h3>
                      <p>{layoutOption(book.layoutId).name} · {book.builtAt ? '已制作' : '草稿'}</p>
                    </div>
                    <span className="book-card__status">
                      {book.builtAt ? <IconCheckCircleStroked /> : null}
                      {book.builtAt ? '可预览' : '未完成'}
                    </span>
                  </div>
                  <p className="book-card__meta">
                    第{book.fromGeneration}—{book.toGeneration}世 · 更新于{' '}
                    {new Date(book.updatedAt).toLocaleDateString('zh-CN')}
                  </p>
                  <div className="book-card__actions">
                    <Button theme="borderless" icon={<IconEdit />} onClick={() => startEdit(book)}>
                      继续编辑
                    </Button>
                    <Button
                      theme="light"
                      type="primary"
                      icon={<IconEyeOpened />}
                      disabled={!book.builtAt || !query.data?.tree}
                      onClick={() => setPreview(book)}
                    >
                      预览谱书
                    </Button>
                    <button
                      type="button"
                      className="book-card__delete"
                      onClick={() => removeBook(book)}
                      aria-label={`删除${book.title}`}
                    >
                      <IconDelete />
                    </button>
                  </div>
                </div>
              </article>
            );
          })}
        </section>
      ) : (
        <section className="books-empty surface-card">
          <div className="books-empty__icon">
            <IconBook />
          </div>
          <h2>还没有谱书</h2>
          <p>从封面开始，制作第一部属于这个家族的谱书。</p>
          <Button theme="solid" type="primary" icon={<IconPlus />} onClick={startCreate}>
            新建第一部谱书
          </Button>
        </section>
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
