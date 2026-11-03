import { useMemo, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { Avatar, Button, Input, Modal, Toast } from '@douyinfe/semi-ui';
import {
  IconArrowRight,
  IconBranch,
  IconEdit,
  IconExit,
  IconGallery,
  IconHome,
  IconLock,
  IconMail,
  IconPhone,
  IconSetting,
  IconUser,
  IconUserGroup,
} from '@douyinfe/semi-icons';
import { useAppDispatch, useAppSelector, useIsReviewer } from '@/store/hooks';
import { logoutSession, switchFamily } from '@/store/authSlice';
import { authApi } from '@/api/auth';
import { contentApi } from '@/api/content';
import { personsApi } from '@/api/persons';
import { useAsync } from '@/hooks/useAsync';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { PageHeader } from '@/components/PageHeader';
import { PersonAvatar } from '@/components/PersonAvatar';
import { SectionCard } from '@/components/SectionCard';
import { RequestStatusPill, RolePill } from '@/components/StatusPill';
import { EmptyState } from '@/components/EmptyState';
import { formatDate, generationShort, maskPhone, roleLabel } from '@/utils/format';
import { toErrorMessage } from '@/utils/error';
import './ProfilePage.scss';

export default function ProfilePage() {
  useDocumentTitle('我的');
  const dispatch = useAppDispatch();
  const navigate = useNavigate();
  const auth = useAppSelector((state) => state.auth);
  const isReviewer = useIsReviewer();
  const [passwordOpen, setPasswordOpen] = useState(false);
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordSaving, setPasswordSaving] = useState(false);
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [switchingFamilyId, setSwitchingFamilyId] = useState<string | null>(null);

  const personQuery = useAsync(
    () =>
      auth.membership?.personId
        ? personsApi.getPerson(auth.membership.personId)
        : Promise.resolve(null),
    [auth.membership?.personId, auth.family?.id],
    { enabled: Boolean(auth.family?.id) },
  );

  const requestsQuery = useAsync(
    async () => (await contentApi.listEditRequests({ mine: true, limit: 100 })).items,
    [auth.family?.id, auth.user?.id],
    { enabled: Boolean(auth.family?.id) },
  );

  const myRequests = requestsQuery.data ?? [];
  const pendingCount = myRequests.filter((request) => request.status === 'pending').length;

  const joinedYears = useMemo(() => {
    if (!auth.membership?.joinedAt) return '—';
    const start = new Date(auth.membership.joinedAt).getTime();
    if (Number.isNaN(start)) return '—';
    const years = Math.max(1, Math.ceil((Date.now() - start) / (365.25 * 24 * 3600 * 1000)));
    return `${years} 年`;
  }, [auth.membership?.joinedAt]);

  const person = personQuery.data;

  const handleSwitchFamily = async (familyId: string) => {
    if (familyId === auth.family?.id) return;
    setSwitchingFamilyId(familyId);
    try {
      await dispatch(switchFamily(familyId)).unwrap();
      Toast.success({ content: '已切换家族空间', duration: 2.2 });
      navigate('/');
    } catch (error) {
      Toast.error({ content: typeof error === 'string' ? error : '切换家族失败' });
    } finally {
      setSwitchingFamilyId(null);
    }
  };

  const handleChangePassword = async () => {
    if (newPassword.length < 8) {
      setPasswordError('新密码至少需要 8 位');
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordError('两次输入的新密码不一致');
      return;
    }
    if (newPassword === currentPassword) {
      setPasswordError('新密码不能与当前密码相同');
      return;
    }
    setPasswordSaving(true);
    setPasswordError(null);
    try {
      await authApi.changePassword(currentPassword, newPassword);
      Toast.success({ content: '密码已更新，下次登录请使用新密码', duration: 2.6 });
      setPasswordOpen(false);
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
    } catch (error) {
      setPasswordError(toErrorMessage(error, '修改密码失败'));
    } finally {
      setPasswordSaving(false);
    }
  };

  return (
    <div className="app-page profile-page">
      <PageHeader
        eyebrow="MY ACCOUNT"
        title="我的"
        description={`${auth.family?.name ?? '家族空间'} · ${roleLabel(auth.membership?.role)}`}
        actions={
          <Button
            theme="borderless"
            icon={<IconExit />}
            onClick={async () => {
              await dispatch(logoutSession());
              navigate('/login', { replace: true });
            }}
          >
            退出登录
          </Button>
        }
      />

      <section className="profile-hero">
        <div className="profile-hero__wash" aria-hidden />
        <div className="profile-hero__person">
          {person ? (
            <PersonAvatar person={person} size={88} ring eager />
          ) : (
            <Avatar size="large" className="profile-hero__avatar">
              {auth.user?.displayName?.slice(-1) ?? '族'}
            </Avatar>
          )}
          <div className="profile-hero__identity">
            <div className="profile-hero__name-row">
              <h1>{auth.user?.displayName ?? '家族成员'}</h1>
              <RolePill role={auth.membership?.role} />
            </div>
            <p className="profile-hero__account">@{auth.user?.loginName ?? 'member'}</p>
            <div className="profile-hero__tags">
              <span>{auth.family?.name}</span>
              {person ? (
                <span>
                  {generationShort(person.generationNo)} · {person.generationName || '字辈未录'}
                </span>
              ) : (
                <span>尚未绑定人物档案</span>
              )}
              <span>加入 {formatDate(auth.membership?.joinedAt, 'YYYY 年 M 月')}</span>
            </div>
          </div>
        </div>

        <div className="profile-hero__actions">
          {person ? (
            <Button theme="light" onClick={() => navigate(`/persons/${person.id}`)}>
              查看我的档案
            </Button>
          ) : (
            <Button theme="light" onClick={() => navigate('/members')}>
              浏览家族成员
            </Button>
          )}
          <Button theme="light" type="primary" icon={<IconLock />} onClick={() => setPasswordOpen(true)}>
            账号安全
          </Button>
        </div>

        <div className="profile-hero__stats">
          <div>
            <strong>{myRequests.length}</strong>
            <span>我的申请</span>
          </div>
          <div>
            <strong>{pendingCount}</strong>
            <span>待审核</span>
          </div>
          <div>
            <strong>{joinedYears}</strong>
            <span>加入家族</span>
          </div>
        </div>
      </section>

      <div className="profile-layout">
        <div className="profile-layout__main">
          <SectionCard eyebrow="SERVICES" title="我的家族服务">
            <div className="profile-services">
              <ServiceItem
                icon={<IconUser />}
                tone="blue"
                title="人物档案"
                description={person ? `${person.fullName} · ${generationShort(person.generationNo)}` : '尚未绑定人物'}
                onClick={() => navigate(person ? `/persons/${person.id}` : '/members')}
              />
              <ServiceItem
                icon={<IconEdit />}
                tone="gold"
                title={isReviewer ? '审核中心' : '我的申请'}
                description={pendingCount ? `${pendingCount} 条待审核` : '查看资料审核进度'}
                onClick={() => navigate('/requests')}
              />
              <ServiceItem
                icon={<IconGallery />}
                tone="teal"
                title="家族相册"
                description="浏览家族共同影像"
                onClick={() => navigate('/gallery')}
              />
              <ServiceItem
                icon={<IconHome />}
                tone="jade"
                title="家族资料"
                description={`${auth.family?.memberCount ?? 0} 位成员 · ${auth.family?.branchCount ?? 0} 个家支`}
                onClick={() => (isReviewer ? navigate('/family') : navigate('/'))}
              />
            </div>
          </SectionCard>

          <SectionCard eyebrow="MY REQUESTS" title="最近申请">
            {requestsQuery.loading ? (
              <p className="profile-quiet">正在整理申请记录…</p>
            ) : myRequests.length ? (
              <div className="profile-request-list">
                {myRequests.slice(0, 4).map((request) => (
                  <button type="button" key={request.id} onClick={() => navigate('/requests')}>
                    <span className="profile-request-list__type">
                      {request.summary || request.targetName || '家族资料申请'}
                    </span>
                    <RequestStatusPill status={request.status} />
                    <small>{formatDate(request.submittedAt, 'MM.DD HH:mm')}</small>
                    <IconArrowRight size="small" />
                  </button>
                ))}
                {myRequests.length > 4 ? (
                  <button type="button" className="profile-request-list__more" onClick={() => navigate('/requests')}>
                    查看全部 {myRequests.length} 条申请 <IconArrowRight size="small" />
                  </button>
                ) : null}
              </div>
            ) : (
              <EmptyState
                compact
                title="还没有提交过资料申请"
                description="需要补充或修改人物资料时，可以在人物档案中提交。"
                actionText="查看我的档案"
                onAction={() => navigate(person ? `/persons/${person.id}` : '/members')}
              />
            )}
          </SectionCard>

          <SectionCard eyebrow="FAMILY SPACE" title="家族空间">
            <div className="profile-family-card">
              <span className="profile-family-card__seal">{auth.family?.surname?.[0] ?? '族'}</span>
              <div className="profile-family-card__body">
                <h3>{auth.family?.name}</h3>
                <p>{auth.family?.motto || '寻根溯源 · 传承家风'}</p>
                <div className="profile-family-card__meta">
                  <span>
                    <IconUserGroup size="small" /> {auth.family?.memberCount ?? 0} 位成员
                  </span>
                  <span>
                    <IconBranch size="small" /> {auth.family?.branchCount ?? 0} 个家支
                  </span>
                  <span>
                    <IconHome size="small" /> {auth.family?.region || '地区未录'}
                  </span>
                </div>
              </div>
              {isReviewer ? (
                <Button theme="borderless" icon={<IconSetting />} onClick={() => navigate('/family')}>
                  管理家族
                </Button>
              ) : null}
            </div>
            {auth.family?.description ? (
              <p className="profile-family-description">{auth.family.description}</p>
            ) : null}

            {(auth.families?.length ?? 0) > 1 ? (
              <div className="profile-family-switch">
                <p>切换家族空间</p>
                <div className="profile-family-switch__list">
                  {auth.families.map((entry) => (
                    <button
                      key={entry.family.id}
                      type="button"
                      className={entry.family.id === auth.family?.id ? 'is-active' : ''}
                      disabled={switchingFamilyId !== null}
                      onClick={() => handleSwitchFamily(entry.family.id)}
                    >
                      <span className="profile-family-switch__seal">{entry.family.surname?.[0] ?? '族'}</span>
                      <span>
                        <strong>{entry.family.name}</strong>
                        <small>{roleLabel(entry.membership.role)} · {entry.family.memberCount} 人</small>
                      </span>
                      {entry.family.id === auth.family?.id ? <em>当前</em> : <IconArrowRight size="small" />}
                    </button>
                  ))}
                </div>
              </div>
            ) : null}
          </SectionCard>
        </div>

        <aside className="profile-layout__side">
          <SectionCard eyebrow="ACCOUNT" title="账号信息">
            <div className="profile-account-list">
              <div>
                <span>
                  <IconUser /> 登录名
                </span>
                <strong>{auth.user?.loginName}</strong>
              </div>
              <div>
                <span>
                  <IconMail /> 展示名
                </span>
                <strong>{auth.user?.displayName}</strong>
              </div>
              <div>
                <span>
                  <IconPhone /> 手机号
                </span>
                <strong>{auth.user?.phone ? maskPhone(auth.user.phone) : '未绑定'}</strong>
              </div>
              <div>
                <span>
                  <IconUserGroup /> 家族身份
                </span>
                <strong>{roleLabel(auth.membership?.role)}</strong>
              </div>
            </div>
            <Button
              theme="light"
              block
              icon={<IconLock />}
              onClick={() => setPasswordOpen(true)}
            >
              修改登录密码
            </Button>
          </SectionCard>

          <SectionCard eyebrow="SECURITY" title="账号与安全">
            <div className="profile-security-list">
              <div>
                <span className="profile-security-list__icon">
                  <IconLock />
                </span>
                <span>
                  <strong>登录密码</strong>
                  <small>建议定期更换，至少 8 位</small>
                </span>
                <button type="button" onClick={() => setPasswordOpen(true)}>
                  修改
                </button>
              </div>
              <div>
                <span className="profile-security-list__icon profile-security-list__icon--jade">
                  <IconPhone />
                </span>
                <span>
                  <strong>手机绑定</strong>
                  <small>{auth.user?.phone ? maskPhone(auth.user.phone) : '尚未绑定手机号'}</small>
                </span>
                <em>{auth.user?.phone ? '已绑定' : '未绑定'}</em>
              </div>
              <div>
                <span className="profile-security-list__icon profile-security-list__icon--gold">
                  <IconHome />
                </span>
                <span>
                  <strong>当前家族</strong>
                  <small>{auth.family?.name}</small>
                </span>
                <em>安全</em>
              </div>
            </div>
            <p className="profile-security-note">
              会话令牌保存在本地浏览器。在公共设备上使用后，请及时退出登录。
            </p>
          </SectionCard>

          <div className="profile-side-quote">
            <span>家 训</span>
            <p>{auth.family?.motto || '忠厚传家，诗书继世。'}</p>
            <small>{auth.family?.region}</small>
          </div>
        </aside>
      </div>

      <Modal
        visible={passwordOpen}
        title="修改登录密码"
        onCancel={() => setPasswordOpen(false)}
        footer={
          <div className="profile-password__footer">
            <Button theme="borderless" onClick={() => setPasswordOpen(false)} disabled={passwordSaving}>
              取消
            </Button>
            <Button theme="solid" type="primary" loading={passwordSaving} onClick={handleChangePassword}>
              保存新密码
            </Button>
          </div>
        }
      >
        <div className="profile-password">
          <label>
            <span>当前密码</span>
            <Input mode="password" value={currentPassword} onChange={setCurrentPassword} autoComplete="current-password" />
          </label>
          <label>
            <span>新密码</span>
            <Input mode="password" value={newPassword} onChange={setNewPassword} autoComplete="new-password" placeholder="至少 8 位" />
          </label>
          <label>
            <span>确认新密码</span>
            <Input mode="password" value={confirmPassword} onChange={setConfirmPassword} autoComplete="new-password" />
          </label>
          {passwordError ? <div className="profile-password__error">{passwordError}</div> : null}
        </div>
      </Modal>
    </div>
  );
}

function ServiceItem({
  icon,
  tone,
  title,
  description,
  onClick,
}: {
  icon: ReactNode;
  tone: string;
  title: string;
  description: string;
  onClick: () => void;
}) {
  return (
    <button type="button" className="profile-service" onClick={onClick}>
      <span className={`profile-service__icon profile-service__icon--${tone}`}>{icon}</span>
      <span>
        <strong>{title}</strong>
        <small>{description}</small>
      </span>
      <IconArrowRight size="small" />
    </button>
  );
}
