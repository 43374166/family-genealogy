import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Input, SideSheet, Toast } from '@douyinfe/semi-ui';
import {
  IconArrowRight,
  IconCheckCircleStroked,
  IconCrossCircleStroked,
  IconEdit,
  IconFile,
  IconRefresh,
  IconUser,
  IconUserGroup,
} from '@douyinfe/semi-icons';
import { useAppSelector, useIsReviewer } from '@/store/hooks';
import { useAsync } from '@/hooks/useAsync';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { contentApi } from '@/api/content';
import { PageHeader } from '@/components/PageHeader';
import { EmptyState } from '@/components/EmptyState';
import { ErrorState } from '@/components/ErrorState';
import { SectionSkeleton } from '@/components/LoadingScreen';
import { RequestStatusPill } from '@/components/StatusPill';
import type { EditRequest, EditRequestStatus } from '@/types/api';
import { formatDateTime, fromNow } from '@/utils/format';
import { cn } from '@/utils/cn';
import { toErrorMessage } from '@/utils/error';
import './RequestsPage.scss';

const STATUS_TABS: { key: EditRequestStatus | 'all'; label: string }[] = [
  { key: 'pending', label: '待审核' },
  { key: 'approved', label: '已通过' },
  { key: 'rejected', label: '已拒绝' },
  { key: 'all', label: '全部' },
];

const REQUEST_TYPE_LABELS: Record<string, string> = {
  update_person: '资料修改',
  update_person_profile: '完整资料修改',
  create_person: '新增人物',
  add_parent_child: '添加父母子女',
  add_spouse: '添加配偶',
  end_parent_child: '解除父母子女',
  end_spouse: '解除配偶',
};

const FIELD_LABELS: Record<string, string> = {
  surname: '姓氏',
  givenName: '名字',
  courtesyName: '字号',
  alias: '别名',
  gender: '性别',
  generationNo: '世代',
  generationName: '字辈',
  branchId: '家支',
  birthOrder: '排行',
  birthYear: '出生年',
  birthMonth: '出生月',
  birthDay: '出生日',
  birthCalendar: '出生历法',
  deathYear: '逝世年',
  deathMonth: '逝世月',
  deathDay: '逝世日',
  lifeStatus: '在世状态',
  birthPlace: '籍贯',
  residence: '现居地',
  occupation: '职业',
  education: '教育',
  biography: '生平简介',
  parentId: '父母',
  childId: '子女',
  parentRole: '父母角色',
  personAId: '人物 A',
  personBId: '人物 B',
  edgeType: '关系类型',
  edgeId: '关系 ID',
  version: '资料版本',
};

