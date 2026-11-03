import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Button, Input, Skeleton, Toast } from '@douyinfe/semi-ui';
import { SafeSelect as Select } from '@/components/SafeSelect';
import {
  IconArrowRight,
  IconBranch,
  IconFilter,
  IconPlus,
  IconSearch,
  IconUserGroup,
} from '@douyinfe/semi-icons';
import { useAppSelector, useIsReviewer } from '@/store/hooks';
import { useAsync } from '@/hooks/useAsync';
import { useDebounce } from '@/hooks/useDebounce';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { personsApi } from '@/api/persons';
import { familyApi } from '@/api/family';
import { PageHeader } from '@/components/PageHeader';
import { PersonAvatar } from '@/components/PersonAvatar';
import { EmptyState } from '@/components/EmptyState';
import { ErrorState } from '@/components/ErrorState';
import { PersonFormDrawer } from '@/components/PersonFormDrawer';
import { LifeStatusPill, StatusPill } from '@/components/StatusPill';
import type { PersonSummary } from '@/types/api';
import {
  formatYear,
  genderLabel,
  generationShort,
  lifeYears,
} from '@/utils/format';
import { cn } from '@/utils/cn';
import './MembersPage.scss';

const PAGE_SIZE = 24;

export default function MembersPage() {
  useDocumentTitle('成员查询');
  const navigate = useNavigate();
  const isReviewer = useIsReviewer();
  const auth = useAppSelector((state) => state.auth);
  const [searchParams, setSearchParams] = useSearchParams();
  const [search, setSearch] = useState(searchParams.get('q') ?? '');
  const [generation, setGeneration] = useState<number | null>(
    searchParams.get('generation') ? Number(searchParams.get('generation')) : null,
  );
  const [branchId, setBranchId] = useState(searchParams.get('branchId') ?? '');
  const [createOpen, setCreateOpen] = useState(false);
  const [extra, setExtra] = useState<PersonSummary[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [moreLoading, setMoreLoading] = useState(false);
  const filterKey = `${search}|${generation}|${branchId}`;
  const lastKeyRef = useRef(filterKey);
  const debouncedSearch = useDebounce(search, 350);

  const branchesQuery = useAsync(
    async () => (await familyApi.listBranches()).items,
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) },
  );

  const query = useAsync(
    () =>
      personsApi.listPersons({
        q: debouncedSearch,
        generation: generation ?? undefined,
        branchId: branchId || undefined,
        limit: PAGE_SIZE,
      }),
    [auth.family?.id, debouncedSearch, generation, branchId],
    { enabled: Boolean(auth.family?.id) },
  );

  useEffect(() => {
    if (lastKeyRef.current !== filterKey) {
      lastKeyRef.current = filterKey;
      setExtra([]);
      setNextCursor(null);
    }
  }, [filterKey]);

  useEffect(() => {
    setNextCursor(query.data?.nextCursor ?? null);
    setExtra([]);
  }, [query.data]);

  useEffect(() => {
    const params = new URLSearchParams(searchParams);
    if (debouncedSearch.trim()) params.set('q', debouncedSearch.trim());
    else params.delete('q');
    if (generation) params.set('generation', String(generation));
    else params.delete('generation');
    if (branchId) params.set('branchId', branchId);
    else params.delete('branchId');
    setSearchParams(params, { replace: true });
    // 只在筛选值真正变化时同步地址栏，避免覆盖 create 等其他参数。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debouncedSearch, generation, branchId]);

  useEffect(() => {
    if (searchParams.get('q') && searchParams.get('q') !== search) {
      setSearch(searchParams.get('q') ?? '');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  useEffect(() => {
    if (searchParams.get('create') !== '1') return;
    if (isReviewer) {
      setCreateOpen(true);
    } else {
      Toast.info({ content: '只有族长或管理员可以直接新增成员', duration: 2.5 });
    }
    const params = new URLSearchParams(searchParams);
    params.delete('create');
    setSearchParams(params, { replace: true });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams, isReviewer]);

  const branchName = (id?: string) =>
    branchesQuery.data?.find((branch) => branch.id === id)?.name ?? '未分家支';

  const members = useMemo(
    () => [...(query.data?.items ?? []), ...extra],
    [extra, query.data],
  );

  const handleLoadMore = async () => {
    if (!nextCursor || moreLoading) return;
    setMoreLoading(true);
    try {
      const page = await personsApi.listPersons({
        q: debouncedSearch,
        generation: generation ?? undefined,
        branchId: branchId || undefined,
        cursor: nextCursor,
        limit: PAGE_SIZE,
      });
      setExtra((current) => [...current, ...page.items]);
      setNextCursor(page.nextCursor);
    } finally {
      setMoreLoading(false);
    }
  };

  const clearFilters = () => {
    setSearch('');
    setGeneration(null);
    setBranchId('');
  };

  const hasFilters = Boolean(debouncedSearch.trim() || generation || branchId);

  return (
    <div className="app-page members-page">
      <PageHeader
        eyebrow="FAMILY MEMBERS"
        title="成员查询"
        description={`在 ${auth.family?.name ?? '家族'} 中寻找一个人，查看世代、家支与生平档案。`}
        actions={
          <>
            <Button
              theme="light"
              icon={<IconBranch />}
              onClick={() => navigate('/tree')}
            >
              查看族谱树
            </Button>
            {isReviewer ? (
              <Button
                theme="solid"
                type="primary"
                icon={<IconPlus />}
                onClick={() => setCreateOpen(true)}
              >
                新增成员
              </Button>
            ) : null}
          </>
        }
      />

      <section className="members-overview">
        <div className="members-overview__item">
          <span className="members-overview__icon">
            <IconUserGroup />
          </span>
          <div>
            <strong>{auth.family?.memberCount ?? 0}</strong>
            <span>家族成员</span>
          </div>
        </div>
        <div className="members-overview__divider" />
        <div className="members-overview__item">
          <span className="members-overview__icon members-overview__icon--jade">
            <IconBranch />
          </span>
          <div>
            <strong>{auth.family?.branchCount ?? 0}</strong>
            <span>家族家支</span>
          </div>
        </div>
        <div className="members-overview__divider" />
        <div className="members-overview__item members-overview__item--query">
          <span>本次查询</span>
          <strong>{members.length}<small>{nextCursor ? '+' : ''} 人</small></strong>
        </div>
        {hasFilters ? (
          <button type="button" className="members-overview__clear" onClick={clearFilters}>
            清除筛选
          </button>
        ) : null}
      </section>

      <section className="members-toolbar">
        <div className="members-toolbar__search">
          <Input
            size="large"
            prefix={<IconSearch />}
            placeholder="搜索姓名、字号或别名"
            value={search}
            onChange={setSearch}
            showClear
            aria-label="搜索成员"
          />
        </div>
        <div className="members-toolbar__filters">
          <span className="members-toolbar__filter-label">
            <IconFilter size="small" />
            筛选
          </span>
          <Select
            placeholder="全部世代"
            value={generation ?? undefined}
            showClear
            onClear={() => setGeneration(null)}
            onChange={(value) => setGeneration(value ? Number(value) : null)}
            optionList={Array.from({ length: 15 }).map((_, index) => ({
              value: index + 1,
              label: `第${index + 1}世`,
            }))}
            className="members-toolbar__select"
            aria-label="按世代筛选"
          />
          <Select
            placeholder="全部家支"
            value={branchId || undefined}
            showClear
            filter
            onClear={() => setBranchId('')}
            onChange={(value) => setBranchId(typeof value === 'string' ? value : '')}
            optionList={(branchesQuery.data ?? []).map((branch) => ({
              value: branch.id,
              label: branch.name,
            }))}
            className="members-toolbar__select"
            aria-label="按家支筛选"
          />
        </div>
      </section>

      {query.error ? (
        <ErrorState description={query.error} onRetry={query.refresh} />
      ) : query.loading ? (
        <div className="member-grid">
          {Array.from({ length: 8 }).map((_, index) => (
            <div className="member-card member-card--skeleton" key={index}>
              <Skeleton.Avatar size="large" style={{ width: 58, height: 58 }} />
              <Skeleton.Title style={{ width: '52%' }} />
              <Skeleton.Paragraph rows={2} />
            </div>
          ))}
        </div>
      ) : members.length ? (
        <>
          <div className="member-grid">
            {members.map((person) => (
              <button
                type="button"
                className="member-card"
                key={person.id}
                onClick={() => navigate(`/persons/${person.id}`)}
              >
                <div className="member-card__head">
                  <PersonAvatar person={person} size={58} />
                  <div className="member-card__identity">
                    <div className="member-card__name-row">
                      <h3>{person.fullName}</h3>
                      <span className={cn('member-card__gender', person.gender)}>
                        {genderLabel(person.gender)}
                      </span>
                    </div>
                    <p>
                      {person.courtesyName || person.alias
                        ? [person.courtesyName, person.alias].filter(Boolean).join(' · ')
                        : '字号未录'}
                    </p>
                  </div>
                  <span className="member-card__arrow">
                    <IconArrowRight />
                  </span>
                </div>

                <div className="member-card__tags">
                  <StatusPill tone="blue">{person.generationName || generationShort(person.generationNo)}</StatusPill>
                  <StatusPill tone="gray">{branchName(person.branchId)}</StatusPill>
                  <LifeStatusPill status={person.lifeStatus} />
                </div>

                <div className="member-card__meta">
                  <span>
                    <em>生卒</em>
                    {person.birth || person.death
                      ? `${formatYear(person.birth) || '?'} — ${
                          person.lifeStatus === 'living' ? '' : formatYear(person.death) || '?'
                        }`
                      : lifeYears(person)}
                  </span>
                  <span>
                    <em>世代</em>
                    {person.generationLabel}
                  </span>
                </div>
              </button>
            ))}
          </div>
          <div className="members-more">
            {nextCursor ? (
              <Button theme="light" loading={moreLoading} onClick={handleLoadMore}>
                加载更多成员
              </Button>
            ) : (
              <span>已经看到全部 {members.length} 位成员</span>
            )}
          </div>
        </>
      ) : (
        <div className="members-empty surface-card">
          <EmptyState
            title={hasFilters ? '没有找到匹配的成员' : '家族中还没有成员'}
            description={
              hasFilters
                ? '试试更换姓名关键词、世代或家支。'
                : '添加第一位成员，让家族树开始生长。'
            }
            actionText={hasFilters ? '清除全部筛选' : isReviewer ? '添加第一位成员' : undefined}
            onAction={hasFilters ? clearFilters : isReviewer ? () => setCreateOpen(true) : undefined}
          />
        </div>
      )}

      <PersonFormDrawer
        visible={createOpen}
        mode="create"
        branches={branchesQuery.data ?? []}
        onClose={() => setCreateOpen(false)}
        onSaved={() => {
          setCreateOpen(false);
          query.refresh();
        }}
      />
    </div>
  );
}
