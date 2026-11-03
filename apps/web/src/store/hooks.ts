import { useDispatch, useSelector, type TypedUseSelectorHook } from 'react-redux';
import type { AppDispatch, RootState } from './index';

export const useAppDispatch = () => useDispatch<AppDispatch>();
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;

export const useAuth = () => useAppSelector((state) => state.auth);
export const useIsReviewer = () => {
  const role = useAppSelector((state) => state.auth.membership?.role);
  return role === 'owner' || role === 'admin';
};
