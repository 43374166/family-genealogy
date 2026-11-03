import { createSlice, type PayloadAction } from '@reduxjs/toolkit';
import { getStoredSidebar, getStoredTheme } from '@/utils/storage';

export type ThemeMode = 'light' | 'dark' | 'system';

export interface UiState {
  themeMode: ThemeMode;
  sidebarCollapsed: boolean;
  mobileNavOpen: boolean;
}

const storedTheme = getStoredTheme();

const initialState: UiState = {
  themeMode:
    storedTheme === 'dark' || storedTheme === 'system' || storedTheme === 'light'
      ? storedTheme
      : 'system',
  sidebarCollapsed: getStoredSidebar(),
  mobileNavOpen: false,
};

const uiSlice = createSlice({
  name: 'ui',
  initialState,
  reducers: {
    setThemeMode(state, action: PayloadAction<ThemeMode>) {
      state.themeMode = action.payload;
    },
    toggleSidebar(state) {
      state.sidebarCollapsed = !state.sidebarCollapsed;
    },
    setSidebarCollapsed(state, action: PayloadAction<boolean>) {
      state.sidebarCollapsed = action.payload;
    },
    setMobileNavOpen(state, action: PayloadAction<boolean>) {
      state.mobileNavOpen = action.payload;
    },
  },
});

export const { setThemeMode, toggleSidebar, setSidebarCollapsed, setMobileNavOpen } =
  uiSlice.actions;
export default uiSlice.reducer;
