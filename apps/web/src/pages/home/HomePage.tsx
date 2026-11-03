import { useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Skeleton, Tooltip } from '@douyinfe/semi-ui';
import {
  IconArrowRight,
  IconBookOpenStroked,
  IconBranch,
  IconCalendar,
  IconEdit,
  IconGallery,
  IconGift,
  IconRefresh,
  IconUserGroup,
  IconUserAdd,
} from '@douyinfe/semi-icons';
import dayjs from 'dayjs';
import { useAppSelector, useIsReviewer } from '@/store/hooks';
import { useAsync } from '@/hooks/useAsync';
import { personsApi } from '@/api/persons';
import { contentApi } from '@/api/content';
import { familyApi } from '@/api/family';
import { SectionCard } from '@/components/SectionCard';
import { EmptyState } from '@/components/EmptyState';
import { ErrorState } from '@/components/ErrorState';
import { SectionSkeleton } from '@/components/LoadingScreen';
import type { Activity, Anniversary } from '@/types/api';
import {
  anniversaryCountdown,
  anniversaryTitle,
  formatDate,
  formatDateTime,
  fromNow,
} from '@/utils/format';
import { cn } from '@/utils/cn';
import './HomePage.scss';

const quickActions = [
  { key: 'tree', title: '族谱树', subtitle: '查看世系关系', path: '/tree', icon: <IconBranch />, tone: 'blue' },
  { key: 'members', title: '成员查询', subtitle: '寻找家族成员', path: '/members', icon: <IconUserGroup />, tone: 'jade' },
  { key: 'gallery', title: '家族相册', subtitle: '珍藏家族影像', path: '/gallery', icon: <IconGallery />, tone: 'teal' },
  { key: 'stories', title: '家族故事', subtitle: '传承家族文化', path: '/stories', icon: <IconBookOpenStroked />, tone: 'violet' },
  { key: 'requests', title: '我的申请', subtitle: '查看资料进度', path: '/requests', icon: <IconEdit />, tone: 'rose' },
  { key: 'add', title: '新增成员', subtitle: '续写家族新页', path: '/members?create=1', icon: <IconUserAdd />, tone: 'gold' },
];

const activityTones: Record<string, string> = {
  person: 'blue',
  family: 'jade',
  member: 'violet',
  request: 'gold',
  system: 'slate',
};

