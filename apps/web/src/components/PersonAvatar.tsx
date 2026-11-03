import type { PersonSummary } from '@/types/api';
import { avatarTone, initials } from '@/utils/format';
import { cn } from '@/utils/cn';
import { useAuthedImage } from '@/hooks/useAuthedImage';
import { personsApi } from '@/api/persons';

interface PersonAvatarProps {
  person: Pick<PersonSummary, 'id' | 'fullName' | 'hasAvatar'> & { version?: number };
  size?: number;
  className?: string;
  ring?: boolean;
  eager?: boolean;
}

export function PersonAvatar({
  person,
  size = 44,
  className,
  ring = false,
  eager = false,
}: PersonAvatarProps) {
  // Version query busts the authenticated-image cache after an avatar change.
  const path = person.hasAvatar
    ? `${personsApi.avatarPath(person.id)}?v=${person.version ?? 0}`
    : null;
  const { url, loading } = useAuthedImage(path, Boolean(path));
  const tone = avatarTone(person.id || person.fullName);

  return (
    <span
      className={cn('person-avatar', `person-avatar--${tone}`, ring && 'is-ring', className)}
      style={{ width: size, height: size, fontSize: Math.max(12, size * 0.32) }}
      aria-label={person.fullName}
    >
      {url ? (
        <img
          src={url}
          alt={person.fullName}
          loading={eager ? 'eager' : 'lazy'}
          draggable={false}
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        />
      ) : (
        <span className="person-avatar__text">{initials(person.fullName)}</span>
      )}
      {loading ? <span className="person-avatar__spinner" aria-hidden /> : null}
    </span>
  );
}
