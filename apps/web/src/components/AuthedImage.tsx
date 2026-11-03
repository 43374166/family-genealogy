import type { CSSProperties, ReactNode } from 'react';
import { useAuthedImage } from '@/hooks/useAuthedImage';
import { cn } from '@/utils/cn';

interface AuthedImageProps {
  path?: string | null;
  alt: string;
  className?: string;
  imgClassName?: string;
  style?: CSSProperties;
  fit?: 'cover' | 'contain';
  fallback?: ReactNode;
  eager?: boolean;
}

/** 带 Bearer 鉴权的图片：先拉 Blob，再渲染 object URL。 */
export function AuthedImage({
  path,
  alt,
  className,
  imgClassName,
  style,
  fit = 'cover',
  fallback,
  eager = false,
}: AuthedImageProps) {
  const { url, loading, error } = useAuthedImage(path, Boolean(path));

  return (
    <div className={cn('authed-image', className)} style={style}>
      {url ? (
        <img
          src={url}
          alt={alt}
          className={cn('authed-image__img', imgClassName)}
          style={{ objectFit: fit }}
          loading={eager ? 'eager' : 'lazy'}
          draggable={false}
        />
      ) : null}
      {loading ? <span className="authed-image__shimmer" aria-hidden /> : null}
      {!loading && (error || !path) ? (
        <span className="authed-image__fallback">{fallback ?? <span>{alt.slice(-1)}</span>}</span>
      ) : null}
    </div>
  );
}