export default function HomePage() {
  const navigate = useNavigate();
  const auth = useAppSelector((state) => state.auth);
  const isReviewer = useIsReviewer();
  const familyId = auth.family?.id;
  const today = dayjs();
  const hour = today.hour();
  const greeting = hour < 6 ? '夜深了' : hour < 11 ? '早上好' : hour < 14 ? '午间好' : hour < 18 ? '下午好' : '晚上好';

  const treeQuery = useAsync(
    async () => {
      const [tree, branches] = await Promise.all([
        personsApi.getTree(),
        familyApi.listBranches(),
      ]);
      return { tree, branches: branches.items };
    },
    [familyId],
    { enabled: Boolean(familyId) },
  );

  const activityQuery = useAsync(
    (signal) => contentApi.listActivity(8).then((page) => {
      if (signal.aborted) return [];
      return page.items;
    }),
    [familyId],
    { enabled: Boolean(familyId) },
  );

  const anniversaryQuery = useAsync(
    () => contentApi.listAnniversaries(90).then((page) => page.items),
    [familyId],
    { enabled: Boolean(familyId) },
  );

  const requestQuery = useAsync(
    () =>
      contentApi
        .listEditRequests({ status: 'pending', mine: !isReviewer, limit: 20 })
        .then((page) => page.items),
    [familyId, isReviewer],
    { enabled: Boolean(familyId) },
  );

  const storyQuery = useAsync(
    () => contentApi.listStories().then((page) => page.items),
    [familyId],
    { enabled: Boolean(familyId) },
  );

  const generations = useMemo(() => {
    const persons = treeQuery.data?.tree.persons ?? [];
    return Array.from(new Set(persons.map((person) => person.generationNo))).sort((a, b) => a - b);
  }, [treeQuery.data]);

  const branchStats = useMemo(() => {
    const persons = treeQuery.data?.tree.persons ?? [];
    return (treeQuery.data?.branches ?? []).map((branch) => {
      const count = persons.filter((person) => person.branchId === branch.id).length;
      return { ...branch, count };
    });
  }, [treeQuery.data]);

  const pendingItems = requestQuery.data ?? [];
  const recentStories = (storyQuery.data ?? []).slice(0, 3);
  const actions = quickActions.map((action) => {
    if (action.key !== 'add' || isReviewer) return action;
    return {
      ...action,
      title: '修改资料',
      subtitle: auth.membership?.personId ? '补充我的档案' : '完善成员信息',
      path: auth.membership?.personId
        ? `/persons/${auth.membership.personId}`
        : '/members',
      icon: <IconEdit />,
    };
  });

  const stats = [
    { label: '家族成员', value: auth.family?.memberCount ?? 0, suffix: '人', icon: <IconUserGroup />, tone: 'blue' },
    { label: '传承世代', value: generations.length || '—', suffix: generations.length ? '世' : '', icon: <IconBranch />, tone: 'jade' },
    { label: '家族家支', value: auth.family?.branchCount ?? branchStats.length, suffix: '支', icon: <IconGallery />, tone: 'teal' },
    { label: '家族故事', value: storyQuery.data?.length ?? '—', suffix: storyQuery.data ? '篇' : '', icon: <IconBookOpenStroked />, tone: 'violet' },
  ];

  return (
    <div className="app-page home-page">
      <div className="home-topline">
        <div>
          <p className="home-greeting">
            {greeting}，<strong>{auth.user?.displayName}</strong>
          </p>
          <p className="home-date">
            {today.format('YYYY年M月D日')} · {today.format('dddd')}
          </p>
        </div>
        <div className="home-topline__actions">
          <Tooltip content="刷新家族动态">
            <Button
              theme="borderless"
              icon={<IconRefresh spin={treeQuery.refreshing || activityQuery.refreshing} />}
              onClick={() => {
                treeQuery.refresh();
                activityQuery.refresh();
                anniversaryQuery.refresh();
                requestQuery.refresh();
                storyQuery.refresh();
              }}
              aria-label="刷新"
            />
          </Tooltip>
          {isReviewer ? (
            <Button theme="light" icon={<IconUserAdd />} onClick={() => navigate('/members?create=1')}>
              添加成员
            </Button>
          ) : (
            <Button
              theme="light"
              icon={<IconEdit />}
              onClick={() =>
                navigate(
                  auth.membership?.personId
                    ? `/persons/${auth.membership.personId}`
                    : '/profile',
                )
              }
            >
              我的档案
            </Button>
          )}
        </div>
      </div>

      <section className="home-hero">
        <div className="home-hero__texture" aria-hidden />
        <div className="home-hero__copy">
          <div className="home-hero__meta">
            <span className="home-hero__meta-line" />
            <span>FAMILY ARCHIVE</span>
            <span className="home-hero__meta-dot" />
            <span>{auth.family?.region || '家族空间'}</span>
          </div>
          <h1>
            {auth.family?.name || '家族族谱'}
            <span className="home-hero__seal" aria-label="族谱印章">
              {auth.family?.surname?.[0] ?? '族'}
              <small>族谱</small>
            </span>
          </h1>
          <p className="home-hero__motto">{auth.family?.motto || '寻根溯源 · 传承家风'}</p>
          <p className="home-hero__description">
            {auth.family?.description ||
              '记录家族成员、世系与共同记忆，让每一代人的故事都有归处。'}
          </p>
          <div className="home-hero__actions">
            <Button
              theme="solid"
              type="primary"
              size="large"
              icon={<IconBranch />}
              onClick={() => navigate('/tree')}
            >
              浏览族谱树
            </Button>
            <Button
              theme="borderless"
              size="large"
              className="home-hero__ghost-btn"
              onClick={() => navigate('/members')}
            >
              查询成员
              <IconArrowRight />
            </Button>
          </div>
        </div>

        <aside className="home-hero__aside">
          <div className="home-hero__quote">
            <span className="home-hero__quote-mark">“</span>
            <p>参天之木，必有其根；怀山之水，必有其源。</p>
            <span className="home-hero__quote-source">清 · 张澍《姓氏寻源》</span>
          </div>
          <div className="home-hero__aside-meta">
            <div>
              <span>当前身份</span>
              <strong>{isReviewer ? (auth.membership?.role === 'owner' ? '族长' : '管理员') : '家族成员'}</strong>
            </div>
            <div>
              <span>家支</span>
              <strong>{branchStats.length || auth.family?.branchCount || '—'} 支</strong>
            </div>
          </div>
        </aside>
      </section>

      <section className="home-stats" aria-label="家族概览">
        {stats.map((stat) => (
          <article className={cn('home-stat', `home-stat--${stat.tone}`)} key={stat.label}>
            <span className="home-stat__icon">{stat.icon}</span>
            <div>
              <span className="home-stat__label">{stat.label}</span>
              <p className="home-stat__value">
                {stat.value}
                <small>{stat.suffix}</small>
              </p>
            </div>
          </article>
        ))}
      </section>

      <div className="home-grid">
        <div className="home-grid__main">
          <SectionCard
            eyebrow="EXPLORE"
            title="家族入口"
            extra={<span className="home-section-note">从一处进入，看见整个家族</span>}
          >
            <div className="quick-grid">
              {actions.map((action) => (
                <button
                  key={action.key}
                  type="button"
                  className="quick-action"
                  onClick={() => navigate(action.path)}
                >
                  <span className={cn('quick-action__icon', `quick-action__icon--${action.tone}`)}>
                    {action.icon}
                  </span>
                  <span className="quick-action__text">
                    <strong>{action.title}</strong>
                    <small>{action.subtitle}</small>
                  </span>
                  <IconArrowRight className="quick-action__arrow" />
                </button>
              ))}
            </div>
          </SectionCard>

          <SectionCard
            eyebrow="LATEST ACTIVITY"
            title="最新动态"
            extra={
              <button type="button" className="text-link" onClick={() => activityQuery.refresh()}>
                刷新动态 <IconRefresh size="small" />
              </button>
            }
          >
            {activityQuery.loading ? (
              <SectionSkeleton rows={4} />
            ) : activityQuery.error ? (
              <ErrorState description={activityQuery.error} onRetry={activityQuery.refresh} />
            ) : activityQuery.data?.length ? (
              <div className="activity-feed">
                {activityQuery.data.map((activity) => (
                  <ActivityRow
                    key={activity.id}
                    activity={activity}
                    onClick={() => navigate('/requests')}
                  />
                ))}
              </div>
            ) : (
              <EmptyState
                compact
                title="家族故事刚刚开始"
                description="新增一位成员、上传一张照片，第一条动态就会出现在这里。"
                actionText={isReviewer ? '去添加成员' : '完善我的档案'}
                onAction={() =>
                  navigate(
                    isReviewer
                      ? '/members?create=1'
                      : auth.membership?.personId
                        ? `/persons/${auth.membership.personId}`
                        : '/profile',
                  )
                }
              />
            )}
          </SectionCard>

          {recentStories.length ? (
            <SectionCard
              eyebrow="FAMILY STORIES"
              title="最近的故事"
              extra={
                <button type="button" className="text-link" onClick={() => navigate('/stories')}>
                  全部故事 <IconArrowRight size="small" />
                </button>
              }
            >
              <div className="home-story-strip">
                {recentStories.map((story) => (
                  <button
                    key={story.id}
                    type="button"
                    className="home-story-card"
                    onClick={() => navigate(`/stories/${story.id}`)}
                  >
                    <span className="home-story-card__mark">卷</span>
                    <strong>{story.title}</strong>
                    <p className="clamp-2">{story.body}</p>
                    <span className="home-story-card__meta">
                      {story.personName || story.authorName} · {fromNow(story.createdAt)}
                    </span>
                  </button>
                ))}
              </div>
            </SectionCard>
          ) : null}
        </div>

        <aside className="home-grid__side">
          <SectionCard
            eyebrow="UPCOMING"
            title="近期生日与祭日"
            extra={
              <span className="home-section-count">
                {anniversaryQuery.data?.length ?? 0}
              </span>
            }
          >
            {anniversaryQuery.loading ? (
              <SectionSkeleton rows={3} />
            ) : anniversaryQuery.error ? (
              <ErrorState description={anniversaryQuery.error} onRetry={anniversaryQuery.refresh} />
            ) : anniversaryQuery.data?.length ? (
              <div className="anniversary-list">
                {anniversaryQuery.data.slice(0, 4).map((item) => (
                  <AnniversaryRow
                    key={`${item.personId}-${item.kind}-${item.date}`}
                    item={item}
                    onClick={() => navigate(`/persons/${item.personId}`)}
                  />
                ))}
              </div>
            ) : (
              <EmptyState
                compact
                title="近期没有纪念日"
                description="完善成员的生日和祭日后，会在这里提前提醒。"
              />
            )}
          </SectionCard>

          <SectionCard
            eyebrow="TO DO"
            title={isReviewer ? '待审核资料' : '我的申请'}
            extra={
              <span className={cn('todo-count', pendingItems.length > 0 && 'has-items')}>
                {pendingItems.length}
              </span>
            }
          >
            {requestQuery.loading ? (
              <SectionSkeleton rows={2} />
            ) : pendingItems.length ? (
              <div className="todo-panel">
                <div className="todo-panel__lead">
                  <span className="todo-panel__stamp">审</span>
                  <div>
                    <strong>
                      {isReviewer ? '有新的资料等待确认' : '资料正在家族审核中'}
                    </strong>
                    <p>
                      {isReviewer
                        ? `${pendingItems.length} 条申请需要你确认后才会写入族谱。`
                        : `${pendingItems.length} 条申请已提交，请耐心等待族长或管理员处理。`}
                    </p>
                  </div>
                </div>
                <button type="button" className="todo-panel__list" onClick={() => navigate('/requests')}>
                  {pendingItems.slice(0, 2).map((request) => (
                    <span key={request.id}>
                      <em>{request.requesterName}</em>
                      <strong>{request.targetName || request.summary || '家族资料'}</strong>
                      <small>{formatDate(request.submittedAt, 'MM.DD HH:mm')}</small>
                    </span>
                  ))}
                </button>
                <Button theme="light" type="primary" block onClick={() => navigate('/requests')}>
                  {isReviewer ? '前往审核' : '查看申请进度'}
                </Button>
              </div>
            ) : (
              <div className="todo-quiet">
                <span className="todo-quiet__icon">安</span>
                <div>
                  <strong>暂无待处理事项</strong>
                  <p>{isReviewer ? '家族资料都已处理妥当。' : '有需要修改的资料时，可以随时提交申请。'}</p>
                </div>
                <Button theme="borderless" onClick={() => navigate('/members')}>
                  查看成员
                </Button>
              </div>
            )}
          </SectionCard>

          <SectionCard
            eyebrow="BRANCHES"
            title="家支一览"
            extra={
              <button type="button" className="text-link" onClick={() => navigate('/members')}>
                全部 <IconArrowRight size="small" />
              </button>
            }
          >
            {treeQuery.loading ? (
              <Skeleton placeholder={<Skeleton.Paragraph rows={4} />} loading />
            ) : branchStats.length ? (
              <div className="branch-list">
                {branchStats.map((branch, index) => {
                  const max = Math.max(...branchStats.map((item) => item.count), 1);
                  return (
                    <button
                      key={branch.id}
                      type="button"
                      className="branch-list__item"
                      onClick={() => navigate(`/members?branchId=${branch.id}`)}
                    >
                      <div className="branch-list__label">
                        <span className={cn('branch-list__dot', `branch-list__dot--${index % 4}`)} />
                        <span>{branch.name}</span>
                        <em>{branch.count} 人</em>
                      </div>
                      <span className="branch-list__track">
                        <span
                          className={cn('branch-list__fill', `branch-list__fill--${index % 4}`)}
                          style={{ width: `${Math.max(8, Math.round((branch.count / max) * 100))}%` }}
                        />
                      </span>
                    </button>
                  );
                })}
              </div>
            ) : (
              <EmptyState compact title="尚未建立家支" description="家族管理中可以创建和整理家支。" />
            )}
          </SectionCard>
        </aside>
      </div>

      <footer className="home-footer">
        <span>家族族谱 · {auth.family?.name}</span>
        <span>用一页纸，安放一个家族的来处。</span>
      </footer>
    </div>
  );
}

