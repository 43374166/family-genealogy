import { useCallback, useEffect, useRef, useState } from 'react';
import { isApiError } from '@/utils/request';

export interface AsyncState<T> {
  data: T | null;
  loading: boolean;
  refreshing: boolean;
  error: string | null;
}

interface UseAsyncOptions<T> {
  enabled?: boolean;
  initialData?: T | null;
  /** 为 true 时不显示 loading（用于轮询等静默刷新）。 */
  quiet?: boolean;
}

/**
 * 统一处理页面级异步读取：竞态保护、取消信号、loading/error 和手动刷新。
 * loader 不进入依赖，由 deps 决定何时重新发起请求。
 */
export function useAsync<T>(
  loader: (signal: AbortSignal) => Promise<T>,
  deps: unknown[],
  options: UseAsyncOptions<T> = {},
) {
  const { enabled = true, initialData = null, quiet = false } = options;
  const loaderRef = useRef(loader);
  loaderRef.current = loader;

  const [state, setState] = useState<AsyncState<T>>({
    data: initialData,
    loading: enabled && !quiet,
    refreshing: false,
    error: null,
  });
  const [reloadToken, setReloadToken] = useState(0);
  const hasLoadedRef = useRef(false);

  useEffect(() => {
    if (!enabled) {
      setState((current) => ({ ...current, loading: false, refreshing: false }));
      return;
    }

    let active = true;
    const controller = new AbortController();
    setState((current) => ({
      ...current,
      loading: !hasLoadedRef.current && !quiet,
      refreshing: hasLoadedRef.current || quiet,
      error: null,
    }));

    loaderRef
      .current(controller.signal)
      .then((data) => {
        if (!active) return;
        hasLoadedRef.current = true;
        setState({ data, loading: false, refreshing: false, error: null });
      })
      .catch((error: unknown) => {
        if (!active || controller.signal.aborted) return;
        hasLoadedRef.current = true;
        setState((current) => ({
          ...current,
          loading: false,
          refreshing: false,
          error: isApiError(error) ? error.message : '加载失败，请稍后重试',
        }));
      });

    return () => {
      active = false;
      controller.abort();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled, reloadToken, quiet, ...deps]);

  const refresh = useCallback(() => {
    setReloadToken((value) => value + 1);
  }, []);

  const setData = useCallback((updater: T | null | ((current: T | null) => T | null)) => {
    setState((current) => ({
      ...current,
      data:
        typeof updater === 'function'
          ? (updater as (current: T | null) => T | null)(current.data)
          : updater,
    }));
  }, []);

  return { ...state, refresh, setData };
}
