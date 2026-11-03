import { useMemo, useState, type ReactNode } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Modal, Skeleton, Toast } from '@douyinfe/semi-ui';
import {
  IconArrowLeft,
  IconArrowRight,
  IconBranch,
  IconCalendar,
  IconDelete,
  IconEdit,
  IconExpand,
  IconHome,
  IconImage,
  IconMapPin,
  IconMember,
  IconUser,
} from '@douyinfe/semi-icons';
import { useAppSelector, useIsReviewer } from '@/store/hooks';
import { useAsync } from '@/hooks/useAsync';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { personsApi } from '@/api/persons';
import { contentApi } from '@/api/content';
import { familyApi } from '@/api/family';
import { PersonAvatar } from '@/components/PersonAvatar';
import { AuthedImage } from '@/components/AuthedImage';
import { SectionCard } from '@/components/SectionCard';
import { EmptyState } from '@/components/EmptyState';
import { ErrorState } from '@/components/ErrorState';
import { LifeStatusPill, StatusPill } from '@/components/StatusPill';
import { SectionSkeleton } from '@/components/LoadingScreen';
import { PersonFormDrawer } from '@/components/PersonFormDrawer';
import { ProfileRequestDrawer } from '@/components/ProfileRequestDrawer';
import type { PartialDate, Photo, Relative } from '@/types/api';
import { dualCalendarDate } from '@/utils/calendar';
import {
  formatDate,
  formatDateTime,
  genderLabel,
  generationShort,
  lifeYears,
  roleLabel,
} from '@/utils/format';
import './PersonDetailPage.scss';

