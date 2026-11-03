import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import { authApi, type LoginInput } from '@/api/auth';
import type { Family, FamilyMembership, Me, Membership, User } from '@/types/api';
import { clearToken, getToken, setToken } from '@/utils/storage';
import { toErrorMessage } from '@/utils/error';

export interface AuthState {
  token: string | null;
  user: User | null;
  membership: Membership | null;
  family: Family | null;
  families: FamilyMembership[];
  status: 'idle' | 'loading' | 'authenticated' | 'error';
  initialized: boolean;
  error: string | null;
}

const initialState: AuthState = {
  token: getToken(),
  user: null,
  membership: null,
  family: null,
  families: [],
  status: 'idle',
  initialized: false,
  error: null,
};

function applyMe(state: AuthState, me: Me) {
  state.user = me.user;
  state.membership = me.membership;
  state.family = me.family;
  state.families = me.families ?? [];
  state.status = 'authenticated';
  state.error = null;
}

export const initializeAuth = createAsyncThunk<
  { token: string; me: Me } | null,
  void,
  { rejectValue: string }
>('auth/initialize', async (_, { rejectWithValue }) => {
  const token = getToken();
  if (!token) return null;
  try {
    const me = await authApi.me();
    return { token, me };
  } catch (error) {
    clearToken();
    return rejectWithValue(toErrorMessage(error));
  }
});

export const login = createAsyncThunk<
  { token: string; me: Me },
  LoginInput,
  { rejectValue: string }
>('auth/login', async (input, { rejectWithValue }) => {
  try {
    const session = await authApi.login(input);
    setToken(session.token);
    const me = await authApi.me();
    return { token: session.token, me };
  } catch (error) {
    clearToken();
    return rejectWithValue(toErrorMessage(error));
  }
});

export const completeQrLogin = createAsyncThunk<
  { token: string; me: Me },
  string,
  { rejectValue: string }
>('auth/completeQrLogin', async (token, { rejectWithValue }) => {
  setToken(token);
  try {
    const me = await authApi.me();
    return { token, me };
  } catch (error) {
    clearToken();
    return rejectWithValue(toErrorMessage(error));
  }
});

export const refreshMe = createAsyncThunk<Me, void, { rejectValue: string }>(
  'auth/refreshMe',
  async (_, { rejectWithValue }) => {
    try {
      return await authApi.me();
    } catch (error) {
      return rejectWithValue(toErrorMessage(error));
    }
  },
);

export const switchFamily = createAsyncThunk<Me, string, { rejectValue: string }>(
  'auth/switchFamily',
  async (familyId, { rejectWithValue }) => {
    try {
      return await authApi.switchFamily(familyId);
    } catch (error) {
      return rejectWithValue(toErrorMessage(error));
    }
  },
);

export const logoutSession = createAsyncThunk<void, void>('auth/logout', async () => {
  try {
    await authApi.logout();
  } catch {
    // 会话可能已失效；本地退出始终成功。
  } finally {
    clearToken();
  }
});

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    sessionExpired(state) {
      clearToken();
      state.token = null;
      state.user = null;
      state.membership = null;
      state.family = null;
      state.families = [];
      state.status = 'idle';
      state.initialized = true;
      state.error = '登录状态已过期，请重新登录';
    },
    clearAuthError(state) {
      state.error = null;
    },
  },
  extraReducers(builder) {
    builder
      .addCase(initializeAuth.pending, (state) => {
        state.status = 'loading';
        state.error = null;
      })
      .addCase(initializeAuth.fulfilled, (state, action) => {
        state.initialized = true;
        if (!action.payload) {
          state.status = 'idle';
          state.token = null;
          return;
        }
        state.token = action.payload.token;
        applyMe(state, action.payload.me);
      })
      .addCase(initializeAuth.rejected, (state, action) => {
        state.initialized = true;
        state.status = 'idle';
        state.token = null;
        state.user = null;
        state.membership = null;
        state.family = null;
        state.families = [];
        state.error = action.payload ?? '登录状态已失效';
      })
      .addCase(login.pending, (state) => {
        state.status = 'loading';
        state.error = null;
      })
      .addCase(login.fulfilled, (state, action) => {
        state.token = action.payload.token;
        state.initialized = true;
        applyMe(state, action.payload.me);
      })
      .addCase(login.rejected, (state, action) => {
        state.status = 'error';
        state.error = action.payload ?? '登录失败';
      })
      .addCase(completeQrLogin.pending, (state) => {
        state.status = 'loading';
        state.error = null;
      })
      .addCase(completeQrLogin.fulfilled, (state, action) => {
        state.token = action.payload.token;
        state.initialized = true;
        applyMe(state, action.payload.me);
      })
      .addCase(completeQrLogin.rejected, (state, action) => {
        state.status = 'error';
        state.error = action.payload ?? '扫码登录失败';
      })
      .addCase(refreshMe.fulfilled, (state, action) => {
        state.token = getToken();
        applyMe(state, action.payload);
      })
      .addCase(refreshMe.rejected, (state, action) => {
        state.error = action.payload ?? null;
      })
      .addCase(switchFamily.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(switchFamily.fulfilled, (state, action) => {
        applyMe(state, action.payload);
        state.token = getToken();
      })
      .addCase(switchFamily.rejected, (state, action) => {
        state.status = 'authenticated';
        state.error = action.payload ?? '切换家族失败';
      })
      .addCase(logoutSession.fulfilled, (state) => {
        state.token = null;
        state.user = null;
        state.membership = null;
        state.family = null;
        state.families = [];
        state.status = 'idle';
        state.initialized = true;
        state.error = null;
      });
  },
});

export const { sessionExpired, clearAuthError } = authSlice.actions;
export default authSlice.reducer;
