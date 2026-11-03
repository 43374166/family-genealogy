import { useEffect, useRef, useState } from 'react';
import { Button, Input, Modal, Toast } from '@douyinfe/semi-ui';
import { SafeSelect as Select } from '@/components/SafeSelect';
import {
  IconCamera,
  IconClose,
  IconCloudUploadStroked,
  IconDelete,
  IconImage,
  IconPlus,
  IconRefresh,
} from '@douyinfe/semi-icons';
import { useAppSelector, useIsReviewer } from '@/store/hooks';
import { useAsync } from '@/hooks/useAsync';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { contentApi } from '@/api/content';
import { personsApi } from '@/api/persons';
import { PageHeader } from '@/components/PageHeader';
import { AuthedImage } from '@/components/AuthedImage';
import { EmptyState } from '@/components/EmptyState';
import { ErrorState } from '@/components/ErrorState';
import { SectionSkeleton } from '@/components/LoadingScreen';
import type { Photo } from '@/types/api';
import { formatDate, formatBytes } from '@/utils/format';
import { toErrorMessage } from '@/utils/error';
import './GalleryPage.scss';

const MAX_FILE_SIZE = 8 * 1024 * 1024;
const ACCEPTED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

export default function GalleryPage() {
  useDocumentTitle('家族相册');
  const isReviewer = useIsReviewer();
  const auth = useAppSelector((state) => state.auth);
  const [personFilter, setPersonFilter] = useState('');
  const [uploadOpen, setUploadOpen] = useState(false);
  const [activePhoto, setActivePhoto] = useState<Photo | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Photo | null>(null);
  const [deleting, setDeleting] = useState(false);

  const personsQuery = useAsync(
    async () => (await personsApi.listPersons({ limit: 100 })).items,
    [auth.family?.id],
    { enabled: Boolean(auth.family?.id) },
  );
  const photosQuery = useAsync(
    async () => (await contentApi.listPhotos(personFilter ? [personFilter] : [])).items,
    [auth.family?.id, personFilter],
    { enabled: Boolean(auth.family?.id) },
  );

  const personOptions = (personsQuery.data ?? []).map((person) => ({
    label: person.fullName,
    value: person.id,
  }));

  const canDelete = (photo: Photo) =>
    isReviewer || photo.uploadedByUserId === auth.user?.id;

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await contentApi.deletePhoto(deleteTarget.id);
      Toast.success({ content: '照片已从家族相册中移除', duration: 2.2 });
      if (activePhoto?.id === deleteTarget.id) setActivePhoto(null);
      setDeleteTarget(null);
      photosQuery.refresh();
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div className="app-page gallery-page">
      <PageHeader
        eyebrow="FAMILY GALLERY"
        title="家族相册"
        description="把老照片、团聚瞬间和日常片段放进同一个家族影像册。"
        actions={
          <>
            <Button
              theme="light"
              icon={<IconRefresh spin={photosQuery.refreshing} />}
              onClick={photosQuery.refresh}
            >
              刷新
            </Button>
            <Button
              theme="solid"
              type="primary"
              icon={<IconPlus />}
              onClick={() => setUploadOpen(true)}
            >
              上传照片
            </Button>
          </>
        }
      />

      <section className="gallery-toolbar">
        <div className="gallery-toolbar__count">
          <span className="gallery-toolbar__icon">
            <IconImage />
          </span>
          <div>
            <strong>{photosQuery.data?.length ?? 0}</strong>
            <span>{personFilter ? '张与这位成员相关的照片' : '张家族影像'}</span>
          </div>
        </div>
        <div className="gallery-toolbar__filters">
          <Select
            placeholder="按成员筛选"
            value={personFilter || undefined}
            showClear
            filter
            onClear={() => setPersonFilter('')}
            onChange={(value) => setPersonFilter(typeof value === 'string' ? value : '')}
            optionList={personOptions}
            className="gallery-toolbar__select"
            aria-label="按成员筛选照片"
          />
          <Button
            theme="borderless"
            icon={<IconCamera />}
            onClick={() => setUploadOpen(true)}
          >
            添加影像
          </Button>
        </div>
      </section>

      {photosQuery.error ? (
        <ErrorState description={photosQuery.error} onRetry={photosQuery.refresh} />
      ) : photosQuery.loading ? (
        <div className="photo-grid">
          {Array.from({ length: 8 }).map((_, index) => (
            <div className="photo-card photo-card--skeleton" key={index}>
              <SectionSkeleton rows={2} />
            </div>
          ))}
        </div>
      ) : photosQuery.data?.length ? (
        <div className="photo-grid">
          {photosQuery.data.map((photo) => (
            <button
              key={photo.id}
              type="button"
              className="photo-card"
              onClick={() => setActivePhoto(photo)}
            >
              <AuthedImage
                path={photo.contentPath}
                alt={photo.caption || '家族照片'}
                fallback={<IconImage />}
              />
              <span className="photo-card__shade" />
              <span className="photo-card__top">
                {photo.persons?.length ? (
                  <span className="photo-card__people">
                    {photo.persons
                      .slice(0, 2)
                      .map((person) => person.fullName)
                      .join('、')}
                    {photo.persons.length > 2 ? ` +${photo.persons.length - 2}` : ''}
                  </span>
                ) : null}
              </span>
              <span className="photo-card__caption">
                <strong>{photo.caption || '未命名影像'}</strong>
                <small>{formatDate(photo.takenAt || photo.createdAt)}</small>
              </span>
            </button>
          ))}
        </div>
      ) : (
        <div className="surface-card gallery-empty">
          <EmptyState
            title={personFilter ? '这位成员还没有关联照片' : '家族相册还是一页空白'}
            description={
              personFilter
                ? '可以上传新照片，或为该成员标记已有照片。'
                : '上传第一张照片，让家族的记忆有颜色。'
            }
            actionText="上传第一张照片"
            onAction={() => setUploadOpen(true)}
          />
        </div>
      )}

      <UploadPhotoModal
        visible={uploadOpen}
        persons={personOptions}
        onClose={() => setUploadOpen(false)}
        onUploaded={() => {
          setUploadOpen(false);
          photosQuery.refresh();
        }}
      />

      <Modal
        visible={Boolean(activePhoto)}
        footer={null}
        centered
        width={900}
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
            <div className="photo-lightbox__meta photo-lightbox__meta--gallery">
              <div>
                <strong>{activePhoto.caption || '未命名影像'}</strong>
                <span>
                  {formatDate(activePhoto.takenAt || activePhoto.createdAt)} · 由{' '}
                  {activePhoto.uploadedByName} 上传 · {formatBytes(activePhoto.sizeBytes)}
                </span>
                {activePhoto.persons?.length ? (
                  <div className="photo-lightbox__people">
                    {activePhoto.persons.map((person) => (
                      <span key={person.personId}>{person.fullName}</span>
                    ))}
                  </div>
                ) : null}
              </div>
              <div className="photo-lightbox__actions">
                {canDelete(activePhoto) ? (
                  <Button
                    theme="borderless"
                    type="danger"
                    icon={<IconDelete />}
                    onClick={() => setDeleteTarget(activePhoto)}
                  >
                    删除
                  </Button>
                ) : null}
                <Button
                  theme="borderless"
                  icon={<IconClose />}
                  onClick={() => setActivePhoto(null)}
                  aria-label="关闭"
                />
              </div>
            </div>
          </div>
        ) : null}
      </Modal>

      <Modal
        visible={Boolean(deleteTarget)}
        title="删除这张照片？"
        type="warning"
        okText="确认删除"
        cancelText="取消"
        confirmLoading={deleting}
        onCancel={() => setDeleteTarget(null)}
        onOk={handleDelete}
      >
        <p className="gallery-delete-note">
          照片将从家族相册和所有故事配图中移除，此操作不可撤销。
        </p>
      </Modal>
    </div>
  );
}

