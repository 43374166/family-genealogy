import { useEffect, useRef } from 'react';
import { coverOption, type BookProject } from './bookModel';

/**
 * A real page you type into. The body uses vertical writing: Enter starts a new
 * column, and each column is separated by a printed rule.
 */
export function BookWritingEditor({
  project,
  familyName,
  surname,
  sectionTitle,
  value,
  pageCount,
  onChange,
}: {
  project: BookProject;
  familyName: string;
  surname: string;
  sectionTitle: string;
  value: string;
  pageCount: number;
  onChange: (value: string) => void;
}) {
  const canvasRef = useRef<HTMLDivElement>(null);
  const cover = coverOption(project.coverId);
  const isRtl = project.writingDirection === 'rtl';

  useEffect(() => {
    const node = canvasRef.current;
    if (!node) return;
    if (document.activeElement !== node && node.innerText !== value) {
      node.textContent = value;
    }
  }, [value]);

  const handleInput = () => {
    onChange(canvasRef.current?.innerText ?? '');
  };

  const handleKeyDown = (event: React.KeyboardEvent<HTMLDivElement>) => {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    document.execCommand('insertText', false, '\n');
    handleInput();
  };

  return (
    <div
      className={`writing-editor__page book-page book-page--writing ${
        isRtl ? 'is-rtl' : 'is-ltr'
      }`}
      style={
        {
          '--writing-accent': cover.accent,
          '--writing-bg': cover.background,
        } as React.CSSProperties
      }
    >
      <div className="book-page__inner">
        <header className="book-page__header">
          <span>{familyName}谱书</span>
          <span>谱书书写</span>
        </header>
        <div className="writing-editor__heading">
          <span>WRITING</span>
          <h3>{sectionTitle || '未命名章节'}</h3>
          <small>回车换列 · 自动保存</small>
        </div>
        <div
          ref={canvasRef}
          className="writing-editor__canvas"
          contentEditable
          suppressContentEditableWarning
          role="textbox"
          aria-multiline="true"
          aria-label={`${sectionTitle}正文`}
          data-placeholder="从这里开始写……回车会换到下一列，文字从上往下，列向左右展开。"
          onInput={handleInput}
          onKeyDown={handleKeyDown}
          onPaste={(event) => {
            event.preventDefault();
            const text = event.clipboardData.getData('text/plain');
            document.execCommand('insertText', false, text);
            handleInput();
          }}
        />
        <footer className="book-page__footer">
          <span>
            {surname || '家'}氏 · {familyName}
          </span>
          <span>{pageCount > 1 ? `共 ${pageCount} 页 · 续页自动排版` : '01'}</span>
        </footer>
      </div>
      <span className="writing-editor__frame" aria-hidden />
    </div>
  );
}
