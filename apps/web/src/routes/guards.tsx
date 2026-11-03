import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAppSelector } from '@/store/hooks';
import { LoadingScreen } from '@/components/LoadingScreen';

export function RequireAuth({ children }: { children: ReactNode }) {
  const auth = useAppSelector((state) => state.auth);
  const location = useLocation();

  if (!auth.initialized) return <LoadingScreen label="正在核对家族身份…" />;
  if (!auth.user) {
    return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />;
  }
  return <>{children}</>;
}

export function GuestOnly({ children }: { children: ReactNode }) {
  const auth = useAppSelector((state) => state.auth);
  const location = useLocation();
  const from = (location.state as { from?: string } | null)?.from || '/';

  if (!auth.initialized) return <LoadingScreen label="正在打开家族大门…" />;
  if (auth.user) return <Navigate to={from} replace />;
  return <>{children}</>;
}

export function RequireReviewer({ children }: { children: ReactNode }) {
  const role = useAppSelector((state) => state.auth.membership?.role);
  if (role !== 'owner' && role !== 'admin') return <Navigate to="/" replace />;
  return <>{children}</>;
}
