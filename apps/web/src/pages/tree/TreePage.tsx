import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  Background,
  BackgroundVariant,
  Controls,
  Panel,
  ReactFlow,
  ReactFlowProvider,
  useReactFlow,
} from '@xyflow/react';
import { Button, Input, Skeleton } from '@douyinfe/semi-ui';
import { SafeSelect as Select } from '@/components/SafeSelect';
import {
  IconArrowRight,
  IconBranch,
  IconClose,
  IconEdit,
  IconExpand,
  IconRefresh,
  IconSearch,
  IconUserAdd,
} from '@douyinfe/semi-icons';
import { useAppSelector } from '@/store/hooks';
import { useAsync } from '@/hooks/useAsync';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { useMediaQuery } from '@/hooks/useMediaQuery';
import { personsApi } from '@/api/persons';
import { familyApi } from '@/api/family';
import { PageHeader } from '@/components/PageHeader';
import { PersonAvatar } from '@/components/PersonAvatar';
import { ErrorState } from '@/components/ErrorState';
import { EmptyState } from '@/components/EmptyState';
import { SectionSkeleton } from '@/components/LoadingScreen';
import type { Person, PersonSummary } from '@/types/api';
import {
  buildTreeLayout,
  findPersonAnchor,
  findUnitForPerson,
  toChineseNumber,
  type FamilyConnection,
  type TreeLayoutResult,
} from './treeLayout';
import {
  TreeInteractionContext,
  treeEdgeTypes,
  treeNodeTypes,
  type FamilyFlowEdge,
  type FamilyUnitNode,
  type GenerationNode,
} from './TreeNodes';
import { cn } from '@/utils/cn';
import { dualCalendarDate, type DualCalendarDate } from '@/utils/calendar';
import { genderLabel, generationShort, lifeYears } from '@/utils/format';
import './TreePage.scss';

interface FocusRequest {
  personId: string;
  nonce: number;
}

