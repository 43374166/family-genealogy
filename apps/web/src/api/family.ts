import type {
  Branch,
  Family,
  FamilyAccountPage,
  GenerationName,
  GenerationNameSet,
  Invite,
  InvitePage,
} from '@/types/api';
import { request } from '@/utils/request';

export interface CreateInviteInput {
  role: 'member' | 'admin';
  branchId?: string;
  maxUses: number;
  expiresInDays: number;
}

export const familyApi = {
  getFamily() {
    return request<Family>({ url: '/family', method: 'get' });
  },

  updateFamily(input: Pick<Family, 'name' | 'surname' | 'motto' | 'region' | 'description'>) {
    return request<Family>({ url: '/family', method: 'patch', data: input });
  },

  listBranches() {
    return request<{ items: Branch[] }>({ url: '/branches', method: 'get' });
  },

  createBranch(name: string) {
    return request<Branch>({ url: '/branches', method: 'post', data: { name } });
  },

  updateBranch(branchId: string, input: { name: string; sortOrder?: number }) {
    return request<Branch>({
      url: `/branches/${encodeURIComponent(branchId)}`,
      method: 'patch',
      data: input,
    });
  },

  deleteBranch(branchId: string) {
    return request<Record<string, never>>({
      url: `/branches/${encodeURIComponent(branchId)}`,
      method: 'delete',
    });
  },

  listAccounts() {
    return request<FamilyAccountPage>({ url: '/accounts', method: 'get' });
  },

  updateAccountRole(userId: string, role: 'admin' | 'member') {
    return request<Record<string, never>>({
      url: `/accounts/${encodeURIComponent(userId)}`,
      method: 'patch',
      data: { role },
    });
  },

  listInvites() {
    return request<InvitePage>({ url: '/invites', method: 'get' });
  },

  createInvite(input: CreateInviteInput) {
    return request<Invite>({
      url: '/invites',
      method: 'post',
      data: {
        role: input.role,
        branchId: input.branchId ?? '',
        maxUses: input.maxUses,
        expiresInDays: input.expiresInDays,
      },
    });
  },

  getGenerationNames() {
    return request<GenerationNameSet>({ url: '/generation-names', method: 'get' });
  },

  saveGenerationNames(items: GenerationName[], poem = '') {
    return request<GenerationNameSet>({
      url: '/generation-names',
      method: 'put',
      data: { items, poem },
    });
  },
};
