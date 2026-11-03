import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Button, Checkbox, Input, Toast } from '@douyinfe/semi-ui';
import {
  IconAt,
  IconHome,
  IconLock,
  IconUser,
  IconUserGroup,
} from '@douyinfe/semi-icons';
import { authApi } from '@/api/auth';
import { useAppDispatch } from '@/store/hooks';
import { login } from '@/store/authSlice';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { toErrorMessage } from '@/utils/error';
import { AuthLayout } from './AuthLayout';
import './Auth.scss';

interface RegisterForm {
  loginName: string;
  displayName: string;
  password: string;
  confirmPassword: string;
  inviteCode: string;
  familyName: string;
  surname: string;
}

const initialForm: RegisterForm = {
  loginName: '',
  displayName: '',
  password: '',
  confirmPassword: '',
  inviteCode: '',
  familyName: '',
  surname: '',
};

export default function RegisterPage() {
  useDocumentTitle('注册');
  const dispatch = useAppDispatch();
  const navigate = useNavigate();
  const [form, setForm] = useState<RegisterForm>(initialForm);
  const [accepted, setAccepted] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const update = (key: keyof RegisterForm, value: string | boolean) => {
    setForm((current) => ({ ...current, [key]: value }));
    setError(null);
  };

  const handleSubmit = async (event?: React.FormEvent) => {
    event?.preventDefault();
    setError(null);

    if (!form.loginName.trim()) return setError('请填写登录名');
    if (!form.displayName.trim()) return setError('请填写你的称呼');
    if (form.password.length < 8) return setError('密码至少需要 8 位');
    if (form.password !== form.confirmPassword) return setError('两次输入的密码不一致');
    if (!accepted) return setError('请先阅读并同意用户协议与隐私政策');

    setSubmitting(true);
    try {
      await authApi.register({
        loginName: form.loginName.trim(),
        displayName: form.displayName.trim(),
        password: form.password,
        inviteCode: form.inviteCode.trim(),
        familyName: form.familyName.trim(),
        surname: form.surname.trim(),
        acceptTerms: true,
      });
      Toast.success({ content: '账号创建成功，正在进入家族空间', duration: 2.2 });
      await dispatch(
        login({ loginName: form.loginName.trim(), password: form.password }),
      ).unwrap();
      navigate('/', { replace: true });
    } catch (registerError) {
      setError(toErrorMessage(registerError, '注册失败，请稍后重试'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthLayout
      eyebrow="新的开始"
      title="建立你的家族空间"
      description="可以凭邀请码加入已有家族，也可以先创建一个属于自己的家族。"
    >
      <form className="auth-form auth-form--register" onSubmit={handleSubmit}>
        <div className="auth-form__row">
          <label className="auth-field">
            <span>登录名</span>
            <Input
              size="large"
              prefix={<IconAt />}
              placeholder="用于登录，建议拼音"
              value={form.loginName}
              onChange={(value) => update('loginName', value)}
              autoComplete="username"
            />
          </label>
          <label className="auth-field">
            <span>你的称呼</span>
            <Input
              size="large"
              prefix={<IconUser />}
              placeholder="例如：张三"
              value={form.displayName}
              onChange={(value) => update('displayName', value)}
              autoComplete="name"
            />
          </label>
        </div>

        <div className="auth-form__row">
          <label className="auth-field">
            <span>密码</span>
            <Input
              size="large"
              mode="password"
              prefix={<IconLock />}
              placeholder="至少 8 位"
              value={form.password}
              onChange={(value) => update('password', value)}
              autoComplete="new-password"
            />
          </label>
          <label className="auth-field">
            <span>确认密码</span>
            <Input
              size="large"
              mode="password"
              prefix={<IconLock />}
              placeholder="再输入一次"
              value={form.confirmPassword}
              onChange={(value) => update('confirmPassword', value)}
              autoComplete="new-password"
            />
          </label>
        </div>

        <label className="auth-field">
          <span>邀请码 <em>选填</em></span>
          <Input
            size="large"
            prefix={<IconUserGroup />}
            placeholder="有邀请码时加入已有家族"
            value={form.inviteCode}
            onChange={(value) => update('inviteCode', value)}
          />
        </label>

        {!form.inviteCode.trim() ? (
          <div className="auth-form__row auth-form__family">
            <label className="auth-field">
              <span>家族名称 <em>选填</em></span>
              <Input
                size="large"
                prefix={<IconHome />}
                placeholder="例如：青溪张氏"
                value={form.familyName}
                onChange={(value) => update('familyName', value)}
              />
            </label>
            <label className="auth-field">
              <span>家族姓氏 <em>选填</em></span>
              <Input
                size="large"
                placeholder="例如：张"
                value={form.surname}
                onChange={(value) => update('surname', value)}
                maxLength={20}
              />
            </label>
          </div>
        ) : null}

        <div className="auth-terms">
          <Checkbox checked={accepted} onChange={(event) => setAccepted(Boolean(event.target.checked))}>
            我已阅读并同意《用户协议》与《隐私政策》，并承诺填写的家族资料真实、合法。
          </Checkbox>
        </div>

        {error ? (
          <div className="auth-error" role="alert">
            {error}
          </div>
        ) : null}

        <Button
          htmlType="submit"
          theme="solid"
          type="primary"
          size="large"
          loading={submitting}
          className="auth-submit"
        >
          {submitting ? '正在建立家族空间…' : '创建账号并继续'}
        </Button>
      </form>

      <div className="auth-switch">
        已经有账号？
        <Link to="/login">返回登录</Link>
      </div>
    </AuthLayout>
  );
}
