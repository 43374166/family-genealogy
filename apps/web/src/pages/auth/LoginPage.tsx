import { useEffect, useState } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { Button, Input } from '@douyinfe/semi-ui';
import { IconLock, IconUser } from '@douyinfe/semi-icons';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { clearAuthError, login } from '@/store/authSlice';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { AuthLayout } from './AuthLayout';
import { QrLoginPanel } from './QrLoginPanel';
import './Auth.scss';

export default function LoginPage() {
  useDocumentTitle('登录');
  const dispatch = useAppDispatch();
  const navigate = useNavigate();
  const location = useLocation();
  const auth = useAppSelector((state) => state.auth);
  const [loginName, setLoginName] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [localError, setLocalError] = useState<string | null>(null);
  const [mode, setMode] = useState<'password' | 'qrcode'>('password');

  const from = (location.state as { from?: string } | null)?.from || '/';
  const loading = submitting || auth.status === 'loading';

  useEffect(() => {
    return () => {
      dispatch(clearAuthError());
    };
  }, [dispatch]);

  useEffect(() => {
    if (auth.user) navigate(from, { replace: true });
  }, [auth.user, from, navigate]);

  const handleSubmit = async (event?: React.FormEvent) => {
    event?.preventDefault();
    setLocalError(null);
    if (!loginName.trim()) {
      setLocalError('请输入登录名');
      return;
    }
    if (password.length < 8) {
      setLocalError('密码至少 8 位');
      return;
    }

    setSubmitting(true);
    try {
      await dispatch(login({ loginName: loginName.trim(), password })).unwrap();
      navigate(from, { replace: true });
    } catch (error) {
      setLocalError(typeof error === 'string' ? error : '登录失败，请稍后重试');
    } finally {
      setSubmitting(false);
    }
  };

  const fillDemo = () => {
    setLoginName('linglei');
    setPassword('Demo#2026');
    setLocalError(null);
  };

  return (
    <AuthLayout
      eyebrow="欢迎回家"
      title="续写家族故事"
      description="登录你的家族空间，查看族谱、成员与共同珍藏的家族记忆。"
    >
      <div className="auth-method-tabs" role="tablist" aria-label="登录方式">
        <button
          type="button"
          role="tab"
          aria-selected={mode === 'password'}
          className={mode === 'password' ? 'is-active' : ''}
          onClick={() => {
            setMode('password');
            dispatch(clearAuthError());
            setLocalError(null);
          }}
        >
          账号密码
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={mode === 'qrcode'}
          className={mode === 'qrcode' ? 'is-active' : ''}
          onClick={() => {
            setMode('qrcode');
            setLocalError(null);
          }}
        >
          扫码登录
          <span>手机确认</span>
        </button>
      </div>

      {mode === 'qrcode' ? (
        <QrLoginPanel onSuccess={() => navigate(from, { replace: true })} />
      ) : (
      <form className="auth-form" onSubmit={handleSubmit}>
        <label className="auth-field">
          <span>登录名</span>
          <Input
            size="large"
            prefix={<IconUser />}
            placeholder="输入登录名"
            value={loginName}
            onChange={setLoginName}
            autoComplete="username"
            aria-label="登录名"
          />
        </label>

        <label className="auth-field">
          <span>密码</span>
          <Input
            size="large"
            mode="password"
            prefix={<IconLock />}
            placeholder="输入密码（至少 8 位）"
            value={password}
            onChange={setPassword}
            autoComplete="current-password"
            onEnterPress={() => handleSubmit()}
            aria-label="密码"
          />
        </label>

        {localError || auth.error ? (
          <div className="auth-error" role="alert">
            {localError || auth.error}
          </div>
        ) : null}

        <Button
          htmlType="submit"
          theme="solid"
          type="primary"
          size="large"
          loading={loading}
          className="auth-submit"
        >
          {loading ? '正在核验身份…' : '进入家族空间'}
        </Button>

        {import.meta.env.DEV ? (
          <button type="button" className="auth-demo" onClick={fillDemo}>
            <span>本地演示账号</span>
            <code>linglei / Demo#2026</code>
            <em>一键填入</em>
          </button>
        ) : null}
      </form>
      )}

      <div className="auth-switch">
        还没有账号？
        <Link to="/register">创建或加入家族</Link>
      </div>

      <p className="auth-security">
        <span>◇</span>
        {mode === 'qrcode'
          ? '扫码后仍需在手机 App 中确认；请求 IP 与归属城市会显示在两端供核对。'
          : '会话凭证保存在本地浏览器，离开公共设备时请及时退出登录。'}
      </p>
    </AuthLayout>
  );
}
