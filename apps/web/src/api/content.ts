import type {
  ActivityPage,
  Anniversary,
  EditRequest,
  EditRequestPage,
  EditRequestStatus,
  NotificationPage,
  PersonEditChanges,
  Photo,
  PhotoPage,
  Story,
  StoryPage,
} from '@/types/api';
import { request } from '@/utils/request';

export const contentApi = {
  listActivity(limit = 20) {
    return request<ActivityPage>({
      url: '/activity',
      method: 'get',
      params: { limit },
    });
  },

  listAnniversaries(days = 60) {
    return request<{ items: Anniversary[]; days: number }>({
      url: '/anniversaries',
      method: 'get',
      params: { days },
    });
  },

  listPhotos(personIds: string[] = [], solePersonId?: string) {
    return request<PhotoPage>({
      url: '/photos',
      method: 'get',
      params: {
        ...(personIds.length ? { personIds: personIds.join(',') } : {}),
        ...(solePersonId ? { solePersonId } : {}),
      },
    });
  },

  uploadPhoto(input: {
    file: File;
    personIds: string[];
    caption: string;
    takenAt?: string;
  }) {
    const form = new FormData();
    form.append('file', input.file);
    if (input.personIds.length) {
      form.append('personIds', input.personIds.join(','));
      form.append('personId', input.personIds[0]);
    }
    form.append('caption', input.caption);
    if (input.takenAt) form.append('takenAt', input.takenAt);
    return request<Photo>({ url: '/photos', method: 'post', data: form });
  },

  updatePhoto(photoId: string, input: { personIds: string[]; caption: string; takenAt?: string }) {
    return request<Photo>({
      url: `/photos/${encodeURIComponent(photoId)}`,
      method: 'patch',
      data: {
        personId: input.personIds[0] ?? '',
        personIds: input.personIds,
        caption: input.caption,
        takenAt: input.takenAt ?? '',
      },
    });
  },

  deletePhoto(photoId: string) {
    return request<Record<string, never>>({
      url: `/photos/${encodeURIComponent(photoId)}`,
      method: 'delete',
    });
  },

  async listStories() {
    const page = await request<StoryPage>({ url: '/stories', method: 'get' });
    return { ...page, items: (page.items ?? []).map(normalizeStoryPhotos) };
  },

  async getStory(storyId: string) {
    const story = await request<Story>({
      url: `/stories/${encodeURIComponent(storyId)}`,
      method: 'get',
    });
    return normalizeStoryPhotos(story);
  },

  async createStory(input: {
    title: string;
    body: string;
    personId?: string;
    photoIds?: string[];
  }) {
    const story = await request<Story>({
      url: '/stories',
      method: 'post',
      data: {
        title: input.title,
        body: input.body,
        personId: input.personId ?? '',
        photoIds: input.photoIds ?? [],
      },
    });
    return normalizeStoryPhotos(story);
  },

  async updateStory(
    storyId: string,
    input: { title: string; body: string; personId?: string; photoIds?: string[] },
  ) {
    const story = await request<Story>({
      url: `/stories/${encodeURIComponent(storyId)}`,
      method: 'patch',
      data: {
        title: input.title,
        body: input.body,
        personId: input.personId ?? '',
        photoIds: input.photoIds ?? [],
      },
    });
    return normalizeStoryPhotos(story);
  },

  deleteStory(storyId: string) {
    return request<Record<string, never>>({
      url: `/stories/${encodeURIComponent(storyId)}`,
      method: 'delete',
    });
  },

  listNotifications() {
    return request<NotificationPage>({ url: '/notifications', method: 'get' });
  },

  unreadNotificationCount() {
    return request<{ count: number }>({
      url: '/notifications/unread-count',
      method: 'get',
      skipErrorToast: true,
    });
  },

  markNotificationsRead(input: { id?: number; all?: boolean }) {
    return request<Record<string, never>>({
      url: '/notifications/read',
      method: 'post',
      data: { id: input.id ?? 0, all: input.all ?? false },
    });
  },

  listEditRequests(params: { status?: EditRequestStatus; mine?: boolean; limit?: number } = {}) {
    return request<EditRequestPage>({
      url: '/edit-requests',
      method: 'get',
      params: {
        ...(params.status ? { status: params.status } : {}),
        ...(params.mine ? { mine: true } : {}),
        limit: params.limit ?? 50,
      },
    });
  },

  getEditRequest(requestId: string) {
    return request<EditRequest>({
      url: `/edit-requests/${encodeURIComponent(requestId)}`,
      method: 'get',
    });
  },

  createEditRequest(input: {
    targetPersonId: string;
    baseVersion: number;
    changes: PersonEditChanges;
  }) {
    return request<EditRequest>({
      url: '/edit-requests',
      method: 'post',
      data: input,
    });
  },

  reviewEditRequest(requestId: string, approve: boolean, note = '') {
    return request<EditRequest>({
      url: `/edit-requests/${encodeURIComponent(requestId)}/${approve ? 'approve' : 'reject'}`,
      method: 'post',
      data: { note },
      skipErrorToast: false,
    });
  },
};

/**
 * 故事接口内嵌的 Photo 没有 contentPath（相册接口才有）。
 * 在 API 层补齐统一路径，避免页面层到处拼 URL。
 */
function normalizeStoryPhotos(story: Story): Story {
  if (!story.photos?.length) return story;
  return {
    ...story,
    photos: story.photos.map((photo) => ({
      ...photo,
      contentPath: photo.contentPath || `/api/v1/photos/${photo.id}/content`,
    })),
  };
}
