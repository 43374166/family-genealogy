import type {
  Branch,
  CreatePersonInput,
  FamilyTree,
  Person,
  PersonPage,
  UpdatePersonInput,
} from '@/types/api';
import { request } from '@/utils/request';

export interface ListPersonsParams {
  q?: string;
  generation?: number;
  branchId?: string;
  cursor?: string;
  limit?: number;
}

export const personsApi = {
  getTree() {
    return request<FamilyTree>({ url: '/tree', method: 'get' });
  },

  listPersons(params: ListPersonsParams = {}) {
    return request<PersonPage>({
      url: '/persons',
      method: 'get',
      params: {
        ...(params.q?.trim() ? { q: params.q.trim() } : {}),
        ...(params.generation ? { generation: params.generation } : {}),
        ...(params.branchId ? { branchId: params.branchId } : {}),
        ...(params.cursor ? { cursor: params.cursor } : {}),
        limit: params.limit ?? 20,
      },
    });
  },

  getPerson(personId: string) {
    return request<Person>({
      url: `/persons/${encodeURIComponent(personId)}`,
      method: 'get',
    });
  },

  createPerson(input: CreatePersonInput) {
    return request<Person>({
      url: '/persons',
      method: 'post',
      data: normalizePersonInput(input),
    });
  },

  updatePerson(personId: string, input: UpdatePersonInput) {
    return request<Person>({
      url: `/persons/${encodeURIComponent(personId)}`,
      method: 'patch',
      data: normalizePersonInput(input),
    });
  },

  deletePerson(personId: string) {
    return request<{ archived: boolean }>({
      url: `/persons/${encodeURIComponent(personId)}`,
      method: 'delete',
    });
  },

  addParentChild(parentId: string, childId: string, parentRole: 'father' | 'mother') {
    return request<{ id: string }>({
      url: '/relationships/parent-child',
      method: 'post',
      data: { parentId, childId, parentRole },
    });
  },

  deleteParentChild(edgeId: string) {
    return request<Record<string, never>>({
      url: `/relationships/parent-child/${encodeURIComponent(edgeId)}`,
      method: 'delete',
    });
  },

  addSpouse(personAId: string, personBId: string) {
    return request<{ id: string }>({
      url: '/relationships/spouse',
      method: 'post',
      data: { personAId, personBId },
    });
  },

  deleteSpouse(edgeId: string) {
    return request<Record<string, never>>({
      url: `/relationships/spouse/${encodeURIComponent(edgeId)}`,
      method: 'delete',
    });
  },

  uploadAvatar(personId: string, file: File) {
    const form = new FormData();
    form.append('file', file);
    return request<{ hasAvatar: boolean }>({
      url: `/persons/${encodeURIComponent(personId)}/avatar`,
      method: 'post',
      data: form,
    });
  },

  deleteAvatar(personId: string) {
    return request<Record<string, never>>({
      url: `/persons/${encodeURIComponent(personId)}/avatar`,
      method: 'delete',
    });
  },

  avatarPath(personId: string) {
    return `/api/v1/persons/${encodeURIComponent(personId)}/avatar`;
  },
};

/** 服务端 DisallowUnknownFields，只提交白名单字段。 */
function normalizePersonInput(input: CreatePersonInput | UpdatePersonInput) {
  const result: Record<string, unknown> = {
    surname: input.surname,
    givenName: input.givenName,
    courtesyName: input.courtesyName ?? '',
    alias: input.alias ?? '',
    gender: input.gender,
    generationNo: input.generationNo,
    generationName: input.generationName ?? '',
    branchId: input.branchId,
    birthOrder: input.birthOrder ?? null,
    lifeStatus: input.lifeStatus,
    biography: input.biography ?? '',
  };

  const dateFields = [
    'birthYear',
    'birthMonth',
    'birthDay',
    'birthCalendar',
    'birthIsLeapMonth',
    'deathYear',
    'deathMonth',
    'deathDay',
    'deathCalendar',
    'deathIsLeapMonth',
  ] as const;
  for (const key of dateFields) {
    if (input[key] !== undefined) result[key] = input[key];
  }

  if ('version' in input) {
    result.version = input.version;
    result.birthPlace = input.birthPlace;
    result.residence = input.residence;
    result.occupation = input.occupation;
    result.education = input.education;
  }

  return result;
}

export type { Branch };
