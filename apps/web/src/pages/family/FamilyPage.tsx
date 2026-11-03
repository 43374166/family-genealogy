import { useEffect, useMemo, useState } from 'react';
import { Button, Input, Modal, Tabs, TextArea, Toast } from '@douyinfe/semi-ui';
import { SafeSelect as Select } from '@/components/SafeSelect';
import {
  IconCopy,
  IconDelete,
  IconEdit,
  IconPlus,
  IconRefresh,
  IconMail,
} from '@douyinfe/semi-icons';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { refreshMe } from '@/store/authSlice';
import { useAsync } from '@/hooks/useAsync';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { familyApi } from '@/api/family';
import { personsApi } from '@/api/persons';
import { PageHeader } from '@/components/PageHeader';
import { SectionCard } from '@/components/SectionCard';
import { EmptyState } from '@/components/EmptyState';
import { RolePill } from '@/components/StatusPill';
import type { Branch, Family, FamilyAccount, GenerationName, Invite } from '@/types/api';
import { formatDate, roleLabel } from '@/utils/format';
import { toErrorMessage } from '@/utils/error';
import './FamilyPage.scss';

type FamilyForm = Pick<Family, 'name' | 'surname' | 'motto' | 'region' | 'description'>;

const EMPTY_FAMILY_FORM: FamilyForm = {
  name: '',
  surname: '',
  motto: '',
  region: '',
  description: '',
};

