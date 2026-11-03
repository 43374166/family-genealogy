import type { Me, QrLoginCreate, QrLoginStatus, Session } from '@/types/api';
import { request } from '@/utils/request';

export interface LoginInput {
  loginName: string;
  password: string;
}

export interface RegisterInput {
  loginName: string;
  password: string;
  displayName: string;
  inviteCode?: string;
  phone?: string;
  familyName?: string;
  surname?: string;
  acceptTerms?: boolean;
}

export interface RegistrationResult {
  user: Me['user'];
  family: Me['family'];
}

export const authApi = {
  login(input: LoginInput) {
    return request<Session>({
      url: '/auth/login',
      method: 'post',
      data: input,
      skipAuth: true,
      skipErrorToast: true,
    });
  },

  register(input: RegisterInput) {
    return request<RegistrationResult>({
      url: '/auth/register',
      method: 'post',
      data: {
        ...input,
        inviteCode: input.inviteCode ?? '',
        phone: input.phone ?? '',
        familyName: input.familyName ?? '',
        surname: input.surname ?? '',
        acceptTerms: input.acceptTerms ?? false,
      },
      skipAuth: true,
      skipErrorToast: true,
    });
  },

  createQrLogin() {
    return request<QrLoginCreate>({
      url: '/auth/qr',
      method: 'post',
      skipAuth: true,
      skipErrorToast: true,
    });
  },

  pollQrLogin(id: string, secret: string) {
    return request<QrLoginStatus>({
      url: `/auth/qr/${encodeURIComponent(id)}`,
      method: 'get',
      params: { secret },
      skipAuth: true,
      skipErrorToast: true,
    });
  },

  cancelQrLogin(id: string, secret: string) {
    return request<Record<string, never>>({
      url: `/auth/qr/${encodeURIComponent(id)}/cancel`,
      method: 'post',
      data: { secret },
      skipAuth: true,
      skipErrorToast: true,
    });
  },

  me() {
    return request<Me>({ url: '/me', method: 'get' });
  },

  logout() {
    return request<Record<string, never>>({
      url: '/auth/logout',
      method: 'post',
      skipErrorToast: true,
    });
  },

  switchFamily(familyId: string) {
    return request<Me>({
      url: '/auth/switch-family',
      method: 'post',
      data: { familyId },
    });
  },

  changePassword(currentPassword: string, newPassword: string) {
    return request<Record<string, never>>({
      url: '/me/password',
      method: 'post',
      data: { currentPassword, newPassword },
    });
  },

  acceptTerms(version = '2026-01') {
    return request<Record<string, never>>({
      url: '/auth/accept-terms',
      method: 'post',
      data: { version },
    });
  },
};