export default function RequestsPage() {
  useDocumentTitle('审核中心');
  const navigate = useNavigate();
  const auth = useAppSelector((state) => state.auth);
  const isReviewer = useIsReviewer();
  const [status, setStatus] = useState<EditRequestStatus | 'all'>('pending');
  const [selected, setSelected] = useState<EditRequest | null>(null);
  const [reviewTarget, setReviewTarget] = useState<{ request: EditRequest; approve: boolean } | null>(null);
  const [reviewNote, setReviewNote] = useState('');
  const [reviewing, setReviewing] = useState(false);
  const [reviewError, setReviewError] = useState<string | null>(null);

  const query = useAsync(
    async () => (await contentApi.listEditRequests({ limit: 100, mine: !isReviewer })).items,
    [auth.family?.id, isReviewer],
    { enabled: Boolean(auth.family?.id) },
  );

  const requests = useMemo(() => query.data ?? [], [query.data]);
  const counts = useMemo(() => {
    return {
      all: requests.length,
      pending: requests.filter((item) => item.status === 'pending').length,
      approved: requests.filter((item) => item.status === 'approved').length,
      rejected: requests.filter((item) => item.status === 'rejected').length,
    };
  }, [requests]);

  const filtered = useMemo(
    () => (status === 'all' ? requests : requests.filter((item) => item.status === status)),
    [requests, status],
  );

  const openReview = (request: EditRequest, approve: boolean) => {
    setReviewTarget({ request, approve });
    setReviewNote('');
    setReviewError(null);
  };

  const submitReview = async () => {
    if (!reviewTarget) return;
    if (!reviewTarget.approve && !reviewNote.trim()) {
      setReviewError('拒绝申请时需要填写审核意见');
      return;
    }
    setReviewing(true);
    setReviewError(null);
    try {
      const updated = await contentApi.reviewEditRequest(
        reviewTarget.request.id,
        reviewTarget.approve,
        reviewNote.trim(),
      );
      Toast.success({
        content: reviewTarget.approve ? '申请已通过并写入族谱' : '申请已拒绝',
        duration: 2.5,
      });
      setReviewTarget(null);
      setSelected((current) => (current?.id === updated.id ? updated : current));
      query.refresh();
    } catch (error) {
      setReviewError(toErrorMessage(error, '审核失败，请稍后重试'));
    } finally {
      setReviewing(false);
    }
  };

  const ownPersonId = auth.membership?.personId;

  return (
    <div className="app-page requests-page">
      <PageHeader
        eyebrow="REVIEW & REQUESTS"
        title={isReviewer ? '审核中心' : '我的申请'}
        description={
          isReviewer
            ? '普通成员提交的资料与关系变更，会在这里等待族长或管理员确认。'
            : '查看你提交的资料修改申请与审核进度。'
        }
        actions={
          <>
            <Button theme="light" icon={<IconRefresh spin={query.refreshing} />} onClick={query.refresh}>
              刷新
            </Button>
            {!isReviewer ? (
              <Button
                theme="solid"
                type="primary"
                icon={<IconEdit />}
                onClick={() => {
                  if (ownPersonId) navigate(`/persons/${ownPersonId}`);
                  else navigate('/members');
                }}
              >
                申请修改资料
              </Button>
            ) : null}
          </>
        }
      />

      <section className="requests-summary">
        <div className="requests-summary__stamp">
          <IconFile />
        </div>
        <div className="requests-summary__text">
          <strong>
            {isReviewer
              ? counts.pending
                ? `${counts.pending} 条申请待处理`
                : '所有申请都已处理'
              : counts.pending
                ? `${counts.pending} 条申请正在审核`
                : '暂无待审核申请'}
          </strong>
          <p>
            {isReviewer
              ? '通过后会立即写入正式档案，并记录审核人。'
              : '审核通过后资料才会更新到族谱，请耐心等待。'}
          </p>
        </div>
        <div className="requests-summary__counts">
          <span>
            <em>{counts.pending}</em> 待审核
          </span>
          <span>
            <em>{counts.approved}</em> 已通过
          </span>
          <span>
            <em>{counts.rejected}</em> 已拒绝
          </span>
        </div>
      </section>

      <div className="requests-tabs" role="tablist">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.key}
            type="button"
            role="tab"
            aria-selected={status === tab.key}
            className={cn('requests-tab', status === tab.key && 'is-active')}
            onClick={() => setStatus(tab.key)}
          >
            {tab.label}
            <em>{counts[tab.key as keyof typeof counts] ?? 0}</em>
          </button>
        ))}
      </div>

      {query.error ? (
        <ErrorState description={query.error} onRetry={query.refresh} />
      ) : query.loading ? (
        <div className="surface-card requests-card">
          <SectionSkeleton rows={5} />
        </div>
      ) : filtered.length ? (
        <div className="requests-list">
          {filtered.map((request) => (
            <button
              type="button"
              className="request-card"
              key={request.id}
              onClick={() => setSelected(request)}
            >
              <span className={cn('request-card__type', `request-card__type--${request.status}`)}>
                {REQUEST_TYPE_LABELS[request.requestType] ?? '资料申请'}
              </span>
              <span className="request-card__main">
                <span className="request-card__title">
                  {request.requesterName}
                  <i>提交了</i>
                  {request.summary || `${request.targetName}的资料申请`}
                </span>
                <span className="request-card__detail">
                  {request.changedFields?.length
                    ? request.changedFields
                        .map((field) => FIELD_LABELS[field] ?? field)
                        .join('、')
                    : request.targetName || REQUEST_TYPE_LABELS[request.requestType]}
                </span>
              </span>
              <span className="request-card__meta">
                <RequestStatusPill status={request.status} />
                <small>{fromNow(request.submittedAt)}</small>
              </span>
              <IconArrowRight size="small" className="request-card__arrow" />
            </button>
          ))}
        </div>
      ) : (
        <div className="surface-card requests-empty">
          <EmptyState
            title={
              status === 'pending'
                ? isReviewer
                  ? '没有待审核的申请'
                  : '没有正在审核的申请'
                : '这里还没有记录'
            }
            description={
              isReviewer
                ? '成员提交资料修改或关系变更后，会在这里等待你的确认。'
                : '需要修改人物资料时，可以在人物档案中提交申请。'
            }
            actionText={!isReviewer ? '去成员列表看看' : undefined}
            onAction={!isReviewer ? () => navigate('/members') : undefined}
          />
        </div>
      )}

      <SideSheet
        visible={Boolean(selected)}
        placement="right"
        width={620}
        title="申请详情"
        onCancel={() => setSelected(null)}
        className="request-detail-sheet"
        footer={
          selected?.status === 'pending' && isReviewer ? (
            <div className="request-detail__footer">
              <Button
                theme="light"
                type="danger"
                icon={<IconCrossCircleStroked />}
                onClick={() => openReview(selected, false)}
              >
                拒绝申请
              </Button>
              <Button
                theme="solid"
                type="primary"
                icon={<IconCheckCircleStroked />}
                onClick={() => openReview(selected, true)}
              >
                通过并写入
              </Button>
            </div>
          ) : null
        }
      >
        {selected ? <RequestDetail request={selected} /> : null}
      </SideSheet>

      <SideSheet
        visible={Boolean(reviewTarget)}
        placement="right"
        width={460}
        title={reviewTarget?.approve ? '通过这条申请？' : '拒绝这条申请？'}
        onCancel={() => setReviewTarget(null)}
        className="review-sheet"
        footer={
          <div className="request-detail__footer">
            <Button theme="borderless" onClick={() => setReviewTarget(null)} disabled={reviewing}>
              取消
            </Button>
            <Button
              theme="solid"
              type={reviewTarget?.approve ? 'primary' : 'danger'}
              loading={reviewing}
              onClick={submitReview}
            >
              {reviewTarget?.approve ? '确认通过' : '确认拒绝'}
            </Button>
          </div>
        }
      >
        <div className="review-panel">
          <p>
            {reviewTarget?.approve
              ? '通过后，申请中的修改会在服务端事务中写入正式档案。请确认内容真实、符合家族记录。'
              : '拒绝时请写明原因，申请人会在审核记录中看到这段说明。'}
          </p>
          <label>
            <span>{reviewTarget?.approve ? '审核备注（可选）' : '拒绝原因（必填）'}</span>
            <Input
              value={reviewNote}
              onChange={setReviewNote}
              maxLength={2000}
              placeholder={reviewTarget?.approve ? '可补充说明' : '例如：与家族旧谱记录不一致，请补充依据'}
            />
          </label>
          {reviewError ? <div className="review-panel__error">{reviewError}</div> : null}
        </div>
      </SideSheet>
    </div>
  );
}

