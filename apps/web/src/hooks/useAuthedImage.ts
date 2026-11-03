import { useEffect, useState } from 'react';
import { getToken } from '@/utils/storage';
import { requestBlob } from '@/utils/request';

const cache = new Map<string, Promise<string>>();

function loadImage(path: string): Promise<string> {
  const token = getToken() ?? '';
  const key = `${token}:${path}`;
  let pending = cache.get(key);
  if (!pending) {
    pending = requestBlob(path, { skipErrorToast: true }).then((blob) => URL.createObjectURL(blob));
    cache.set(key, pending);
    pending.catch(() => cache.delete(key));
  }
  return pending;
}

/** 相册和头像接口都需要 Bearer，不能直接把受保护路径塞进 img.src。 */
export function useAuthedImage(path?: string | null, enabled = true) {
  const [url, setUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(Boolean(path && enabled));
  const [error, setError] = useState(false);

  useEffect(() => {
    if (!path || !enabled) {
      setUrl(null);
      setLoading(false);
      setError(false);
      return;
    }

    let active = true;
    setLoading(true);
    setError(false);

    loadImage(path)
      .then((resolved) => {
        if (!active) return;
        setUrl(resolved);
        setLoading(false);
      })
      .catch(() => {
        if (!active) return;
        setError(true);
        setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [path, enabled]);

  return { url, loading, error };
}