export default function FamilyPage() {
  useDocumentTitle('家族管理');
  const dispatch = useAppDispatch();
  const auth = useAppSelector((state) => state.auth);
  const isOwner = auth.membership?.role === 'owner';
  const [activeTab, setActiveTab] = useState('profile');
  const [familyForm, setFamilyForm] = useState<FamilyForm>(EMPTY_FAMILY_FORM);
  const [savingFamily, setSavingFamily] = useState(false);
  const [familyError, setFamilyError] = useState<string | null>(null);
  const [branchModal, setBranchModal] = useState<{ open: boolean; branch?: Branch | null }>({ open: false });
  const [branchName, setBranchName] = useState('');
  const [branchSort, setBranchSort] = useState('0');
  const [branchSaving, setBranchSaving] = useState(false);
  const [deleteBranch, setDeleteBranch] = useState<Branch | null>(null);
  const [inviteOpen, setInviteOpen] = useState(false);
  const [inviteRole, setInviteRole] = useState<'member' | 'admin'>('member');
  const [inviteBranch, setInviteBranch] = useState('');
  const [inviteUses, setInviteUses] = useState(1);
  const [inviteDays, setInviteDays] = useState(7);
  const [inviteSaving, setInviteSaving] = useState(false);
  const [inviteError, setInviteError] = useState<string | null>(null);
  const [roleUpdatingId, setRoleUpdatingId] = useState<string | null>(null);
  const [generationRows, setGenerationRows] = useState<GenerationName[]>([]);
  const [generationPoem, setGenerationPoem] = useState('');
  const [generationSaving, setGenerationSaving] = useState(false);

  useEffect(() => {
    if (!auth.family) return;
    setFamilyForm({
      name: auth.family.name,
      surname: auth.family.surname,
      motto: auth.family.motto ?? '',
      region: auth.family.region ?? '',
      description: auth.family.description ?? '',
    });
  }, [auth.family]);

  const treeQuery = useAsync(
    async () => (await personsApi.getTree()).persons,
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) },
  );
  const branchesQuery = useAsync(
    async () => (await familyApi.listBranches()).items,
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) },
  );
  const accountsQuery = useAsync(
    async () => (await familyApi.listAccounts()).items,
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) && isOwner },
  );
  const invitesQuery = useAsync(
    async () => (await familyApi.listInvites()).items,
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) && isOwner },
  );
  const generationQuery = useAsync(
    async () => await familyApi.getGenerationNames(),
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) },
  );

  useEffect(() => {
    if (!generationQuery.data) return;
    setGenerationRows(generationQuery.data.items ?? []);
    setGenerationPoem(generationQuery.data.poem ?? '');
  }, [generationQuery.data]);

  const branchCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const person of treeQuery.data ?? []) {
      if (person.branchId) counts.set(person.branchId, (counts.get(person.branchId) ?? 0) + 1);
    }
    return counts;
  }, [treeQuery.data]);

  const updateFamilyField = <K extends keyof FamilyForm>(key: K, value: FamilyForm[K]) => {
    setFamilyForm((current) => ({ ...current, [key]: value }));
    setFamilyError(null);
  };

  const handleSaveFamily = async () => {
    if (!familyForm.name.trim() || !familyForm.surname.trim()) {
      setFamilyError('家族名称和姓氏不能为空');
      return;
    }
    setSavingFamily(true);
    setFamilyError(null);
    try {
      await familyApi.updateFamily({
        name: familyForm.name.trim(),
        surname: familyForm.surname.trim(),
        motto: familyForm.motto.trim(),
        region: familyForm.region.trim(),
        description: familyForm.description.trim(),
      });
      await dispatch(refreshMe()).unwrap();
      Toast.success({ content: '家族资料已更新', duration: 2.3 });
    } catch (error) {
      setFamilyError(toErrorMessage(error, '保存失败，请稍后重试'));
    } finally {
      setSavingFamily(false);
    }
  };

  const openBranchModal = (branch?: Branch) => {
    setBranchModal({ open: true, branch });
    setBranchName(branch?.name ?? '');
    setBranchSort(String(branch?.sortOrder ?? 0));
  };

  const handleSaveBranch = async () => {
    if (!branchName.trim()) return;
    setBranchSaving(true);
    try {
      if (branchModal.branch) {
        await familyApi.updateBranch(branchModal.branch.id, {
          name: branchName.trim(),
          sortOrder: Number(branchSort) || 0,
        });
        Toast.success({ content: '家支信息已更新', duration: 2 });
      } else {
        await familyApi.createBranch(branchName.trim());
        Toast.success({ content: '家支已创建', duration: 2 });
      }
      setBranchModal({ open: false });
      branchesQuery.refresh();
      treeQuery.refresh();
    } finally {
      setBranchSaving(false);
    }
  };

  const handleDeleteBranch = async () => {
    if (!deleteBranch) return;
    try {
      await familyApi.deleteBranch(deleteBranch.id);
      Toast.success({ content: '家支已删除', duration: 2 });
      setDeleteBranch(null);
      branchesQuery.refresh();
      treeQuery.refresh();
    } finally {
      setDeleteBranch(null);
    }
  };

  const handleCopy = async (value: string) => {
    try {
      await navigator.clipboard.writeText(value);
      Toast.success({ content: '已复制到剪贴板', duration: 1.8 });
    } catch {
      Toast.error({ content: '复制失败，请手动选择' });
    }
  };

  const handleCreateInvite = async () => {
    if (inviteRole === 'admin' && !inviteBranch) {
      setInviteError('管理员邀请需要选择家支');
      return;
    }
    setInviteSaving(true);
    setInviteError(null);
    try {
      await familyApi.createInvite({
        role: inviteRole,
        branchId: inviteRole === 'admin' ? inviteBranch : undefined,
        maxUses: inviteUses,
        expiresInDays: inviteDays,
      });
      Toast.success({ content: '邀请码已生成', duration: 2.2 });
      setInviteOpen(false);
      invitesQuery.refresh();
    } catch (error) {
      setInviteError(toErrorMessage(error, '生成邀请码失败'));
    } finally {
      setInviteSaving(false);
    }
  };

  const handleRoleChange = async (account: FamilyAccount, role: 'admin' | 'member') => {
    setRoleUpdatingId(account.userId);
    try {
      await familyApi.updateAccountRole(account.userId, role);
      Toast.success({ content: `${account.displayName} 已设为${roleLabel(role)}`, duration: 2 });
      accountsQuery.refresh();
    } finally {
      setRoleUpdatingId(null);
    }
  };

  const handleSaveGenerations = async () => {
    setGenerationSaving(true);
    try {
      const items = generationRows
        .filter((item) => item.name.trim() && item.generationNo > 0)
        .map((item) => ({ generationNo: item.generationNo, name: item.name.trim() }));
      await familyApi.saveGenerationNames(items, generationPoem.trim());
      Toast.success({ content: '字辈已保存', duration: 2.2 });
      generationQuery.refresh();
    } finally {
      setGenerationSaving(false);
    }
  };

  return (
    <div className="app-page family-page">
      <PageHeader
        eyebrow="FAMILY SETTINGS"
        title="家族管理"
        description="维护家族资料、家支、成员角色与字辈信息。只有族长和管理员可以进入这里。"
        actions={
          <Button theme="light" icon={<IconRefresh spin={treeQuery.refreshing} />} onClick={() => {
            treeQuery.refresh();
            branchesQuery.refresh();
            accountsQuery.refresh();
            invitesQuery.refresh();
            generationQuery.refresh();
          }}>
            刷新
          </Button>
        }
      />

      <section className="family-banner">
        <span className="family-banner__seal">{auth.family?.surname?.[0] ?? '族'}</span>
        <div>
          <h2>{auth.family?.name}</h2>
          <p>{auth.family?.motto || '还没有写下家训'}</p>
          <span>
            {auth.family?.memberCount ?? 0} 位成员 · {auth.family?.branchCount ?? 0} 个家支 · 当前身份{' '}
            {roleLabel(auth.membership?.role)}
          </span>
        </div>
      </section>

      <Tabs activeKey={activeTab} onChange={setActiveTab} className="family-tabs">
        <Tabs.TabPane tab="家族资料" itemKey="profile" />
        <Tabs.TabPane tab="家支管理" itemKey="branches" />
        <Tabs.TabPane tab="成员与邀请" itemKey="accounts" />
        <Tabs.TabPane tab="字辈" itemKey="generations" />
      </Tabs>

      {activeTab === 'profile' ? (
        <SectionCard eyebrow="FAMILY PROFILE" title="基础资料">
          <div className="family-form">
            <div className="family-form__row">
              <label>
                <span>家族名称</span>
                <Input value={familyForm.name} onChange={(value) => updateFamilyField('name', value)} maxLength={80} />
              </label>
              <label>
                <span>家族姓氏</span>
                <Input value={familyForm.surname} onChange={(value) => updateFamilyField('surname', value)} maxLength={20} />
              </label>
            </div>
            <div className="family-form__row">
              <label>
                <span>家训</span>
                <Input value={familyForm.motto} onChange={(value) => updateFamilyField('motto', value)} maxLength={120} />
              </label>
              <label>
                <span>家族地区</span>
                <Input value={familyForm.region} onChange={(value) => updateFamilyField('region', value)} maxLength={80} />
              </label>
            </div>
            <label>
              <span>家族简介</span>
              <TextArea
                value={familyForm.description}
                onChange={(value) => updateFamilyField('description', value)}
                maxLength={2000}
                autosize={{ minRows: 4, maxRows: 8 }}
                placeholder="介绍家族的来源、堂号、迁徙与家风…"
              />
            </label>
            {familyError ? <div className="family-form__error">{familyError}</div> : null}
            <div className="family-form__footer">
              <Button theme="solid" type="primary" loading={savingFamily} onClick={handleSaveFamily}>
                保存家族资料
              </Button>
            </div>
          </div>
        </SectionCard>
      ) : null}

      {activeTab === 'branches' ? (
        <SectionCard
          eyebrow="BRANCHES"
          title="家支管理"
          extra={
            <Button theme="light" icon={<IconPlus />} onClick={() => openBranchModal()}>
              新建家支
            </Button>
          }
        >
          {branchesQuery.loading ? (
            <p className="family-quiet">正在整理家支…</p>
          ) : branchesQuery.data?.length ? (
            <div className="branch-manage-list">
              {branchesQuery.data.map((branch, index) => {
                const count = branchCounts.get(branch.id) ?? 0;
                return (
                  <div className="branch-manage-row" key={branch.id}>
                    <span className={`branch-manage-row__dot branch-manage-row__dot--${index % 4}`} />
                    <div className="branch-manage-row__main">
                      <strong>{branch.name}</strong>
                      <span>排序 {branch.sortOrder} · {count} 位成员</span>
                    </div>
                    <div className="branch-manage-row__actions">
                      <Button
                        theme="borderless"
                        icon={<IconEdit />}
                        onClick={() => openBranchModal(branch)}
                        aria-label="编辑家支"
                      />
                      <Button
                        theme="borderless"
                        type="danger"
                        icon={<IconDelete />}
                        disabled={count > 0}
                        onClick={() => setDeleteBranch(branch)}
                        aria-label="删除家支"
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <EmptyState
              compact
              title="尚未建立家支"
              description="按房派或迁居地建立家支，成员可以归入对应家支。"
              actionText="新建家支"
              onAction={() => openBranchModal()}
            />
          )}
        </SectionCard>
      ) : null}

      {activeTab === 'accounts' ? (
        <div className="family-account-grid">
          <SectionCard eyebrow="ACCOUNTS" title="成员账号">
            {!isOwner ? (
              <p className="family-permission-note">仅族长可以查看和调整成员角色。</p>
            ) : accountsQuery.loading ? (
              <p className="family-quiet">正在加载成员账号…</p>
            ) : accountsQuery.data?.length ? (
              <div className="account-list">
                {accountsQuery.data.map((account) => (
                  <div className="account-row" key={account.userId}>
                    <span className="account-row__avatar">{account.displayName.slice(-1)}</span>
                    <div className="account-row__identity">
                      <strong>{account.displayName}</strong>
                      <span>
                        @{account.loginName}
                        {account.personName ? ` · 绑定 ${account.personName}` : ' · 未绑定人物'}
                      </span>
                    </div>
                    {account.role === 'owner' ? (
                      <RolePill role="owner" />
                    ) : (
                      <Select
                        size="small"
                        value={account.role}
                        style={{ width: 100 }}
                        disabled={roleUpdatingId === account.userId}
                        onChange={(value) => handleRoleChange(account, value as 'admin' | 'member')}
                        optionList={[
                          { value: 'admin', label: '管理员' },
                          { value: 'member', label: '普通成员' },
                        ]}
                      />
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <EmptyState compact title="暂无成员账号" description="通过邀请码邀请家族成员加入。" />
            )}
          </SectionCard>

          <SectionCard
            eyebrow="INVITES"
            title="邀请码"
            extra={
              isOwner ? (
                <Button theme="light" icon={<IconPlus />} onClick={() => setInviteOpen(true)}>
                  新建邀请
                </Button>
              ) : null
            }
          >
            {!isOwner ? (
              <p className="family-permission-note">仅族长可以创建和管理邀请码。</p>
            ) : invitesQuery.loading ? (
              <p className="family-quiet">正在加载邀请码…</p>
            ) : invitesQuery.data?.length ? (
              <div className="invite-list">
                {invitesQuery.data.map((invite) => (
                  <InviteRow key={invite.id} invite={invite} onCopy={handleCopy} />
                ))}
              </div>
            ) : (
              <EmptyState
                compact
                title="还没有邀请码"
                description="生成一次性或多次邀请码，邀请族人加入当前家族空间。"
                actionText="新建邀请"
                onAction={() => setInviteOpen(true)}
              />
            )}
          </SectionCard>
        </div>
      ) : null}

      {activeTab === 'generations' ? (
        <SectionCard
          eyebrow="GENERATION NAMES"
          title="字辈谱"
          extra={
            <div className="generation-actions">
              <Button
                theme="borderless"
                icon={<IconPlus />}
                onClick={() =>
                  setGenerationRows((current) => [
                    ...current,
                    { generationNo: (current.at(-1)?.generationNo ?? 0) + 1, name: '' },
                  ])
                }
              >
                添加世代
              </Button>
              <Button
                theme="solid"
                type="primary"
                loading={generationSaving}
                onClick={handleSaveGenerations}
              >
                保存字辈
              </Button>
            </div>
          }
        >
          <div className="generation-editor">
            <label className="generation-editor__poem">
              <span>字辈诗 / 族训</span>
              <Input
                value={generationPoem}
                onChange={setGenerationPoem}
                maxLength={500}
                placeholder="例如：德维垂佑，钦绍念显扬"
              />
            </label>
            <div className="generation-editor__list">
              {generationRows.length ? (
                generationRows.map((row, index) => (
                  <div className="generation-editor__row" key={`${row.generationNo}-${index}`}>
                    <span className="generation-editor__no">第 {row.generationNo} 世</span>
                    <Input
                      value={row.name}
                      maxLength={20}
                      placeholder="字辈用字"
                      onChange={(value) =>
                        setGenerationRows((current) =>
                          current.map((item, itemIndex) =>
                            itemIndex === index ? { ...item, name: value } : item,
                          ),
                        )
                      }
                    />
                    <Button
                      theme="borderless"
                      type="danger"
                      icon={<IconDelete />}
                      onClick={() => setGenerationRows((current) => current.filter((_, i) => i !== index))}
                      aria-label="删除这一代"
                    />
                  </div>
                ))
              ) : (
                <EmptyState
                  compact
                  title="还没有配置字辈"
                  description="字辈会显示在人物世代的旁边，帮助核对家族辈分。"
                  actionText="添加第一代字辈"
                  onAction={() => setGenerationRows([{ generationNo: 1, name: '' }])}
                />
              )}
            </div>
          </div>
        </SectionCard>
      ) : null}

      <Modal
        visible={branchModal.open}
        title={branchModal.branch ? '编辑家支' : '新建家支'}
        onCancel={() => setBranchModal({ open: false })}
        onOk={handleSaveBranch}
        okText="保存"
        cancelText="取消"
        confirmLoading={branchSaving}
      >
        <div className="family-modal-form">
          <label>
            <span>家支名称</span>
            <Input value={branchName} onChange={setBranchName} maxLength={80} placeholder="例如：长房" />
          </label>
          <label>
            <span>显示顺序</span>
            <Input value={branchSort} onChange={setBranchSort} placeholder="数字越小越靠前" />
          </label>
        </div>
      </Modal>

      <Modal
        visible={Boolean(deleteBranch)}
        title="删除这个家支？"
        type="warning"
        okText="确认删除"
        cancelText="取消"
        onCancel={() => setDeleteBranch(null)}
        onOk={handleDeleteBranch}
      >
        <p className="family-modal-note">
          只有没有成员归属的家支可以删除。删除后不可恢复。
        </p>
      </Modal>

      <Modal
        visible={inviteOpen}
        title="生成家族邀请码"
        onCancel={() => setInviteOpen(false)}
        footer={
          <div className="family-modal-footer">
            <Button theme="borderless" onClick={() => setInviteOpen(false)} disabled={inviteSaving}>
              取消
            </Button>
            <Button theme="solid" type="primary" loading={inviteSaving} onClick={handleCreateInvite}>
              生成邀请码
            </Button>
          </div>
        }
      >
        <div className="family-modal-form">
          <label>
            <span>邀请角色</span>
            <Select
              value={inviteRole}
              onChange={(value) => setInviteRole(value as 'member' | 'admin')}
              optionList={[
                { value: 'member', label: '普通成员' },
                { value: 'admin', label: '家支管理员' },
              ]}
              style={{ width: '100%' }}
            />
          </label>
          {inviteRole === 'admin' ? (
            <label>
              <span>管理家支</span>
              <Select
                value={inviteBranch || undefined}
                onChange={(value) => setInviteBranch(String(value))}
                optionList={(branchesQuery.data ?? []).map((branch) => ({
                  value: branch.id,
                  label: branch.name,
                }))}
                placeholder="选择需要管理的家支"
                style={{ width: '100%' }}
              />
            </label>
          ) : null}
          <div className="family-modal-form__row">
            <label>
              <span>可使用次数</span>
              <Input
                value={String(inviteUses)}
                onChange={(value) => setInviteUses(Math.max(1, Number(value) || 1))}
              />
            </label>
            <label>
              <span>有效天数</span>
              <Input
                value={String(inviteDays)}
                onChange={(value) => setInviteDays(Math.max(1, Number(value) || 1))}
              />
            </label>
          </div>
          {inviteError ? <div className="family-form__error">{inviteError}</div> : null}
        </div>
      </Modal>
    </div>
  );
}

function InviteRow({ invite, onCopy }: { invite: Invite; onCopy: (value: string) => void }) {
  return (
    <div className="invite-row">
      <span className="invite-row__icon">
        <IconMail />
      </span>
      <div className="invite-row__body">
        <div>
          <strong>{invite.code}</strong>
          <button type="button" onClick={() => onCopy(invite.code)} aria-label="复制邀请码">
            <IconCopy size="small" />
          </button>
        </div>
        <span>
          {roleLabel(invite.role)}
          {invite.branchName ? ` · ${invite.branchName}` : ''} · 已用 {invite.usedCount}/{invite.maxUses} 次
        </span>
      </div>
      <div className="invite-row__meta">
        <span>{formatDate(invite.expiresAt, 'YYYY.MM.DD')} 到期</span>
        <em className={invite.status === 'active' ? 'is-active' : ''}>{invite.status === 'active' ? '有效' : '已失效'}</em>
      </div>
    </div>
  );
}