export default function TreePage() {
  useDocumentTitle('族谱树');
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const auth = useAppSelector((state) => state.auth);
  const familyId = auth.family?.id;
  const initialFocusRef = useRef(searchParams.get('personId'));
  const [generation, setGeneration] = useState<number | 'all'>('all');
  const [branchId, setBranchId] = useState<string>('');
  const [search, setSearch] = useState('');
  const [searchOpen, setSearchOpen] = useState(false);
  const [selectedPerson, setSelectedPerson] = useState<PersonSummary | null>(null);
  const [focusRequest, setFocusRequest] = useState<FocusRequest | null>(null);

  const query = useAsync(
    async () => {
      const [tree, branches] = await Promise.all([personsApi.getTree(), familyApi.listBranches()]);
      return { tree, branches: branches.items };
    },
    [familyId],
    { enabled: Boolean(familyId) },
  );

  const layout = useMemo(() => {
    if (!query.data) return null;
    return buildTreeLayout(query.data.tree, {
      familySurname: auth.family?.surname ?? '',
    });
  }, [query.data, auth.family?.surname]);

  const branchName = useMemo(() => {
    if (!query.data) return () => '';
    const map = new Map(query.data.branches.map((branch) => [branch.id, branch.name]));
    return (id?: string) => (id ? map.get(id) ?? '' : '');
  }, [query.data]);

  const persons = useMemo(() => query.data?.tree.persons ?? [], [query.data]);
  const matchedPersons = useMemo(() => {
    const keyword = search.trim().toLowerCase();
    if (!keyword) return [];
    return persons
      .filter((person) => personMatchesSearch(person, keyword))
      .slice(0, 8);
  }, [persons, search]);

  useEffect(() => {
    const targetId = initialFocusRef.current;
    if (!targetId || !layout) return;
    const target = persons.find((person) => person.id === targetId);
    if (target) {
      setSelectedPerson(target);
      setFocusRequest({ personId: target.id, nonce: Date.now() });
    }
    initialFocusRef.current = null;
    const next = new URLSearchParams(searchParams);
    next.delete('personId');
    setSearchParams(next, { replace: true });
    // 只在首次进入页面时读取一次 personId，之后由树内交互控制选中状态。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [layout, persons]);

  const currentMemberId = auth.membership?.personId;
  const generationRange =
    layout && layout.generations.length
      ? `${layout.generations[0].label} — ${layout.generations[layout.generations.length - 1].label}`
      : '';

  const focusPerson = (person: PersonSummary) => {
    setSelectedPerson(person);
    setFocusRequest({ personId: person.id, nonce: Date.now() });
    setSearch('');
    setSearchOpen(false);
  };

  const locateSelf = () => {
    if (!currentMemberId) return;
    const person = persons.find((item) => item.id === currentMemberId);
    if (person) {
      focusPerson(person);
    }
  };

  const branchOptions = (query.data?.branches ?? []).map((branch) => ({
    label: branch.name,
    value: branch.id,
  }));

  return (
    <div className="app-page tree-page">
      <PageHeader
        eyebrow="FAMILY TREE"
        title="族谱树"
        description={
          layout
            ? `${auth.family?.name ?? ''} · ${persons.length} 位成员 · ${generationRange}`
            : '以世代为轴，看见一个家族如何生长。'
        }
        actions={
          <>
            {currentMemberId ? (
              <Button theme="borderless" icon={<IconExpand />} onClick={locateSelf}>
                定位到我
              </Button>
            ) : null}
            <Button theme="light" icon={<IconRefresh spin={query.refreshing} />} onClick={query.refresh}>
              刷新
            </Button>
            <Button
              theme="solid"
              type="primary"
              icon={<IconUserAdd />}
              onClick={() => navigate('/members?create=1')}
            >
              新增成员
            </Button>
          </>
        }
      />

      <section className="tree-toolbar surface-card">
        <div className="tree-toolbar__generations" aria-label="世代筛选">
          <button
            type="button"
            className={cn('tree-chip', generation === 'all' && 'is-active')}
            onClick={() => setGeneration('all')}
          >
            全部世代
          </button>
          {(layout?.generations ?? []).map((row) => (
            <button
              type="button"
              key={row.generation}
              className={cn('tree-chip', generation === row.generation && 'is-active')}
              onClick={() => setGeneration(row.generation)}
            >
              第{toChineseNumber(row.generation)}世
              <em>{row.count}</em>
            </button>
          ))}
        </div>

        <div className="tree-toolbar__tools">
          <Select
            className="tree-toolbar__branch"
            placeholder="全部家支"
            value={branchId || undefined}
            optionList={branchOptions}
            onChange={(value) => setBranchId(typeof value === 'string' ? value : '')}
            onClear={() => setBranchId('')}
            showClear
            filter
            aria-label="按家支筛选"
          />
          <div className="tree-search">
            <Input
              prefix={<IconSearch />}
              placeholder="在族谱中找一个人"
              value={search}
              onChange={(value) => {
                setSearch(value);
                setSearchOpen(true);
              }}
              onFocus={() => setSearchOpen(true)}
              onBlur={() => window.setTimeout(() => setSearchOpen(false), 140)}
              showClear
              aria-label="搜索族谱成员"
            />
            {searchOpen && search.trim() ? (
              <div className="tree-search__results">
                {matchedPersons.length ? (
                  matchedPersons.map((person) => (
                    <button
                      key={person.id}
                      type="button"
                      onMouseDown={(event) => event.preventDefault()}
                      onClick={() => focusPerson(person)}
                    >
                      <PersonAvatar person={person} size={28} />
                      <span>
                        <strong>{person.fullName}</strong>
                        <small>
                          {generationShort(person.generationNo)} · {branchName(person.branchId) || '未分支'}
                        </small>
                      </span>
                      <IconArrowRight size="small" />
                    </button>
                  ))
                ) : (
                  <p className="tree-search__empty">没有找到匹配的成员</p>
                )}
              </div>
            ) : null}
          </div>
        </div>
      </section>

      <section className="tree-canvas">
        {query.loading && !layout ? (
          <div className="tree-loading">
            <SectionSkeleton rows={4} />
            <span>正在铺开族谱长卷…</span>
          </div>
        ) : query.error ? (
          <div className="tree-state">
            <ErrorState description={query.error} onRetry={query.refresh} />
          </div>
        ) : layout && layout.units.length ? (
          <ReactFlowProvider>
            <TreeCanvas
              layout={layout}
              connections={layout.connections}
              generation={generation}
              branchId={branchId}
              search={search}
              selectedPerson={selectedPerson}
              focusRequest={focusRequest}
              currentPersonId={currentMemberId}
              onSelectPerson={(person) => {
                setSelectedPerson(person);
                setFocusRequest({ personId: person.id, nonce: Date.now() });
              }}
              onClearSelection={() => setSelectedPerson(null)}
              onFitAll={() => {
                setGeneration('all');
                setBranchId('');
              }}
            />
            {selectedPerson ? (
              <PersonPeek
                key={selectedPerson.id}
                summary={selectedPerson}
                branchName={branchName(selectedPerson.branchId)}
                onClose={() => setSelectedPerson(null)}
                onFocus={() =>
                  setFocusRequest({ personId: selectedPerson.id, nonce: Date.now() })
                }
                onOpenProfile={() => navigate(`/persons/${selectedPerson.id}`)}
                onOpenRelation={(id) => navigate(`/persons/${id}`)}
              />
            ) : null}
            <div className="tree-legend">
              <span>
                <i className="is-male" /> 男
              </span>
              <span>
                <i className="is-female" /> 女
              </span>
              <span>
                <i className="is-deceased" /> 已故
              </span>
              <span className="tree-legend__hint">滚轮缩放 · 拖动画布 · 点击人物查看</span>
            </div>
          </ReactFlowProvider>
        ) : (
          <div className="tree-state">
            <EmptyState
              title="族谱还是一张白纸"
              description="添加第一位成员，家族的树就从这里开始生长。"
              actionText="添加第一位成员"
              onAction={() => navigate('/members?create=1')}
            />
          </div>
        )}
      </section>

      <p className="tree-footnote">
        <IconBranch size="small" /> 族谱树按父母子女关系自动布局；夫妻并排显示，多配偶会共同置于同一家庭单元。
      </p>
    </div>
  );
}

function TreeCanvas({
  layout,
  connections,
  generation,
  branchId,
  search,
  selectedPerson,
  focusRequest,
  currentPersonId,
  onSelectPerson,
  onClearSelection,
  onFitAll,
}: {
  layout: TreeLayoutResult;
  connections: FamilyConnection[];
  generation: number | 'all';
  branchId: string;
  search: string;
  selectedPerson: PersonSummary | null;
  focusRequest: FocusRequest | null;
  currentPersonId?: string;
  onSelectPerson: (person: PersonSummary) => void;
  onClearSelection: () => void;
  onFitAll: () => void;
}) {
  const { fitView, setCenter } = useReactFlow();
  const isMobile = useMediaQuery('(max-width: 760px)');
  const keyword = search.trim();

  const matchedPersonIds = useMemo(() => {
    if (!keyword) return new Set<string>();
    return new Set(
      layout.units
        .flatMap((unit) => unit.members)
        .filter((person) => personMatchesSearch(person, keyword))
        .map((person) => person.id),
    );
  }, [keyword, layout]);

  const unitNodes = useMemo<FamilyUnitNode[]>(() => {
    return layout.units.map((unit) => {
      const generationDimmed = generation !== 'all' && unit.generation !== generation;
      const branchDimmed = Boolean(branchId) && !unit.members.some((member) => member.branchId === branchId);
      const searchDimmed =
        Boolean(keyword) && !unit.members.some((member) => personMatchesSearch(member, keyword));
      const dimmed = generationDimmed || branchDimmed || searchDimmed;
      return {
        id: unit.id,
        type: 'familyUnit',
        position: { x: unit.x, y: unit.y },
        data: { unit, dimmed },
        draggable: false,
        connectable: false,
        style: { width: unit.width, height: unit.height, zIndex: 2 },
      };
    });
  }, [branchId, generation, keyword, layout]);

  const generationNodes = useMemo<GenerationNode[]>(
    () =>
      layout.generations.map((row) => ({
        id: `generation-${row.generation}`,
        type: 'generation',
        position: { x: 24, y: row.y + 27 },
        data: {
          row,
          dimmed: generation !== 'all' && row.generation !== generation,
        },
        draggable: false,
        connectable: false,
        selectable: false,
        style: { width: 110, height: 44, zIndex: 1 },
      })),
    [generation, layout],
  );

  const flowEdges = useMemo<FamilyFlowEdge[]>(
    () =>
      connections.map((connection) => {
        const sourceUnit = layout.units.find((unit) => unit.id === connection.source);
        const targetUnit = layout.units.find((unit) => unit.id === connection.target);
        const dimmed =
          (generation !== 'all' &&
            sourceUnit?.generation !== generation &&
            targetUnit?.generation !== generation) ||
          Boolean(
            branchId &&
              !sourceUnit?.members.some((member) => member.branchId === branchId) &&
              !targetUnit?.members.some((member) => member.branchId === branchId),
          ) ||
          Boolean(
            keyword &&
              !sourceUnit?.members.some((member) => personMatchesSearch(member, keyword)) &&
              !targetUnit?.members.some((member) => personMatchesSearch(member, keyword)),
          );
        return {
          id: connection.id,
          source: connection.source,
          target: connection.target,
          sourceHandle: connection.sourceHandle,
          targetHandle: connection.targetHandle,
          type: 'family',
          data: { dimmed, gender: connection.gender },
          selectable: false,
        };
      }),
    [branchId, connections, generation, keyword, layout],
  );

  const nodes = useMemo(() => [...generationNodes, ...unitNodes], [generationNodes, unitNodes]);

  const interaction = useMemo(
    () => ({
      selectedPersonId: selectedPerson?.id ?? null,
      matchedPersonIds,
      onSelectPerson,
    }),
    [matchedPersonIds, onSelectPerson, selectedPerson?.id],
  );

  const initialFitDone = useRef(false);

  useEffect(() => {
    if (initialFitDone.current) return;
    const frame = window.requestAnimationFrame(() => {
      initialFitDone.current = true;
      // On a large tree the full fit can shrink cards to an unreadable size.
      // Start on the current member's family unit (or the middle generation),
      // and leave "查看全谱" available for the overview.
      const ownUnit = currentPersonId
        ? unitNodes.find((node) =>
            node.data.unit.members.some((member) => member.id === currentPersonId),
          )
        : null;
      const middleGeneration =
        layout.generations[Math.floor(layout.generations.length / 2)]?.generation;
      const middleUnit = unitNodes
        .filter(
          (node) => Math.abs(node.data.unit.generation - (middleGeneration ?? 1)) <= 1,
        )
        .slice()
        .sort((a, b) => b.data.unit.width - a.data.unit.width)[0];
      const target = ownUnit ?? middleUnit;
      if (target) {
        const unit = target.data.unit;
        const ownAnchor = currentPersonId
          ? findPersonAnchor(layout, currentPersonId)
          : undefined;
        setCenter(ownAnchor?.x ?? unit.x + unit.width / 2, ownAnchor?.y ?? unit.y + unit.height / 2, {
          zoom: isMobile ? 0.78 : 1,
          duration: 0,
        });
        return;
      }
      fitView({ padding: 0.2, duration: 0, maxZoom: 0.95 });
    });
    return () => window.cancelAnimationFrame(frame);
  }, [currentPersonId, fitView, isMobile, layout, setCenter, unitNodes]);

  useEffect(() => {
    if (generation === 'all') return;
    const targets = unitNodes.filter((node) => node.data.unit.generation === generation);
    if (!targets.length) return;
    const timer = window.setTimeout(() => {
      fitView({ nodes: targets, padding: 0.45, duration: 550, maxZoom: 1.1 });
    }, 50);
    return () => window.clearTimeout(timer);
  }, [fitView, generation, unitNodes]);

  useEffect(() => {
    if (!focusRequest) return;
    const unit = findUnitForPerson(layout, focusRequest.personId);
    if (!unit) return;
    const anchor = findPersonAnchor(layout, focusRequest.personId);
    const timer = window.setTimeout(() => {
      setCenter(anchor?.x ?? unit.x + unit.width / 2, anchor?.y ?? unit.y + unit.height / 2, {
        zoom: 1.06,
        duration: 650,
      });
    }, 60);
    return () => window.clearTimeout(timer);
  }, [focusRequest, layout, setCenter]);

  const handleFitAll = () => {
    onFitAll();
    window.requestAnimationFrame(() => {
      fitView({ padding: 0.18, duration: 500, maxZoom: 0.95 });
    });
  };

  return (
    <TreeInteractionContext.Provider value={interaction}>
      <ReactFlow
        nodes={nodes}
        edges={flowEdges}
        nodeTypes={treeNodeTypes}
        edgeTypes={treeEdgeTypes}
        minZoom={0.18}
        maxZoom={1.85}
        nodesDraggable={false}
        nodesConnectable={false}
        panOnScroll={false}
        zoomOnScroll
        zoomOnPinch
        zoomOnDoubleClick={false}
        preventScrolling
        proOptions={{ hideAttribution: false }}
        onPaneClick={onClearSelection}
      >
        <Background
          variant={BackgroundVariant.Dots}
          gap={22}
          size={1}
          color="rgba(84, 100, 109, 0.16)"
        />
        <Controls position="top-right" showInteractive={false} />
        <Panel position="top-left" className="tree-canvas__panel">
          <span>
            {layout.units.length} 个家庭 · {layout.generations.reduce((sum, row) => sum + row.count, 0)} 人
          </span>
          <button type="button" onClick={handleFitAll}>
            查看全谱
          </button>
        </Panel>
      </ReactFlow>
    </TreeInteractionContext.Provider>
  );
}

function PersonPeek({
  summary,
  branchName,
  onClose,
  onFocus,
  onOpenProfile,
  onOpenRelation,
}: {
  summary: PersonSummary;
  branchName: string;
  onClose: () => void;
  onFocus: () => void;
  onOpenProfile: () => void;
  onOpenRelation: (personId: string) => void;
}) {
  const detailQuery = useAsync(
    () => personsApi.getPerson(summary.id),
    [summary.id],
    { enabled: Boolean(summary.id) },
  );
  const person: Person | null = detailQuery.data;
  const birth = dualCalendarDate(summary.birth);
  const death = dualCalendarDate(summary.death);

  return (
    <aside className="tree-peek" aria-label={`${summary.fullName} 简介`}>
      <button type="button" className="tree-peek__close" onClick={onClose} aria-label="关闭">
        <IconClose />
      </button>
      <div className="tree-peek__head">
        <PersonAvatar person={summary} size={62} ring eager />
        <div>
          <h3>{summary.fullName}</h3>
          <p>
            {generationShort(summary.generationNo)}
            {summary.generationName ? ` · ${summary.generationName}字辈` : ''}
          </p>
          <span className={cn('tree-peek__life', summary.lifeStatus === 'living' && 'is-living')}>
            {lifeYears(summary)} · {branchName || '未分家支'}
          </span>
        </div>
      </div>

      {detailQuery.loading ? (
        <Skeleton placeholder={<Skeleton.Paragraph rows={4} />} loading />
      ) : (
        <div className="tree-peek__body">
          <div className="tree-peek__stats">
            <div>
              <span>性别</span>
              <strong>{genderLabel(summary.gender)}</strong>
            </div>
            <div>
              <span>生肖</span>
              <strong>
                {[birth?.ganzhiYear, birth?.zodiac].filter(Boolean).join(' · ') || '未详'}
              </strong>
            </div>
            <div>
              <span>身份</span>
              <strong>{person?.occupation || '未记录'}</strong>
            </div>
          </div>

          <div className="tree-peek__calendar">
            <PeekCalendarLine label="出生" date={birth} />
            {summary.lifeStatus === 'deceased' || summary.death ? (
              <PeekCalendarLine label="逝世" date={death} />
            ) : null}
          </div>

          {person?.biography ? (
            <p className="tree-peek__bio clamp-4">{person.biography}</p>
          ) : (
            <p className="tree-peek__bio is-empty">这个人的故事还等待被补充。</p>
          )}

          {person && (person.parents?.length || person.spouses?.length || person.children?.length) ? (
            <div className="tree-peek__relations">
              <p className="tree-peek__section-title">亲属关系</p>
              {[...(person.parents ?? []), ...(person.spouses ?? [])]
                .slice(0, 4)
                .map((relative) => (
                  <button
                    type="button"
                    key={relative.edgeId}
                    onClick={() => onOpenRelation(relative.personId)}
                  >
                    <span>{relative.relation}</span>
                    <strong>{relative.fullName}</strong>
                    <IconArrowRight size="small" />
                  </button>
                ))}
              {person.children?.length ? (
                <button
                  type="button"
                  className="tree-peek__children"
                  onClick={onOpenProfile}
                >
                  <span>子女</span>
                  <strong>
                    {person.children
                      .slice(0, 3)
                      .map((child) => child.fullName)
                      .join('、')}
                    {person.children.length > 3 ? ` 等 ${person.children.length} 人` : ''}
                  </strong>
                  <IconArrowRight size="small" />
                </button>
              ) : null}
            </div>
          ) : null}
        </div>
      )}

      <div className="tree-peek__actions">
        <Button theme="light" icon={<IconExpand />} onClick={onFocus}>
          居中
        </Button>
        <Button theme="light" type="primary" icon={<IconEdit />} onClick={onOpenProfile}>
          完整档案
        </Button>
      </div>
    </aside>
  );
}

function PeekCalendarLine({ label, date }: { label: string; date: DualCalendarDate | null }) {
  if (!date) return null;
  return (
    <div className="tree-peek__calendar-line">
      <span>{label}</span>
      <div>
        <strong>{date.primary}</strong>
        {date.secondary ? <small>{date.secondary}</small> : null}
      </div>
    </div>
  );
}

function personMatchesSearch(person: PersonSummary, keyword: string): boolean {
  const lower = keyword.toLowerCase();
  return [person.fullName, person.courtesyName, person.alias]
    .filter(Boolean)
    .some((value) => value!.toLowerCase().includes(lower));
}
