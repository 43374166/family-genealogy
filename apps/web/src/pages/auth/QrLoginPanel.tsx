import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { Button, Spin } from '@douyinfe/semi-ui';
import {
  IconCheckCircleStroked,
  IconClock,
  IconCrossCircleStroked,
  IconMapPin,
  IconRefresh,
  IconShieldStroked,
  IconSmartphoneStroked,
} from '@douyinfe/semi-icons';
import dayjs from 'dayjs';
import { authApi } from '@/api/auth';
import { useAppDispatch } from '@/store/hooks';
import { completeQrLogin } from '@/store/authSlice';
import type { QrLoginCreate, QrLoginStatus } from '@/types/api';
import { isApiError } from '@/utils/request';
import './QrLoginPanel.scss';

interface QrLoginPanelProps {
  onSuccess: () => void;
}

function locationText(status: QrLoginStatus | null, create: QrLoginCreate | null): string {
  const city = status?.requestCity || create?.requestCity || '';
  const region = status?.requestRegion || create?.requestRegion || '';
  if (!city && !region) return 'IP 归属地查询中';
  if (city && region && city !== region && !region.includes(city)) return `${region} · ${city}`;
  return city || region;
}

export function QrLoginPanel({ onSuccess }: QrLoginPanelProps) {
  const dispatch = useAppDispatch();
  const [qr, setQr] = useState<QrLoginCreate | null>(null);
  const [status, setStatus] = useState<QrLoginStatus | null>(null);
  const [phase, setPhase] = useState<'creating' | 'active' | 'success' | 'expired' | 'error'>(
    'creating',
  );
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => Date.now());
  const mountedRef = useRef(true);
  const qrRef = useRef<QrLoginCreate | null>(null);
  const completedRef = useRef(false);
  const onSuccessRef = useRef(onSuccess);
  onSuccessRef.current = onSuccess;

  const createQr = useCallback(async () => {
    const previous = qrRef.current;
    if (previous) {
      void authApi.cancelQrLogin(previous.id, previous.secret).catch(() => undefined);
    }
    completedRef.current = false;
    setPhase('creating');
    setError(null);
    setStatus(null);
    setQr(null);
    qrRef.current = null;
    try {
      const created = await authApi.createQrLogin();
      if (!mountedRef.current) return;
      setQr(created);
      qrRef.current = created;
      setStatus({
        id: created.id,
        status: created.status,
        expiresAt: created.expiresAt,
        requestIp: created.requestIp,
        requestCity: created.requestCity,
        requestRegion: created.requestRegion,
        requestDevice: created.requestDevice,
      });
      setPhase('active');
    } catch (createError) {
      if (!mountedRef.current) return;
      setPhase('error');
      setError(isApiError(createError) ? createError.message : '二维码生成失败，请重试');
    }
  }, []);

  useEffect(() => {
    mountedRef.current = true;
    createQr();
    return () => {
      mountedRef.current = false;
      const current = qrRef.current;
      if (current && !completedRef.current) {
        void authApi.cancelQrLogin(current.id, current.secret).catch(() => undefined);
      }
    };
  }, [createQr]);

  useEffect(() => {
    if (!qr) return;
    let stopped = false;
    let timer = 0;

    const tick = async () => {
      try {
        const next = await authApi.pollQrLogin(qr.id, qr.secret);
        if (stopped || !mountedRef.current) return;
        setStatus(next);
        if (next.status === 'confirmed' && next.session) {
          stopped = true;
          completedRef.current = true;
          setPhase('success');
          try {
            await dispatch(completeQrLogin(next.session.token)).unwrap();
            if (mountedRef.current) onSuccessRef.current();
          } catch (loginError) {
            if (!mountedRef.current) return;
            setPhase('error');
            setError(typeof loginError === 'string' ? loginError : '登录会话创建失败');
          }
          return;
        }
        if (['expired', 'cancelled', 'consumed'].includes(next.status)) {
          stopped = true;
          setPhase('expired');
          setError(next.status === 'cancelled' ? '本次登录已取消' : '二维码已失效，请刷新');
          return;
        }
        timer = window.setTimeout(tick, Math.max(1400, qr.pollIntervalMs || 2000));
      } catch (pollError) {
        if (stopped || !mountedRef.current) return;
        const code = isApiError(pollError) ? pollError.code : '';
        if (code === 'QR_ALREADY_USED' || code === 'QR_EXPIRED' || code === 'QR_NOT_FOUND') {
          stopped = true;
          setPhase('expired');
          setError(isApiError(pollError) ? pollError.message : '二维码已失效');
          return;
        }
        // Transient network failures retry silently until expiry.
        timer = window.setTimeout(tick, 2600);
      }
    };

    timer = window.setTimeout(tick, 1200);
    return () => {
      stopped = true;
      window.clearTimeout(timer);
    };
  }, [dispatch, qr]);

  useEffect(() => {
    if (phase !== 'active') return;
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [phase]);

  const expiresAt = status?.expiresAt || qr?.expiresAt;
  const secondsLeft = expiresAt
    ? Math.max(0, dayjs(expiresAt).diff(dayjs(now), 'second'))
    : 0;
  const scanned = status?.status === 'scanned';
  const location = locationText(status, qr);
  const device = status?.requestDevice || qr?.requestDevice || '';
  const requestIp = status?.requestIp || qr?.requestIp || '';
  const expiredAtZero = phase === 'active' && secondsLeft <= 0;
  const showFailure = phase === 'expired' || expiredAtZero || phase === 'error';
  const countdown = useMemo(() => {
    if (secondsLeft <= 0) return '已过期';
    const minutes = Math.floor(secondsLeft / 60);
    const seconds = secondsLeft % 60;
    return `${minutes}:${String(seconds).padStart(2, '0')}`;
  }, [secondsLeft]);

  return (
    <div className="qr-login">
      {phase === 'creating' ? (
        <div className="qr-login__loading">
          <Spin size="large" />
          <p>正在生成安全二维码…</p>
          <small>会同时获取本次请求的 IP 归属地，供手机端确认。</small>
        </div>
      ) : phase === 'success' ? (
        <div className="qr-login__success">
          <span className="qr-login__success-icon">
            <IconCheckCircleStroked />
          </span>
          <h3>登录已确认</h3>
          <p>正在为你打开家族空间…</p>
        </div>
      ) : showFailure ? (
        <div className="qr-login__failure">
          <span className="qr-login__failure-icon">
            {phase === 'error' ? <IconCrossCircleStroked /> : <IconClock />}
          </span>
          <h3>{phase === 'error' ? '二维码生成失败' : '二维码已失效'}</h3>
          <p>{error || '为保护账号安全，登录二维码只保留 2 分钟。'}</p>
          <Button theme="solid" type="primary" icon={<IconRefresh />} onClick={createQr}>
            刷新二维码
          </Button>
        </div>
      ) : (
        <>
          <div className={`qr-frame ${scanned ? 'is-scanned' : ''}`}>
            {qr ? <QRCodeSVG value={qr.payload} size={188} level="M" marginSize={1} /> : null}
            {scanned ? (
              <span className="qr-frame__scanned">
                <IconCheckCircleStroked />
                已扫码
              </span>
            ) : null}
          </div>

          <div className="qr-login__status">
            {scanned ? (
              <>
                <span className="qr-login__status-icon is-scanned">
                  <IconCheckCircleStroked />
                </span>
                <div>
                  <strong>已扫码，请在手机上确认登录</strong>
                  <p>确认后本页面会自动进入家族空间。</p>
                </div>
              </>
            ) : (
              <>
                <span className="qr-login__status-icon">
                  <IconSmartphoneStroked />
                </span>
                <div>
                  <strong>打开「家族族谱」App 扫一扫</strong>
                  <p>入口：我的 → 扫码登录网页。请勿把二维码转发给他人。</p>
                </div>
              </>
            )}
          </div>

          <div className="qr-login__context">
            <div>
              <span>
                <IconMapPin size="small" /> 本次请求
              </span>
              <strong>{location}</strong>
            </div>
            <div>
              <span>
                <IconShieldStroked size="small" /> 设备 / IP
              </span>
              <strong className="qr-login__address">
                {device ? <span>{device}</span> : null}
                {requestIp ? <em>{requestIp}</em> : null}
                {!device && !requestIp ? <span>正在识别</span> : null}
              </strong>
            </div>
            <div>
              <span>
                <IconClock size="small" /> 有效期
              </span>
              <strong className={secondsLeft <= 20 ? 'is-warning' : ''}>{countdown}</strong>
            </div>
          </div>

          <div className="qr-login__foot">
            <span>
              <span className="qr-login__live-dot" /> 等待手机端确认
            </span>
            <button type="button" onClick={createQr}>
              刷新二维码
            </button>
          </div>
        </>
      )}
    </div>
  );
}
