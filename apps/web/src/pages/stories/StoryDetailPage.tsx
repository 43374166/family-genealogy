import { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Modal, Toast } from '@douyinfe/semi-ui';
import {
  IconArrowLeft,
  IconArrowRight,
  IconDelete,
  IconEdit,
  IconImage,
  IconUser,
} from '@douyinfe/semi-icons';
import { useAppSelector, useIsReviewer } from '@/store/hooks';
import { useAsync } from '@/hooks/useAsync';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { contentApi } from '@/api/content';
import { AuthedImage } from '@/components/AuthedImage';
import { ErrorState } from '@/components/ErrorState';
import { StoryEditorDrawer } from '@/components/StoryEditorDrawer';
import type { Photo, Story } from '@/types/api';
import { formatDate, formatDateTime } from '@/utils/format';
import './StoryDetailPage.scss';

export default function StoryDetailPage() {
  const { storyId = '' } = useParams();
  const navigate = useNavigate();
  const auth = useAppSelector((state) => state.auth);
  const isReviewer = useIsReviewer();
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [activePhoto, setActivePhoto] = useState<Photo | null>(null);

  const query = useAsync(
    () => contentApi.getStory(storyId),
    [storyId],
    { enabled: Boolean(storyId) },
  );
  const story: Story | null = query.data;
  useDocumentTitle(story?.title ?? '故事详情');

  const canManage =
    isReviewer || (story ? story.authorUserId === auth.user?.id : false);

  const handleDelete = async () => {
    if (!story) return;
    setDeleting(true);
    try {
      await contentApi.deleteStory(story.id);
      Toast.success({ content: '故事已从家族记忆中移除', duration: 2.3 });
      navigate('/stories', { replace: true });
    } finally {
      setDeleting(false);
    }
  };

  if (query.loading) {
    return (
      <div className="app-page story-detail-page">
        <div className="story-reading-loading surface-card">
          <span />
          <span />
          <span />
        </div>
      </div>
    );
  }

  if (query.error || !story) {
    return (
      <div className="app-page story-detail-page">
        <ErrorState
          title="没有找到这个故事"
          description={query.error ?? '故事可能已被移除，或不属于当前家族。'}
          onRetry={query.refresh}
        />
      </div>
    );
  }

  const paragraphs = story.body.split(/\n+/).filter((line) => line.trim());

  return (
    <div className="app-page story-detail-page">
      <div className="story-detail-back">
        <button type="button" onClick={() => navigate('/stories')}>
          <IconArrowLeft /> 返回故事
        </button>
        <span>卷 · {formatDate(story.createdAt, 'YYYY')}</span>
        {canManage ? (
          <div className="story-detail-back__actions">
            <Button theme="borderless" icon={<IconEdit />} onClick={() => setEditOpen(true)}>
              编辑
            </Button>
            <Button theme="borderless" type="danger" icon={<IconDelete />} onClick={() => setDeleteOpen(true)}>
              删除
            </Button>
          </div>
        ) : null}
      </div>

      <article className="story-article">
        <header className="story-article__header">
          <p className="eyebrow">FAMILY STORY · {story.personName || '家族记忆'}</p>
          <h1>{story.title}</h1>
          <div className="story-article__meta">
            <span>
              <IconUser size="small" /> {story.authorName}
            </span>
            <span>{formatDateTime(story.createdAt)}</span>
            {story.photos?.length ? (
              <span>
                <IconImage size="small" /> {story.photos.length} 张照片
              </span>
            ) : null}
          </div>
          {story.personId && story.personName ? (
            <button
              type="button"
              className="story-article__person"
              onClick={() => navigate(`/persons/${story.personId}`)}
            >
              阅读 {story.personName} 的人物档案 <IconArrowRight size="small" />
            </button>
          ) : null}
        </header>

        <div className="story-article__divider">
          <span>卷</span>
        </div>

        <div className="story-article__body">
          {paragraphs.map((paragraph, index) => (
            <p key={index}>{paragraph}</p>
          ))}
        </div>

        {story.photos?.length ? (
          <div className="story-article__photos">
            {story.photos.map((photo) => (
              <button
                type="button"
                key={photo.id}
                onClick={() => setActivePhoto(photo)}
              >
                <AuthedImage path={photo.contentPath} alt={photo.caption || story.title} />
                {photo.caption ? <span>{photo.caption}</span> : null}
              </button>
            ))}
          </div>
        ) : null}

        <footer className="story-article__footer">
          <span>家 族 族 谱 · 故 事 卷</span>
          <button type="button" onClick={() => navigate('/stories')}>
            继续阅读其他故事 <IconArrowRight size="small" />
          </button>
        </footer>
      </article>

      <StoryEditorDrawer
        visible={editOpen}
        story={story}
        onClose={() => setEditOpen(false)}
        onSaved={() => {
          setEditOpen(false);
          query.refresh();
        }}
      />

      <Modal
        visible={deleteOpen}
        title="删除这个故事？"
        type="warning"
        okText="确认删除"
        cancelText="取消"
        confirmLoading={deleting}
        onCancel={() => setDeleteOpen(false)}
        onOk={handleDelete}
      >
        <p className="story-delete-note">
          故事正文将从家族记忆中移除。已关联的照片不会从家族相册删除。
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
              alt={activePhoto.caption || story.title}
              fit="contain"
              className="photo-lightbox__image"
              eager
            />
            <div className="photo-lightbox__meta">
              <strong>{activePhoto.caption || story.title}</strong>
              <span>{formatDate(activePhoto.createdAt)}</span>
            </div>
          </div>
        ) : null}
      </Modal>
    </div>
  );
}
