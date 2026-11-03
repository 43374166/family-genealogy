import { lazy, Suspense, useEffect } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { Toast } from '@douyinfe/semi-ui';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { initializeAuth, sessionExpired } from '@/store/authSlice';
import { resetNotifications } from '@/store/notificationSlice';
import { setStoredTheme } from '@/utils/storage';
import { AUTH_EXPIRED_EVENT } from '@/utils/request';
import { AppShell } from '@/layouts/AppShell';
import { GuestOnly, RequireAuth, RequireReviewer } from '@/routes/guards';
import { LoadingScreen } from '@/components/LoadingScreen';
import { ErrorBoundary } from '@/components/ErrorBoundary';

const LoginPage = lazy(() => import('@/pages/auth/LoginPage'));
const RegisterPage = lazy(() => import('@/pages/auth/RegisterPage'));
const HomePage = lazy(() => import('@/pages/home/HomePage'));
const TreePage = lazy(() => import('@/pages/tree/TreePage'));
const MembersPage = lazy(() => import('@/pages/members/MembersPage'));
const PersonDetailPage = lazy(() => import('@/pages/person/PersonDetailPage'));
const GalleryPage = lazy(() => import('@/pages/gallery/GalleryPage'));
const StoriesPage = lazy(() => import('@/pages/stories/StoriesPage'));
const StoryDetailPage = lazy(() => import('@/pages/stories/StoryDetailPage'));
const MessagesPage = lazy(() => import('@/pages/messages/MessagesPage'));
const RequestsPage = lazy(() => import('@/pages/requests/RequestsPage'));
const ProfilePage = lazy(() => import('@/pages/profile/ProfilePage'));
const FamilyPage = lazy(() => import('@/pages/family/FamilyPage'));
const NotFoundPage = lazy(() => import('@/pages/NotFoundPage'));

function ThemeSync() {
  const themeMode = useAppSelector((state) => state.ui.themeMode);

  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)');

    const apply = () => {
      const resolved =
        themeMode === 'system' ? (media.matches ? 'dark' : 'light') : themeMode;
      document.body.setAttribute('theme-mode', resolved);
      document.documentElement.style.colorScheme = resolved;
      document
        .querySelector('meta[name="theme-color"]')
        ?.setAttribute('content', resolved === 'dark' ? '#101716' : '#f4f7f8');
      setStoredTheme(themeMode);
    };

    apply();
    if (themeMode !== 'system') return;
    media.addEventListener('change', apply);
    return () => media.removeEventListener('change', apply);
  }, [themeMode]);

  return null;
}

function SessionBootstrap() {
  const dispatch = useAppDispatch();

  useEffect(() => {
    dispatch(initializeAuth());

    const handleExpired = () => {
      dispatch(sessionExpired());
      dispatch(resetNotifications());
      Toast.warning({
        content: '登录状态已过期，请重新登录',
        duration: 3,
        id: 'session-expired',
      });
    };

    window.addEventListener(AUTH_EXPIRED_EVENT, handleExpired);
    return () => window.removeEventListener(AUTH_EXPIRED_EVENT, handleExpired);
  }, [dispatch]);

  return null;
}

function ScrollToTop() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}

export default function App() {
  return (
    <ErrorBoundary>
      <ThemeSync />
      <SessionBootstrap />
      <ScrollToTop />
      <Suspense fallback={<LoadingScreen label="正在翻到下一页…" />}>
        <Routes>
          <Route
            path="/login"
            element={
              <GuestOnly>
                <LoginPage />
              </GuestOnly>
            }
          />
          <Route
            path="/register"
            element={
              <GuestOnly>
                <RegisterPage />
              </GuestOnly>
            }
          />
          <Route
            path="/"
            element={
              <RequireAuth>
                <AppShell />
              </RequireAuth>
            }
          >
            <Route index element={<HomePage />} />
            <Route path="tree" element={<TreePage />} />
            <Route path="members" element={<MembersPage />} />
            <Route path="persons/:personId" element={<PersonDetailPage />} />
            <Route path="gallery" element={<GalleryPage />} />
            <Route path="stories" element={<StoriesPage />} />
            <Route path="stories/:storyId" element={<StoryDetailPage />} />
            <Route path="messages" element={<MessagesPage />} />
            <Route path="requests" element={<RequestsPage />} />
            <Route path="profile" element={<ProfilePage />} />
            <Route
              path="family"
              element={
                <RequireReviewer>
                  <FamilyPage />
                </RequireReviewer>
              }
            />
            <Route path="404" element={<NotFoundPage />} />
            <Route path="*" element={<NotFoundPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </ErrorBoundary>
  );
}