function ActivityRow({ activity, onClick }: { activity: Activity; onClick: () => void }) {
  const tone = activityTones[activity.kind] ?? 'slate';
  return (
    <button type="button" className="activity-row" onClick={onClick}>
      <span className={cn('activity-row__icon', `activity-row__icon--${tone}`)}>
        {activity.kind === 'person' ? '人' : activity.kind === 'request' ? '审' : activity.kind === 'family' ? '家' : '记'}
      </span>
      <span className="activity-row__text">
        <span>
          <strong>{activity.actorName}</strong>
          {activity.summary}
          {activity.needsReview ? <em>待处理</em> : null}
        </span>
        <small>{activity.detail || '家族资料更新'}</small>
      </span>
      <span className="activity-row__time">{formatDateTime(activity.createdAt)}</span>
    </button>
  );
}

function AnniversaryRow({ item, onClick }: { item: Anniversary; onClick: () => void }) {
  const isBirthday = item.kind === 'birthday';
  return (
    <button type="button" className="anniversary-row" onClick={onClick}>
      <span className={cn('anniversary-row__icon', isBirthday ? 'is-birthday' : 'is-memorial')}>
        {isBirthday ? <IconGift /> : <IconCalendar />}
      </span>
      <span className="anniversary-row__text">
        <strong>{item.fullName}</strong>
        <small>
          {anniversaryTitle(item)} · {item.isLunar ? item.lunarText : item.solarText}
        </small>
      </span>
      <span className={cn('anniversary-row__countdown', item.daysUntil <= 3 && 'is-soon')}>
        {anniversaryCountdown(item.daysUntil)}
      </span>
    </button>
  );
}
