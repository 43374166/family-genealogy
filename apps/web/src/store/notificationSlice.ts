import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import { contentApi } from '@/api/content';
import type { NotificationItem } from '@/types/api';
import { toErrorMessage } from '@/utils/error';

export interface NotificationState {
  items: NotificationItem[];
  unreadCount: number;
  loading: boolean;
  loaded: boolean;
  error: string | null;
}

const initialState: NotificationState = {
  items: [],
  unreadCount: 0,
  loading: false,
  loaded: false,
  error: null,
};

export const fetchNotifications = createAsyncThunk<
  { items: NotificationItem[]; unreadCount: number },
  void,
  { rejectValue: string }
>('notifications/fetch', async (_, { rejectWithValue }) => {
  try {
    return await contentApi.listNotifications();
  } catch (error) {
    return rejectWithValue(toErrorMessage(error));
  }
});

export const fetchUnreadCount = createAsyncThunk<number, void, { rejectValue: string }>(
  'notifications/unread',
  async (_, { rejectWithValue }) => {
    try {
      const result = await contentApi.unreadNotificationCount();
      return result.count;
    } catch (error) {
      return rejectWithValue(toErrorMessage(error));
    }
  },
);

export const markAllNotificationsRead = createAsyncThunk<void, void, { rejectValue: string }>(
  'notifications/readAll',
  async (_, { rejectWithValue }) => {
    try {
      await contentApi.markNotificationsRead({ all: true });
    } catch (error) {
      return rejectWithValue(toErrorMessage(error));
    }
  },
);

export const markNotificationRead = createAsyncThunk<number, number, { rejectValue: string }>(
  'notifications/readOne',
  async (id, { rejectWithValue }) => {
    try {
      await contentApi.markNotificationsRead({ id });
      return id;
    } catch (error) {
      return rejectWithValue(toErrorMessage(error));
    }
  },
);

const notificationSlice = createSlice({
  name: 'notifications',
  initialState,
  reducers: {
    resetNotifications() {
      return initialState;
    },
  },
  extraReducers(builder) {
    builder
      .addCase(fetchNotifications.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchNotifications.fulfilled, (state, action) => {
        state.loading = false;
        state.loaded = true;
        state.items = action.payload.items ?? [];
        state.unreadCount = action.payload.unreadCount ?? 0;
      })
      .addCase(fetchNotifications.rejected, (state, action) => {
        state.loading = false;
        state.loaded = true;
        state.error = action.payload ?? '加载消息失败';
      })
      .addCase(fetchUnreadCount.fulfilled, (state, action) => {
        state.unreadCount = action.payload;
      })
      .addCase(markAllNotificationsRead.fulfilled, (state) => {
        state.items = state.items.map((item) => ({ ...item, isRead: true }));
        state.unreadCount = 0;
      })
      .addCase(markNotificationRead.fulfilled, (state, action) => {
        const item = state.items.find((entry) => entry.id === action.payload);
        if (item && !item.isRead) {
          item.isRead = true;
          state.unreadCount = Math.max(0, state.unreadCount - 1);
        }
      });
  },
});

export const { resetNotifications } = notificationSlice.actions;
export default notificationSlice.reducer;