export default function PersonDetailPage() {
  const { personId = '' } = useParams();
  const navigate = useNavigate();
  const isReviewer = useIsReviewer();
  const auth = useAppSelector((state) => state.auth);
  const [editOpen, setEditOpen] = useState(false);
  const [requestOpen, setRequestOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [activePhoto, setActivePhoto] = useState<Photo | null>(null);

  const query = useAsync(
    () => personsApi.getPerson(personId),
    [personId],
    { enabled: Boolean(personId) },
  );
  const branchesQuery = useAsync(
    async () => (await familyApi.listBranches()).items,
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) },
  );
  const photosQuery = useAsync(
    async () => (await contentApi.listPhotos([], personId)).items,
    [personId],
    { enabled: Boolean(personId) },
  );
  const storiesQuery = useAsync(
    async () => (await contentApi.listStories()).items,
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) },
  );

  const person = query.data;
  useDocumentTitle(person ? person.fullName : '人物档案');

  const branchName = useMemo(
    () =>
      branchesQuery.data?.find((branch) => branch.id === person?.branchId)?.name ??
      '未分家支',
    [branchesQuery.data, person?.branchId],
  );

  const relatedStories = useMemo(
    () => (storiesQuery.data ?? []).filter((story) => story.personId === personId),
    [personId, storiesQuery.data],
  );

  const isSelf = auth.membership?.personId === personId;

  const handleEdit = () => {
    if (!person) return;
    if (isReviewer) setEditOpen(true);
    else setRequestOpen(true);
  };

  const handleDelete = async () => {
    if (!person) return;
    setDeleting(true);
    try {
      await personsApi.deletePerson(person.id);
      Toast.success({ content: '人物已从族谱中移除，历史审核记录仍会保留', duration: 2.8 });
      navigate('/members', { replace: true });
    } finally {
      setDeleting(false);
    }
  };

  if (query.loading) {
    return (
      <div className="app-page person-page">
        <div className="person-loading surface-card">
          <Skeleton.Avatar style={{ width: 94, height: 94 }} />
          <Skeleton.Title style={{ width: 220 }} />
          <Skeleton.Paragraph rows={2} />
        </div>
      </div>
    );
  }

  if (query.error || !person) {
    return (
      <div className="app-page person-page">
        <ErrorState
          title="没有找到这位成员"
          description={query.error ?? '人物可能已被归档，或不属于当前家族。'}
          onRetry={query.refresh}
        />
      </div>
    );
  }

  return (
    <div className="app-page person-page">
      <div className="person-back">
        <button type="button" onClick={() => navigate('/members')}>
          <IconArrowLeft /> 返回成员
        </button>
        <span>人物档案</span>
        {isSelf ? <em>这是你绑定的家族人物</em> : null}
      </div>

      <section className="person-hero">
        <div className="person-hero__watermark" aria-hidden>
          {person.surname || '族'}
        </div>
        <div className="person-hero__avatar">
          <PersonAvatar person={person} size={108} ring eager />
          <span className="person-hero__seal">第{person.generationNo}世</span>
        </div>
        <div className="person-hero__identity">
          <p className="eyebrow">PERSON ARCHIVE · {person.generationLabel}</p>
          <div className="person-hero__name-row">
            <h1>{person.fullName}</h1>
            <LifeStatusPill status={person.lifeStatus} />
            {person.generationName ? <StatusPill tone="violet">{person.generationName}字辈</StatusPill> : null}
          </div>
          <p className="person-hero__sub">
            {[person.courtesyName, person.alias].filter(Boolean).join(' · ') || '字号未录'}
            {person.occupation ? ` · ${person.occupation}` : ''}
          </p>
          <p className="person-hero__bio clamp-2">
            {person.biography || '这个人的生平还留着一页空白，等待家族成员一起补全。'}
          </p>
          <div className="person-hero__actions">
            <Button theme="solid" type="primary" icon={<IconEdit />} onClick={handleEdit}>
              {isReviewer ? '编辑资料' : '申请修改'}
            </Button>
            <Button
              theme="light"
              icon={<IconExpand />}
              onClick={() => navigate(`/tree?personId=${person.id}`)}
            >
              在族谱中查看
            </Button>
          </div>
        </div>
        <div className="person-hero__meta">
          <div>
            <span>生卒</span>
            <strong>{lifeYears(person)}</strong>
          </div>
          <div>
            <span>籍贯</span>
            <strong>{person.birthPlace || '未记录'}</strong>
          </div>
          <div>
            <span>家支</span>
            <strong>{branchName}</strong>
          </div>
        </div>
      </section>

      <div className="person-layout">
        <div className="person-layout__main">
          <SectionCard eyebrow="LIFE STORY" title="生平记述">
            {person.biography ? (
              <div className="person-bio">{person.biography}</div>
            ) : (
              <EmptyState
                compact
                title="这一页还空着"
                description="如果你了解这个人的故事，可以提交资料申请，让后人也看见。"
                actionText={isReviewer ? '编辑资料' : '申请补充'}
                onAction={handleEdit}
              />
            )}
          </SectionCard>

          <SectionCard eyebrow="RELATIONSHIPS" title="亲属关系">
            <div className="relation-board">
              <RelationGroup
                title="父母"
                relations={person.parents ?? []}
                empty="父母未录"
                onOpen={(relative) => navigate(`/persons/${relative.personId}`)}
              />
              <RelationGroup
                title="配偶"
                relations={person.spouses ?? []}
                empty="暂无配偶记录"
                onOpen={(relative) => navigate(`/persons/${relative.personId}`)}
              />
              <RelationGroup
                title="子女"
                relations={person.children ?? []}
                empty="暂无子女记录"
                onOpen={(relative) => navigate(`/persons/${relative.personId}`)}
              />
              <RelationGroup
                title="兄弟姐妹"
                relations={person.siblings ?? []}
                empty="暂无兄弟姐妹记录"
                onOpen={(relative) => navigate(`/persons/${relative.personId}`)}
              />
            </div>
          </SectionCard>

          <SectionCard
            eyebrow="FAMILY PHOTOS"
            title="个人影像"
            extra={
              <button type="button" className="text-link" onClick={() => navigate('/gallery')}>
                家族相册 <IconArrowRight size="small" />
              </button>
            }
          >
            {photosQuery.loading ? (
              <SectionSkeleton rows={2} />
            ) : photosQuery.data?.length ? (
              <div className="person-photo-grid">
                {photosQuery.data.map((photo) => (
                  <button
                    type="button"
                    className="person-photo"
                    key={photo.id}
                    onClick={() => setActivePhoto(photo)}
                  >
                    <AuthedImage
                      path={photo.contentPath}
                      alt={photo.caption || `${person.fullName} 的照片`}
                      fallback={<IconImage />}
                    />
                    {photo.caption ? <span>{photo.caption}</span> : null}
                  </button>
                ))}
              </div>
            ) : (
              <EmptyState
                compact
                title="还没有关联到个人的照片"
                description="上传照片并标记这位成员后，影像会出现在这里。"
                actionText="前往家族相册"
                onAction={() => navigate('/gallery')}
              />
            )}
          </SectionCard>

          {relatedStories.length ? (
            <SectionCard eyebrow="FAMILY STORIES" title="与他/她有关的故事">
              <div className="person-story-list">
                {relatedStories.map((story) => (
                  <button
                    type="button"
                    key={story.id}
                    onClick={() => navigate(`/stories/${story.id}`)}
                  >
                    <span className="person-story-list__mark">卷</span>
                    <span>
                      <strong>{story.title}</strong>
                      <p className="clamp-1">{story.body}</p>
                    </span>
                    <small>{formatDate(story.createdAt)}</small>
                  </button>
                ))}
              </div>
            </SectionCard>
          ) : null}
        </div>

        <aside className="person-layout__side">
          <SectionCard eyebrow="ARCHIVE" title="档案信息">
            <dl className="person-info-list">
              <InfoRow icon={<IconUser />} label="性别" value={genderLabel(person.gender)} />
              <InfoRow
                icon={<IconBranch />}
                label="世代"
                value={`${generationShort(person.generationNo)}${person.generationName ? ` · ${person.generationName}字辈` : ''}`}
              />
              <InfoRow
                icon={<IconMember />}
                label="排行"
                value={person.birthOrder ? `第 ${person.birthOrder} 位` : '未记录'}
              />
              <InfoRow
                icon={<IconCalendar />}
                label="出生"
                value={<CalendarValue date={person.birth} />}
              />
              <InfoRow
                icon={<IconCalendar />}
                label="逝世"
                value={
                  person.lifeStatus === 'living' ? '在世' : <CalendarValue date={person.death} />
                }
              />
              <InfoRow icon={<IconMapPin />} label="籍贯" value={person.birthPlace || '未记录'} />
              <InfoRow icon={<IconHome />} label="现居" value={person.residence || '未记录'} />
              <InfoRow icon={<IconUser />} label="职业" value={person.occupation || '未记录'} />
              <InfoRow icon={<IconBranch />} label="家支" value={branchName} />
            </dl>
            <div className="person-info-foot">
              <span>档案更新 {formatDateTime(person.updatedAt)}</span>
              <span>v{person.version}</span>
            </div>
          </SectionCard>

          <SectionCard eyebrow="ACTIONS" title="档案操作">
            <div className="person-action-list">
              <button type="button" onClick={() => navigate(`/tree?personId=${person.id}`)}>
                <span className="person-action-list__icon">
                  <IconBranch />
                </span>
                <span>
                  <strong>在族谱中定位</strong>
                  <small>查看此人周围的世代与亲属</small>
                </span>
                <IconArrowRight size="small" />
              </button>
              <button type="button" onClick={handleEdit}>
                <span className="person-action-list__icon person-action-list__icon--gold">
                  <IconEdit />
                </span>
                <span>
                  <strong>{isReviewer ? '编辑完整资料' : '提交资料申请'}</strong>
                  <small>{isReviewer ? '修改会立即写入族谱' : '由族长或管理员审核后写入'}</small>
                </span>
                <IconArrowRight size="small" />
              </button>
              <button type="button" onClick={() => navigate('/gallery')}>
                <span className="person-action-list__icon person-action-list__icon--jade">
                  <IconImage />
                </span>
                <span>
                  <strong>查看家族影像</strong>
                  <small>浏览与标记家族照片</small>
                </span>
                <IconArrowRight size="small" />
              </button>
              {isReviewer ? (
                <button
                  type="button"
                  className="is-danger"
                  onClick={() => setDeleteOpen(true)}
                >
                  <span className="person-action-list__icon person-action-list__icon--danger">
                    <IconDelete />
                  </span>
                  <span>
                    <strong>从族谱中移除</strong>
                    <small>软删除，保留审计记录</small>
                  </span>
                  <IconArrowRight size="small" />
                </button>
              ) : null}
            </div>
          </SectionCard>

          <div className="person-side-note">
            <span>家族档案</span>
            <p>{auth.family?.motto || '寻根溯源，传承家风。'}</p>
            <small>
              {auth.family?.name} · {roleLabel(auth.membership?.role)}
            </small>
          </div>
        </aside>
      </div>

      {isReviewer ? (
        <PersonFormDrawer
          visible={editOpen}
          mode="edit"
          person={person}
          branches={branchesQuery.data ?? []}
          onClose={() => setEditOpen(false)}
          onSaved={() => {
            setEditOpen(false);
            query.refresh();
          }}
        />
      ) : null}

      <ProfileRequestDrawer
        visible={requestOpen}
        person={person}
        onClose={() => setRequestOpen(false)}
        onSubmitted={() => {
          setRequestOpen(false);
        }}
      />

      <Modal
        visible={deleteOpen}
        title="从族谱中移除这位成员？"
        onCancel={() => setDeleteOpen(false)}
        onOk={handleDelete}
        okText="确认移除"
        cancelText="再想想"
        confirmLoading={deleting}
        type="warning"
        className="person-delete-modal"
      >
        <p>
          「{person.fullName}」将从当前族谱中移除，亲属关系会结束，账号绑定和照片标记也会解除。
          历史审计仍会保留，但这个操作不应被用于临时隐藏成员。
        </p>
      </Modal>

      <Modal
        visible={Boolean(activePhoto)}
        footer={null}
        centered
        width={860}
        className="photo-lightbox"
        onCancel={() => setActivePhoto(null)}
      >
        {activePhoto ? (
          <div className="photo-lightbox__body">
            <AuthedImage
              path={activePhoto.contentPath}
              alt={activePhoto.caption || '家族照片'}
              fit="contain"
              className="photo-lightbox__image"
              fallback={<IconImage />}
              eager
            />
            <div className="photo-lightbox__meta">
              <strong>{activePhoto.caption || '未命名影像'}</strong>
              <span>
                {formatDate(activePhoto.takenAt || activePhoto.createdAt)}
                {activePhoto.persons?.length
                  ? ` · ${activePhoto.persons.map((entry) => entry.fullName).join('、')}`
                  : ''}
              </span>
            </div>
          </div>
        ) : null}
      </Modal>
    </div>
  );
}

