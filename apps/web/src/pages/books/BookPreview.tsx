import { useEffect, useMemo, useRef, useState } from 'react';
import { Button, Toast } from '@douyinfe/semi-ui';
import { IconArrowLeft, IconArrowRight, IconClose, IconDownload, IconPrint } from '@douyinfe/semi-icons';
import { zipSync } from 'fflate';
import type { Branch, FamilyTree } from '@/types/api';
import {
  captureNodePng,
  dataUrlToUint8,
  downloadBlob,
  downloadDataUrl,
  imagesAsPdf,
  safeFilename,
} from '@/utils/export';
import { formBookPages, type BookPage, type BookProject } from './bookModel';
import { BookPageView } from './BookPageView';
import './BooksPage.scss';

const PAGE_WIDTH = 430;
const PAGE_HEIGHT = 610;

export function BookPreview({
  project,
  tree,
  branches,
  familyName,
  surname,
  onClose,
}: {
  project: BookProject;
  tree: FamilyTree | null;
  branches: Branch[];
  familyName: string;
  surname: string;
  onClose: () => void;
}) {
  const pages = useMemo(() => formBookPages(project, tree), [project, tree]);
  const spreads = useMemo(() => {
    const inner = pages.slice(1);
    if (inner.length % 2 !== 0) {
      inner.push({ id: 'blank-end', kind: 'blank' });
    }
    const result: BookPage[][] = [];
    for (let index = 0; index < inner.length; index += 2) {
      result.push(inner.slice(index, index + 2));
    }
    return result;
  }, [pages]);
  const [opened, setOpened] = useState(false);
  const [spreadIndex, setSpreadIndex] = useState(0);
  const [tube, setTube] = useState(false);
  const [flipping, setFlipping] = useState<'next' | 'prev' | null>(null);
  const [scale, setScale] = useState(0.86);
  const [exporting, setExporting] = useState<'spread' | 'png' | 'pdf' | null>(null);
  const spreadRef = useRef<HTMLDivElement>(null);
  const pageRefs = useRef<Array<HTMLDivElement | null>>([]);
  const timerRef = useRef<number | null>(null);

  const branchName = (id?: string) => branches.find((branch) => branch.id === id)?.name ?? '';
  const baseName = safeFilename(`${familyName}-${project.title}`, 'family-book');

  useEffect(() => {
    const resize = () => {
      const width = Math.min(window.innerWidth - 64, 980);
      const height = window.innerHeight - 250;
      setScale(Math.max(0.28, Math.min(1, width / (PAGE_WIDTH * 2), height / PAGE_HEIGHT)));
    };
    resize();
    window.addEventListener('resize', resize);
    return () => window.removeEventListener('resize', resize);
  }, []);

  useEffect(() => {
    return () => {
      if (timerRef.current) window.clearTimeout(timerRef.current);
    };
  }, []);

  const turn = (direction: 'next' | 'prev') => {
    if (flipping) return;
    if (direction === 'next' && spreadIndex >= spreads.length - 1) return;
    if (direction === 'prev' && spreadIndex <= 0) return;
    setFlipping(direction);
    timerRef.current = window.setTimeout(() => {
      setSpreadIndex((index) => index + (direction === 'next' ? 1 : -1));
      setFlipping(null);
      timerRef.current = null;
    }, 420);
  };

  const exportSpread = async () => {
    if (!spreadRef.current) return;
    setExporting('spread');
    try {
      const dataUrl = await captureNodePng(spreadRef.current, {
        pixelRatio: 5,
        backgroundColor: '#f6f2e8',
      });
      downloadDataUrl(dataUrl, `${baseName}-跨页-${spreadIndex + 1}.png`);
      Toast.success('已导出 5x 无损跨页 PNG');
    } catch (error) {
      console.error(error);
      Toast.error('跨页导出失败，请稍后重试');
    } finally {
      setExporting(null);
    }
  };

  const captureAllPages = async (): Promise<string[]> => {
    const images: string[] = [];
    for (let index = 0; index < pages.length; index += 1) {
      const node = pageRefs.current[index];
      if (!node) continue;
      images.push(
        await captureNodePng(node, { pixelRatio: 5, backgroundColor: '#f6f2e8' }),
      );
    }
    return images;
  };

  const exportAllPng = async () => {
    setExporting('png');
    try {
      const images = await captureAllPages();
      const files: Record<string, Uint8Array> = {};
      images.forEach((image, index) => {
        files[`${baseName}-${String(index + 1).padStart(2, '0')}.png`] =
          dataUrlToUint8(image);
      });
      downloadBlob(
        new Blob([zipSync(files)], { type: 'application/zip' }),
        `${baseName}-全本PNG.zip`,
      );
      Toast.success('已导出全本 5x 无损 PNG 压缩包');
    } catch (error) {
      console.error(error);
      Toast.error('全本 PNG 导出失败，请稍后重试');
    } finally {
      setExporting(null);
    }
  };

  const exportAllPdf = async () => {
    setExporting('pdf');
    try {
      const images = await captureAllPages();
      await imagesAsPdf(images, `${baseName}-印刷版.pdf`, { format: 'a4' });
      Toast.success('已导出 A4 高清 PDF');
    } catch (error) {
      console.error(error);
      Toast.error('PDF 导出失败，请稍后重试');
    } finally {
      setExporting(null);
    }
  };

  if (!pages.length) {
    return (
      <div className="book-viewer">
        <div className="book-viewer__empty">
          <p>还没有可排入谱书的成员。</p>
          <Button onClick={onClose}>返回</Button>
        </div>
      </div>
    );
  }

  const spread = spreads[spreadIndex] ?? [];

  return (
    <div className="book-viewer" role="dialog" aria-modal="true" aria-label="谱书预览">
      <header className="book-viewer__bar">
        <div>
          <span className="book-viewer__eyebrow">BOOK PREVIEW</span>
          <h2>{project.title}</h2>
        </div>
        <div className="book-viewer__actions">
          <button
            type="button"
            className={tube ? 'is-active' : ''}
            onClick={() => setTube((value) => !value)}
          >
            筒子页
          </button>
          <Button
            theme="borderless"
            icon={<IconDownload />}
            loading={exporting === 'spread'}
            disabled={Boolean(exporting)}
            onClick={exportSpread}
          >
            跨页 PNG
          </Button>
          <Button
            theme="borderless"
            icon={<IconDownload />}
            loading={exporting === 'png'}
            disabled={Boolean(exporting)}
            onClick={exportAllPng}
          >
            全本 PNG
          </Button>
          <Button
            theme="borderless"
            icon={<IconPrint />}
            loading={exporting === 'pdf'}
            disabled={Boolean(exporting)}
            onClick={exportAllPdf}
          >
            全本 PDF
          </Button>
          <button type="button" className="book-viewer__close" onClick={onClose} aria-label="关闭预览">
            <IconClose />
          </button>
        </div>
      </header>

      <div className="book-viewer__stage">
        <div
          className="book-viewer__scaler"
          style={{
            width: opened ? PAGE_WIDTH * 2 * scale : PAGE_WIDTH * scale,
            height: PAGE_HEIGHT * scale,
          }}
        >
          <div
            className="book-viewer__paper"
            style={{
              width: opened ? PAGE_WIDTH * 2 : PAGE_WIDTH,
              height: PAGE_HEIGHT,
              transform: `scale(${scale})`,
            }}
          >
            {!opened ? (
              <div className="book-viewer__cover">
                <BookPageView
                  page={pages[0]}
                  project={project}
                  familyName={familyName}
                  surname={surname}
                  branchName={branchName}
                />
                <button
                  type="button"
                  className="book-viewer__open"
                  onClick={() => setOpened(true)}
                >
                  翻开谱书
                  <IconArrowRight />
                </button>
              </div>
            ) : (
              <div
                ref={spreadRef}
                className={`book-spread ${tube ? 'is-tube' : ''} ${
                  flipping ? `is-flipping-${flipping}` : ''
                }`}
              >
                {spread.map((page, index) => (
                  <div className={`book-spread__side book-spread__side--${index}`} key={page.id}>
                    <BookPageView
                      page={page}
                      project={project}
                      familyName={familyName}
                      surname={surname}
                      branchName={branchName}
                    />
                  </div>
                ))}
                <span className="book-spread__gutter" aria-hidden />
                {flipping ? <span className="book-spread__turn-sheet" aria-hidden /> : null}
              </div>
            )}
          </div>
        </div>
      </div>

      {opened ? (
        <footer className="book-viewer__footer">
          <button
            type="button"
            onClick={() => turn('prev')}
            disabled={spreadIndex === 0 || Boolean(flipping)}
            aria-label="上一页"
          >
            <IconArrowLeft />
          </button>
          <span>
            {spreadIndex + 1} / {spreads.length}
            <em>{tube ? ' · 筒子页' : ' · 双页展开'}</em>
          </span>
          <button
            type="button"
            onClick={() => turn('next')}
            disabled={spreadIndex >= spreads.length - 1 || Boolean(flipping)}
            aria-label="下一页"
          >
            <IconArrowRight />
          </button>
          <button
            type="button"
            className="book-viewer__close-book"
            onClick={() => {
              setOpened(false);
              setSpreadIndex(0);
            }}
          >
            合上
          </button>
        </footer>
      ) : null}

      <div className="book-print-host" aria-hidden>
        {pages.map((page, index) => (
          <div
            className="book-print-page"
            key={page.id}
            ref={(node) => {
              pageRefs.current[index] = node;
            }}
            style={{ width: PAGE_WIDTH, height: PAGE_HEIGHT }}
          >
            <BookPageView
              page={page}
              project={project}
              familyName={familyName}
              surname={surname}
              branchName={branchName}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
