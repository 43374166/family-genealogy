import { useEffect } from 'react';

const APP_NAME = '家族族谱';

export function useDocumentTitle(title?: string): void {
  useEffect(() => {
    document.title = title ? `${title} · ${APP_NAME}` : `${APP_NAME} · 寻根溯源`;
  }, [title]);
}