function UploadPhotoModal({
  visible,
  persons,
  onClose,
  onUploaded,
}: {
  visible: boolean;
  persons: { label: string; value: string }[];
  onClose: () => void;
  onUploaded: () => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [files, setFiles] = useState<File[]>([]);
  const [previews, setPreviews] = useState<string[]>([]);
  const [personIds, setPersonIds] = useState<string[]>([]);
  const [caption, setCaption] = useState('');
  const [takenAt, setTakenAt] = useState('');
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (visible) return;
    setFiles([]);
    setPersonIds([]);
    setCaption('');
    setTakenAt('');
    setProgress(0);
    setError(null);
  }, [visible]);

  useEffect(() => {
    const urls = files.map((file) => URL.createObjectURL(file));
    setPreviews(urls);
    return () => urls.forEach((url) => URL.revokeObjectURL(url));
  }, [files]);

  const addFiles = (incoming: FileList | File[]) => {
    const next = Array.from(incoming).filter((file) => {
      if (!ACCEPTED_TYPES.includes(file.type)) {
        setError('仅支持 JPEG、PNG 或 WebP 图片');
        return false;
      }
      if (file.size > MAX_FILE_SIZE) {
        setError(`「${file.name}」超过 8MB，请压缩后再上传`);
        return false;
      }
      return true;
    });
    if (!next.length) return;
    setFiles((current) => [...current, ...next].slice(0, 6));
    setError(null);
  };

  const removeFile = (index: number) => {
    setFiles((current) => current.filter((_, itemIndex) => itemIndex !== index));
  };

  const handleUpload = async () => {
    if (!files.length) {
      setError('请先选择照片');
      return;
    }
    if (takenAt && !/^\d{4}-\d{2}-\d{2}$/.test(takenAt)) {
      setError('拍摄日期格式应为 YYYY-MM-DD');
      return;
    }

    setUploading(true);
    setError(null);
    let uploaded = 0;
    try {
      for (const file of files) {
        await contentApi.uploadPhoto({
          file,
          personIds,
          caption: caption.trim(),
          takenAt: takenAt || undefined,
        });
        uploaded += 1;
        setProgress(uploaded);
      }
      Toast.success({ content: `${uploaded} 张照片已放入家族相册`, duration: 2.6 });
      onUploaded();
    } catch (uploadError) {
      setError(
        toErrorMessage(
          uploadError,
          uploaded ? `已上传 ${uploaded} 张，剩余照片上传失败` : '照片上传失败，请稍后重试',
        ),
      );
    } finally {
      setUploading(false);
    }
  };

  return (
    <Modal
      visible={visible}
      title="上传家族照片"
      width={650}
      onCancel={onClose}
      footer={
        <div className="upload-photo__footer">
          <span>{files.length ? `已选择 ${files.length} 张照片` : '最多一次选择 6 张，单张不超过 8MB'}</span>
          <div>
            <Button theme="borderless" onClick={onClose} disabled={uploading}>
              取消
            </Button>
            <Button theme="solid" type="primary" loading={uploading} onClick={handleUpload}>
              {uploading ? `正在上传 ${progress}/${files.length}` : '上传照片'}
            </Button>
          </div>
        </div>
      }
    >
      <div className="upload-photo">
        <div
          className="upload-photo__dropzone"
          onDragOver={(event) => event.preventDefault()}
          onDrop={(event) => {
            event.preventDefault();
            addFiles(event.dataTransfer.files);
          }}
          onClick={() => inputRef.current?.click()}
          role="button"
          tabIndex={0}
          onKeyDown={(event) => {
            if (event.key === 'Enter' || event.key === ' ') inputRef.current?.click();
          }}
        >
          <input
            ref={inputRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            multiple
            hidden
            onChange={(event) => {
              if (event.target.files) addFiles(event.target.files);
              event.target.value = '';
            }}
          />
          <span className="upload-photo__upload-icon">
            <IconCloudUploadStroked />
          </span>
          <strong>拖放照片到这里，或点击选择文件</strong>
          <small>支持 JPEG / PNG / WebP，单张不超过 8MB</small>
        </div>

        {previews.length ? (
          <div className="upload-photo__previews">
            {previews.map((url, index) => (
              <div key={url} className="upload-photo__preview">
                <img src={url} alt={files[index]?.name ?? '待上传照片'} />
                <button
                  type="button"
                  onClick={() => removeFile(index)}
                  aria-label="移除这张照片"
                  disabled={uploading}
                >
                  <IconClose size="small" />
                </button>
                <span>{formatBytes(files[index]?.size ?? 0)}</span>
              </div>
            ))}
          </div>
        ) : null}

        <div className="upload-photo__fields">
          <label className="upload-photo__field">
            <span>照片说明</span>
            <Input
              value={caption}
              onChange={setCaption}
              maxLength={500}
              placeholder="例如：1998 年春节，老宅门前合影"
            />
          </label>
          <label className="upload-photo__field">
            <span>拍摄日期</span>
            <Input
              value={takenAt}
              onChange={setTakenAt}
              placeholder="YYYY-MM-DD，可留空"
              maxLength={10}
            />
          </label>
          <label className="upload-photo__field upload-photo__field--full">
            <span>关联成员</span>
            <Select
              multiple
              filter
              value={personIds}
              onChange={(value) => setPersonIds((value as string[]) ?? [])}
              optionList={persons}
              placeholder="选择照片中出现的家族成员"
              maxTagCount={4}
              style={{ width: '100%' }}
            />
          </label>
        </div>

        {error ? <div className="upload-photo__error">{error}</div> : null}
      </div>
    </Modal>
  );
}