function RequestDetail({ request }: { request: EditRequest }) {
  const fields = buildFieldEntries(request);
  return (
    <div className="request-detail">
      <div className="request-detail__head">
        <span className="request-detail__avatar">
          <IconUser />
        </span>
        <div>
          <h3>{request.summary || REQUEST_TYPE_LABELS[request.requestType] || '家族资料申请'}</h3>
          <p>
            {request.requesterName} · {formatDateTime(request.submittedAt)}
          </p>
        </div>
        <RequestStatusPill status={request.status} />
      </div>

      <div className="request-detail__grid">
        <div>
          <span>申请类型</span>
          <strong>{REQUEST_TYPE_LABELS[request.requestType] ?? request.requestType}</strong>
        </div>
        <div>
          <span>目标人物</span>
          <strong>{request.targetName || '家族关系'}</strong>
        </div>
        <div>
          <span>提交人</span>
          <strong>{request.requesterName}</strong>
        </div>
        <div>
          <span>资料版本</span>
          <strong>{request.baseVersion ? `v${request.baseVersion}` : '—'}</strong>
        </div>
      </div>

      <section className="request-detail__section">
        <h4>申请内容</h4>
        {fields.length ? (
          <div className="request-detail__changes">
            {fields.map(([key, value]) => (
              <div key={key}>
                <span>{FIELD_LABELS[key] ?? key}</span>
                <strong>{value || '（清空）'}</strong>
              </div>
            ))}
          </div>
        ) : (
          <p className="request-detail__empty">这条申请没有可展示的字段差异。</p>
        )}
      </section>

      {request.baseVersion ? (
        <p className="request-detail__hint">
          审核时会检查人物资料版本。若资料已经被其他人更新，申请可能会提示版本冲突。
        </p>
      ) : null}

      <section className="request-detail__section">
        <h4>审核记录</h4>
        <div className="request-detail__timeline">
          <div>
            <span className="is-done" />
            <p>
              <strong>{request.requesterName}</strong> 提交申请
              <em>{formatDateTime(request.submittedAt)}</em>
            </p>
          </div>
          {request.status !== 'pending' ? (
            <div>
              <span className={request.status === 'approved' ? 'is-done' : 'is-rejected'} />
              <p>
                <strong>{request.reviewerName || '审核人'}</strong>
                {request.status === 'approved' ? ' 通过了申请' : ' 拒绝了申请'}
                <em>{request.reviewedAt ? formatDateTime(request.reviewedAt) : ''}</em>
              </p>
              {request.reviewNote ? <blockquote>{request.reviewNote}</blockquote> : null}
            </div>
          ) : (
            <div>
              <span className="is-pending" />
              <p>等待族长或管理员审核</p>
            </div>
          )}
        </div>
      </section>

      <div className="request-detail__people">
        <IconUserGroup size="small" />
        家族资料审核由族长与具备范围权限的管理员共同维护。
      </div>
    </div>
  );
}

function buildFieldEntries(request: EditRequest): [string, string][] {
  const source =
    request.requestType === 'update_person'
      ? (request.changes as unknown as Record<string, unknown>)
      : request.payload;
  if (!source || typeof source !== 'object') return [];
  return Object.entries(source)
    .filter(([, value]) => value !== undefined && value !== null)
    .filter(([key]) => key !== 'version')
    .map(([key, value]) => {
      let display: string;
      if (typeof value === 'boolean') display = value ? '是' : '否';
      else if (typeof value === 'string') display = value;
      else if (typeof value === 'number') display = String(value);
      else if (Array.isArray(value)) display = value.join('、');
      else if (value && typeof value === 'object') display = JSON.stringify(value);
      else display = '';
      return [key, display] as [string, string];
    });
}
