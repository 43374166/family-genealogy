import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Input } from '@douyinfe/semi-ui';
import {
  IconArrowRight,
  IconBookOpenStroked,
  IconEdit,
  IconImage,
  IconPlus,
  IconSearch,
} from '@douyinfe/semi-icons';
import { useAppSelector } from '@/store/hooks';
import { useAsync } from '@/hooks/useAsync';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { contentApi } from '@/api/content';
import { PageHeader } from '@/components/PageHeader';
import { EmptyState } from '@/components/EmptyState';
import { ErrorState } from '@/components/ErrorState';
import { SectionSkeleton } from '@/components/LoadingScreen';
import { AuthedImage } from '@/components/AuthedImage';
import { StoryEditorDrawer } from '@/components/StoryEditorDrawer';
import type { Story } from '@/types/api';
import { formatDate, fromNow } from '@/utils/format';
import { cn } from '@/utils/cn';
import './StoriesPage.scss';

export default function StoriesPage() {
  useDocumentTitle('家族故事');
  const navigate = useNavigate();
  const auth = useAppSelector((state) => state.auth);
  const [search, setSearch] = useState('');
  const [editorOpen, setEditorOpen] = useState(false);

  const query = useAsync(
    async () => (await contentApi.listStories()).items,
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) },
  );

  const stories = useMemo(() => query.data ?? [], [query.data]);
  const filtered = useMemo(() => {
    const keyword = search.trim().toLowerCase();
    if (!keyword) return stories;
    return stories.filter((story) =>
      [story.title, story.body, story.authorName, story.personName]
        .filter(Boolean)
        .some((value) => value!.toLowerCase().includes(keyword)),
    );
  }, [search, stories]);

  const contributors = useMemo(
    () => new Set(stories.map((story) => story.authorUserId)).size,
    [stories],
  );
  const photoCount = useMemo(
    () => stories.reduce((sum, story) => sum + (story.photos?.length ?? 0), 0),
    [stories],
  );

  const featured = filtered.find((story) => story.photos?.length) ?? filtered[0];

  return (
    <div className="app-page stories-page">
      <PageHeader
        eyebrow="FAMILY STORIES"
        title="家族故事"
        description="把口耳相传的往事写下来，让家族记忆不再只停留在饭桌上。"
        actions={
          <Button theme="solid" type="primary" icon={<IconPlus />} onClick={() => setEditorOpen(true)}>
            写一个故事
          </Button>
        }
      />

      <section className="stories-overview">
        <div className="stories-overview__quote">
          <span>“</span>
          <p>一家之史，即一国史之根。</p>
        </div>
        <div className="stories-overview__stats">
          <div>
            <strong>{stories.length}</strong>
            <span>篇故事</span>
          </div>
          <div>
            <strong>{contributors}</strong>
            <span>位讲述者</span>
          </div>
          <div>
            <strong>{photoCount}</strong>
            <span>张配图</span>
          </div>
        </div>
        <div className="stories-overview__search">
          <Input
            prefix={<IconSearch />}
            placeholder="搜索故事标题、人物或正文"
            value={search}
            onChange={setSearch}
            showClear
            aria-label="搜索家族故事"
          />
        </div>
      </section>

      {query.error ? (
        <ErrorState description={query.error} onRetry={query.refresh} />
      ) : query.loading ? (
        <div className="stories-layout">
          <div className="story-feature story-feature--skeleton">
            <SectionSkeleton rows={4} />
          </div>
          <div className="stories-grid">
            {Array.from({ length: 3 }).map((_, index) => (
              <div className="story-card story-card--skeleton" key={index}>
                <SectionSkeleton rows={3} />
              </div>
            ))}
          </div>
        </div>
      ) : !stories.length ? (
        <div className="surface-card stories-empty">
          <EmptyState
            title="第一个故事，等你来讲"
            description="可以写祖父的旧事，也可以写这个家族最近的一次团聚。"
            actionText="写一个故事"
            onAction={() => setEditorOpen(true)}
          />
        </div>
      ) : !filtered.length ? (
        <div className="surface-card stories-empty">
          <EmptyState
            title="没有找到这个故事"
            description="换一个关键词试试，或者直接写下新的故事。"
            actionText="清除搜索"
            onAction={() => setSearch('')}
          />
        </div>
      ) : (
        <div className="stories-layout">
          {featured ? <FeatureStory story={featured} onClick={() => navigate(`/stories/${featured.id}`)} /> : null}
          <div className="stories-grid">
            {filtered
              .filter((story) => story.id !== featured?.id)
              .map((story, index) => (
                <StoryCard
                  key={story.id}
                  story={story}
                  index={index}
                  onClick={() => navigate(`/stories/${story.id}`)}
                />
              ))}
            <button type="button" className="story-write-card" onClick={() => setEditorOpen(true)}>
              <span className="story-write-card__mark">
                <IconEdit />
              </span>
              <strong>写下新的家族故事</strong>
              <p>一个人、一件旧物、一次团聚，都可以成为故事的开头。</p>
              <span className="story-write-card__cta">
                开始书写 <IconArrowRight size="small" />
              </span>
            </button>
          </div>
        </div>
      )}

      <StoryEditorDrawer
        visible={editorOpen}
        onClose={() => setEditorOpen(false)}
        onSaved={(story) => {
          setEditorOpen(false);
          query.refresh();
          navigate(`/stories/${story.id}`);
        }}
      />
    </div>
  );
}

function FeatureStory({ story, onClick }: { story: Story; onClick: () => void }) {
  return (
    <button type="button" className="story-feature" onClick={onClick}>
      <div className="story-feature__media">
        {story.photos?.length ? (
          <AuthedImage path={story.photos[0].contentPath} alt={story.title} eager />
        ) : (
          <div className="story-feature__paper">
            <span>家</span>
            <i>族谱 · 故事</i>
          </div>
        )}
      </div>
      <div className="story-feature__content">
        <span className="story-feature__label">
          <IconBookOpenStroked size="small" /> 卷首故事
        </span>
        <h2>{story.title}</h2>
        <p className="clamp-4">{story.body}</p>
        <div className="story-feature__meta">
          <span>{story.personName ? `讲述 ${story.personName}` : story.authorName}</span>
          <span>{formatDate(story.createdAt)}</span>
        </div>
        <span className="story-feature__cta">
          展开阅读 <IconArrowRight size="small" />
        </span>
      </div>
    </button>
  );
}

function StoryCard({ story, index, onClick }: { story: Story; index: number; onClick: () => void }) {
  const hasPhoto = Boolean(story.photos?.length);
  return (
    <button
      type="button"
      className={cn('story-card', hasPhoto && 'story-card--with-photo', `story-card--tone-${index % 3}`)}
      onClick={onClick}
    >
      {hasPhoto ? (
        <div className="story-card__cover">
          <AuthedImage path={story.photos![0].contentPath} alt={story.title} />
          {story.photos!.length > 1 ? (
            <span className="story-card__photo-count">
              <IconImage size="small" /> {story.photos!.length}
            </span>
          ) : null}
        </div>
      ) : (
        <div className="story-card__mark">
          <span>{index % 2 ? '忆' : '家'}</span>
          <i>FAMILY STORY</i>
        </div>
      )}
      <div className="story-card__body">
        <span className="story-card__label">{story.personName ? `关于 ${story.personName}` : '家族记忆'}</span>
        <h3>{story.title}</h3>
        <p className="clamp-2">{story.body}</p>
        <div className="story-card__meta">
          <span>{story.authorName}</span>
          <span>{fromNow(story.createdAt)}</span>
        </div>
      </div>
    </button>
  );
}
