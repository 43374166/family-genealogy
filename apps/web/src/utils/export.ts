import { toPng } from 'html-to-image';
import { jsPDF } from 'jspdf';

function waitForImage(image: HTMLImageElement): Promise<void> {
  if (image.complete) return Promise.resolve();
  return new Promise((resolve) => {
    const done = () => {
      image.removeEventListener('load', done);
      image.removeEventListener('error', done);
      resolve();
    };
    image.addEventListener('load', done, { once: true });
    image.addEventListener('error', done, { once: true });
    window.setTimeout(done, 5000);
  });
}

export async function waitForNodeAssets(node: HTMLElement): Promise<void> {
  await Promise.all(Array.from(node.querySelectorAll('img')).map(waitForImage));
  if (document.fonts?.ready) await document.fonts.ready;
  await new Promise((resolve) => window.requestAnimationFrame(() => resolve(undefined)));
}

export async function captureNodePng(
  node: HTMLElement,
  options: { pixelRatio?: number; backgroundColor?: string } = {},
): Promise<string> {
  await waitForNodeAssets(node);
  return toPng(node, {
    pixelRatio: options.pixelRatio ?? 4,
    backgroundColor: options.backgroundColor ?? '#f6f5ef',
    cacheBust: true,
    skipAutoScale: true,
    style: {
      transform: 'none',
      margin: '0',
    },
  });
}

export function downloadDataUrl(dataUrl: string, filename: string): void {
  const link = document.createElement('a');
  link.href = dataUrl;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
}

export function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  downloadDataUrl(url, filename);
  window.setTimeout(() => URL.revokeObjectURL(url), 2000);
}

export function dataUrlToUint8(dataUrl: string): Uint8Array {
  const base64 = dataUrl.split(',')[1] ?? '';
  const binary = window.atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

export function safeFilename(value: string, fallback = 'family-tree'): string {
  const cleaned = value
    .trim()
    .replace(/[\\/:*?"<>|]+/g, '-')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
  return cleaned || fallback;
}

export interface PdfImageOptions {
  format?: 'a3' | 'a4' | 'a2';
  orientation?: 'portrait' | 'landscape';
  marginMm?: number;
}

function loadImage(dataUrl: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error('image decode failed'));
    image.src = dataUrl;
  });
}

export async function imageAsPdf(
  dataUrl: string,
  filename: string,
  options: PdfImageOptions = {},
): Promise<void> {
  const image = await loadImage(dataUrl);
  const width = image.naturalWidth || 2400;
  const height = image.naturalHeight || 1600;
  const orientation =
    options.orientation ?? (width >= height ? 'landscape' : 'portrait');
  const pdf = new jsPDF({
    orientation,
    unit: 'mm',
    format: options.format ?? 'a3',
    compress: true,
  });
  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();
  const margin = options.marginMm ?? 8;
  const ratio = Math.min(
    (pageWidth - margin * 2) / width,
    (pageHeight - margin * 2) / height,
  );
  const drawWidth = width * ratio;
  const drawHeight = height * ratio;
  pdf.addImage(
    dataUrl,
    'PNG',
    (pageWidth - drawWidth) / 2,
    (pageHeight - drawHeight) / 2,
    drawWidth,
    drawHeight,
    undefined,
    'SLOW',
  );
  pdf.save(filename);
}

export async function imagesAsPdf(
  images: string[],
  filename: string,
  options: { format?: 'a3' | 'a4'; marginMm?: number } = {},
): Promise<void> {
  if (!images.length) return;
  const pdf = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: options.format ?? 'a4',
    compress: true,
  });
  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();
  const margin = options.marginMm ?? 0;
  for (let index = 0; index < images.length; index += 1) {
    if (index > 0) pdf.addPage();
    const dataUrl = images[index];
    const image = await loadImage(dataUrl);
    const width = image.naturalWidth || 1200;
    const height = image.naturalHeight || 1700;
    const ratio = Math.min(
      (pageWidth - margin * 2) / width,
      (pageHeight - margin * 2) / height,
    );
    const drawWidth = width * ratio;
    const drawHeight = height * ratio;
    pdf.addImage(
      dataUrl,
      'PNG',
      (pageWidth - drawWidth) / 2,
      (pageHeight - drawHeight) / 2,
      drawWidth,
      drawHeight,
      undefined,
      'SLOW',
    );
  }
  pdf.save(filename);
}
