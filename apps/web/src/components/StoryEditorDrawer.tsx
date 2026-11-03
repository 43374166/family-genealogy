import { useEffect, useState } from 'react';
import { Button, Input, SideSheet, TextArea, Toast } from '@douyinfe/semi-ui';
import { SafeSelect as Select } from '@/components/SafeSelect';
import { IconCheckCircleStroked, IconClose } from '@douyinfe/semi-icons';
import type { Photo, Story } from '@/types/api';
import { contentApi } from '@/api/content';
import { personsApi } from '@/api/persons';
import { useAsync } from '@/hooks/useAsync';
import { useAppSelector } from '@/store/hooks';
import { AuthedImage } from './AuthedImage';
import { toErrorMessage } from '@/utils/error';
import { cn } from '@/utils/cn';
import './StoryEditorDrawer.scss';

export function StoryEditorDrawer({
  visible,
  story,
  onClose,
  onSaved,
}: {
  visible: boolean;
  story?: Story | null;
  onClose: () => void;
  onSaved: (story: Story) => void;
}) {
  const auth = useAppSelector((state) => state.auth);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [personId, setPersonId] = useState('');
  const [photoIds, setPhotoIds] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const personsQuery = useAsync(
    async () => (await personsApi.listPersons({ limit: 100 })).items,
    [auth.family?.id, visible],
    { enabled: visible && Boolean(auth.family?.id) },
  );
  const photosQuery = useAsync(
    async () => (await contentApi.listPhotos()).items,
    [auth.family?.id, visible],
    { enabled: visible && Boolean(auth.family?.id) },
  );

  useEffect(() => {
    if (!visible) return;
    setTitle(story?.title ?? '');
    setBody(story?.body ?? '');
    setPersonId(story?.personId ?? '');
    setPhotoIds((story?.photos ?? []).map((photo) => photo.id));
    setError(null);
  }, [story, visible]);

  const togglePhoto = (photoId: string) => {
    setPhotoIds((current) => {
      if (current.includes(photoId)) return current.filter((id) => id !== photoId);
      if (current.length >= 9) {
        Toast.info({ content: '一个故事最多选择 9 张配图', duration: 2 });
        return current;
      }
      return [...current, photoId];
    });
  };

  const handleSave = async () => {
    if (!title.trim()) {
      setError('请为这个故事写一个标题');
      return;
    }
    if (!body.trim()) {
      setError('故事正文不能为空');
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const payload = {
        title: title.trim(),
        body: body.trim(),
        personId: personId || '',
        photoIds,
      };
      const saved = story
        ? await contentApi.updateStory(story.id, payload)
        : await contentApi.createStory(payload);
      Toast.success({
        content: story ? '故事已更新' : '故事已收入家族记忆',
        duration: 2.3,
      });
      onSaved(saved);
      onClose();
    } catch (saveError) {
      setError(toErrorMessage(saveError, '保存失败，请稍后重试'));
    } finally {
      setSaving(false);
    }
  };

  const allPhotos: Photo[] = photosQuery.data ?? [];

  return (
    <SideSheet
      visible={visible}
      placement="right"
      width={760}
      title={story ? '编辑家族故事' : '写一个家族故事'}
      onCancel={onClose}
      closeOnEsc
      maskClosable={false}
      className="story-editor-sheet"
      footer={
        <div className="story-editor__footer">
          <span>{body.trim().length} / 20000 字</span>
          <div>
            <Button theme="borderless" onClick={onClose} disabled={saving}>
              取消
            </Button>
            <Button theme="solid" type="primary" loading={saving} onClick={handleSave}>
              {story ? '保存修改' : '收入家族记忆'}
            </Button>
          </div>
        </div>
      }
    >
      <div className="story-editor">
        <p className="story-editor__intro">
          写下一个人、一件事，或一个再普通不过的家族日常。文字和照片会一起被后来的人看见。
        </p>

        <label className="story-editor__field">
          <span>故事标题 <em>*</em></span>
          <Input
            size="large"
            value={title}
            onChange={setTitle}
            maxLength={120}
            placeholder="例如：祖父的那把旧藤椅"
          />
        </label>

        <div className="story-editor__row">
          <label className="story-editor__field">
            <span>关联人物</span>
            <Select
              filter
              value={personId || undefined}
              onChange={(value) => setPersonId(typeof value === 'string' ? value : '')}
              onClear={() => setPersonId('')}
              showClear
              placeholder="可选，关联一位家族成员"
              optionList={(personsQuery.data ?? []).map((person) => ({
                label: `${person.fullName} · 第${person.generationNo}世`,
                value: person.id,
              }))}
              style={{ width: '100%' }}
            />
          </label>
          <span className="story-editor__field story-editor__field--hint">
            <span>配图</span>
            <em>已选择 {photoIds.length} / 9 张</em>
          </span>
        </div>

        <label className="story-editor__field">
          <span>正文 <em>*</em></span>
          <TextArea
            value={body}
            onChange={setBody}
            maxLength={20000}
            autosize={{ minRows: 8, maxRows: 20 }}
            placeholder="从一个细节写起，让故事慢慢展开…"
          />
        </label>

        <div className="story-editor__field">
          <span>选择配图</span>
          {photosQuery.loading ? (
            <p className="story-editor__empty">正在翻找家族相册…</p>
          ) : allPhotos.length ? (
            <div className="story-editor__photos">
              {allPhotos.map((photo) => {
                const selected = photoIds.includes(photo.id);
                const index = photoIds.indexOf(photo.id);
                return (
                  <button
                    type="button"
                    key={photo.id}
                    className={cn('story-photo-option', selected && 'is-selected')}
                    onClick={() => togglePhoto(photo.id)}
                    title={photo.caption || '选择这张照片'}
                  >
                    <AuthedImage path={photo.contentPath} alt={photo.caption || '家族照片'} />
                    {selected ? (
                      <span className="story-photo-option__order">
                        {index >= 0 ? index + 1 : <IconCheckCircleStroked />}
                      </span>
                    ) : (
                      <span className="story-photo-option__check">
                        <IconCheckCircleStroked />
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          ) : (
            <p className="story-editor__empty">
              家族相册中还没有照片，可以先写纯文字故事。
            </p>
          )}
        </div>

        {error ? (
          <div className="story-editor__error">
            <IconClose size="small" /> {error}
          </div>
        ) : null}
      </div>
    </SideSheet>
  );
}
