import axios, { AxiosError, type AxiosRequestConfig, type AxiosResponse } from 'axios';
import { Toast } from '@douyinfe/semi-ui';
import type { Problem } from '@/types/api';
import { clearToken, getToken } from '@/utils/storage';

export const AUTH_EXPIRED_EVENT = 'family-tree:auth-expired';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/v1';

/** 内容路径（图片）绕过 axios 的 baseURL 前缀，但仍指向同一服务。 */
export function resolveServerPath(path: string): string {
  if (/^https?:\/\//i.test(path)) return path;
  if (/^\/api\//.test(path)) {
    const configured = /^https?:\/\//i.test(API_BASE_URL)
      ? API_BASE_URL.replace(/\/api\/v1\/?$/, '')
      : '';
    return `${configured}${path}`;
  }
  return `${API_BASE_URL}${path.startsWith('/') ? path : `/${path}`}`;
}

export interface ApiErrorBody extends Problem {
  status: number;
}

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly requestId?: string;
  readonly detail?: string;
  readonly fieldErrors?: Problem['errors'];

  constructor(message: string, options: Partial<ApiErrorBody> = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = options.status ?? 0;
    this.code = options.code ?? 'NETWORK_ERROR';
    this.requestId = options.requestId;
    this.detail = options.detail;
    this.fieldErrors = options.errors;
  }
}

export function isApiError(value: unknown): value is ApiError {
  return value instanceof ApiError;
}

function isProblem(value: unknown): value is Partial<Problem> {
  return typeof value === 'object' && value !== null && 'code' in value;
}

function normalizeError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;

  if (axios.isCancel(error)) {
    return new ApiError('请求已取消', { code: 'REQUEST_CANCELED', status: 0 });
  }

  const axiosError = error as AxiosError<unknown>;
  const response = axiosError.response;
  if (response) {
    const body = response.data;
    if (isProblem(body)) {
      return new ApiError(body.detail || body.title || `请求失败（${response.status}）`, {
        ...body,
        status: body.status ?? response.status,
      });
    }
    return new ApiError(`请求失败（${response.status}）`, {
      status: response.status,
      code: `HTTP_${response.status}`,
    });
  }

  if (axiosError.code === 'ECONNABORTED' || axiosError.code === 'ETIMEDOUT') {
    return new ApiError('连接服务器超时，请稍后重试', { code: 'TIMEOUT' });
  }

  if (axiosError.message) {
    return new ApiError('无法连接服务器，请检查网络或服务地址', {
      code: axiosError.code ?? 'NETWORK_ERROR',
    });
  }

  return new ApiError('发生未知错误，请稍后重试', { code: 'UNKNOWN_ERROR' });
}

declare module 'axios' {
  export interface AxiosRequestConfig {
    /** 公开接口（登录、注册）不附带 Bearer token。 */
    skipAuth?: boolean;
    /** 由页面自行呈现错误时，关闭全局 Toast。 */
    skipErrorToast?: boolean;
  }
}

const client = axios.create({
  baseURL: API_BASE_URL,
  timeout: 20_000,
  headers: {
    Accept: 'application/json',
  },
});

let lastAuthExpiredAt = 0;

function notifyAuthExpired(): void {
  const now = Date.now();
  // 多个并发请求同时 401 时只触发一次全局退出。
  if (now - lastAuthExpiredAt < 1000) return;
  lastAuthExpiredAt = now;
  clearToken();
  window.dispatchEvent(new CustomEvent(AUTH_EXPIRED_EVENT));
}

function requestId(): string {
  // crypto.randomUUID 只在安全上下文可用；HTTP 局域网部署需要回退。
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

client.interceptors.request.use((config) => {
  const token = getToken();
  if (token && !config.skipAuth) {
    config.headers.set('Authorization', `Bearer ${token}`);
  }
  config.headers.set('X-Request-Id', requestId());
  if (config.data instanceof FormData) {
    delete config.headers['Content-Type'];
  }
  return config;
});

export interface FlatResult<T> {
  data: T | null;
  error: ApiError | null;
  status?: number;
}

/**
 * 与 md2card 的 createFlatRequest 一致：HTTP 层不抛异常，统一返回
 * `{ data, error }`，页面/Redux thunk 可以显式分支处理。错误信息按
 * RFC 9457 的 `detail → title → HTTP 状态` 顺序提取，并默认弹出一次 Toast。
 */
export async function flatRequest<T>(config: AxiosRequestConfig): Promise<FlatResult<T>> {
  try {
    const response = await client.request<T>(config);
    if (response.status === 204) {
      return { data: {} as T, error: null, status: response.status };
    }
    return { data: response.data, error: null, status: response.status };
  } catch (error) {
    const apiError = normalizeError(error);

    if (apiError.status === 401 && !config.skipAuth) {
      notifyAuthExpired();
    }

    const silent = config.skipErrorToast || apiError.code === 'REQUEST_CANCELED';
    if (!silent && !(apiError.status === 401 && !config.skipAuth)) {
      Toast.error({
        content: apiError.message,
        duration: 3.2,
        id: `api-error-${apiError.code}`,
      });
    }

    return { data: null, error: apiError, status: apiError.status };
  }
}

export async function request<T>(config: AxiosRequestConfig): Promise<T> {
  const result = await flatRequest<T>(config);
  if (result.error) throw result.error;
  return result.data as T;
}

const contentClient = axios.create({
  timeout: 20_000,
  headers: { Accept: 'image/*' },
});

export async function requestBlob(
  path: string,
  options: { skipErrorToast?: boolean } = {},
): Promise<Blob> {
  try {
    const token = getToken();
    const response: AxiosResponse<Blob> = await contentClient.get(resolveServerPath(path), {
      responseType: 'blob',
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    });
    return response.data;
  } catch (error) {
    const apiError = normalizeError(error);
    if (apiError.status === 401) notifyAuthExpired();
    if (!options.skipErrorToast && apiError.status !== 404) {
      Toast.error({ content: '图片加载失败', duration: 2.5 });
    }
    throw apiError;
  }
}

export { client as axiosInstance, API_BASE_URL };
