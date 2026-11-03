import { isApiError } from '@/utils/request';

export function toErrorMessage(error: unknown, fallback = '操作失败，请稍后重试'): string {
  if (isApiError(error)) return error.message;
  if (error instanceof Error && error.message) return error.message;
  if (typeof error === 'string' && error) return error;
  return fallback;
}