function CalendarValue({ date }: { date?: PartialDate | null }) {
  const info = dualCalendarDate(date);
  if (!info) return <>未记录</>;
  return (
    <span className="person-calendar-value">
      <span>{info.primary}</span>
      {info.secondary ? <small>{info.secondary}</small> : null}
    </span>
  );
}

function InfoRow({
  icon,
  label,
  value,
}: {
  icon: ReactNode;
  label: string;
  value: ReactNode;
}) {
  return (
    <div className="person-info-row">
      <dt>
        <span>{icon}</span>
        {label}
      </dt>
      <dd>{value || '未记录'}</dd>
    </div>
  );
}

function RelationGroup({
  title,
  relations,
  empty,
  onOpen,
}: {
  title: string;
  relations: Relative[];
  empty: string;
  onOpen: (relative: Relative) => void;
}) {
  return (
    <div className="relation-group">
      <header>
        <h3>{title}</h3>
        <span>{relations.length || ''}</span>
      </header>
      {relations.length ? (
        <div className="relation-group__list">
          {relations.map((relative) => (
            <button
              type="button"
              key={`${relative.edgeId}-${relative.personId}`}
              onClick={() => onOpen(relative)}
            >
              <PersonAvatar
                person={{ id: relative.personId, fullName: relative.fullName, hasAvatar: false }}
                size={37}
              />
              <span>
                <strong>{relative.fullName}</strong>
                <small>{relative.relation}</small>
              </span>
              <IconArrowRight size="small" />
            </button>
          ))}
        </div>
      ) : (
        <p className="relation-group__empty">{empty}</p>
      )}
    </div>
  );
}
