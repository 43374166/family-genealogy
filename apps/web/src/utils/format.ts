import dayjs from 'dayjs';
import 'dayjs/locale/zh-cn';
import relativeTime from 'dayjs/plugin/relativeTime';
import type { Anniversary, PartialDate, PersonSummary, Role } from '@/types/api';

dayjs.extend(relativeTime);
dayjs.locale('zh-cn');

export function formatDate(value?: string | null, template = 'YYYY.MM.DD'): string {
  if (!value) return '—';
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.format(template) : '—';
}

export function formatDateTime(value?: string | null): string {
  return formatDate(value, 'YYYY.MM.DD HH:mm');
}

export function formatMonthDay(value?: string | null): string {
  return formatDate(value, 'MM 月 DD 日');
}

export function fromNow(value?: string | null): string {
  if (!value) return '—';
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.fromNow() : '—';
}

export function roleLabel(role?: Role | string): string {
  if (role === 'owner') return '族长';
  if (role === 'admin') return '管理员';
  return '普通成员';
}

export function genderLabel(gender?: string): string {
  if (gender === 'male') return '男';
  if (gender === 'female') return '女';
  return '未详';
}

export function lifeStatusLabel(status?: string): string {
  if (status === 'living') return '在世';
  if (status === 'deceased') return '已故';
  return '生卒未详';
}

export function generationLabel(person: Pick<PersonSummary, 'generationNo' | 'generationLabel'>): string {
  return person.generationLabel || `第${person.generationNo}世`;
}

export function generationShort(no: number): string {
  const numerals = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
  if (no <= 10) return `第${numerals[no] ?? no}世`;
  if (no < 20) return `第十${numerals[no - 10] ?? no % 10}世`;
  return `第${no}世`;
}

export function formatPartialDate(date?: PartialDate | null): string {
  if (!date) return '未详';
  if (date.text) return date.text;
  if (!date.year) return '未详';
  const calendar = date.calendar === 'lunar' ? '农历' : '';
  const month = date.month ? `${String(date.month).padStart(2, '0')}月` : '';
  const day = date.day ? `${String(date.day).padStart(2, '0')}日` : '';
  const leap = date.isLeapMonth ? '闰' : '';
  return `${calendar}${date.year}年${leap}${month}${day}`;
}

export function formatYear(date?: PartialDate | null): string {
  if (!date) return '';
  if (date.year) return String(date.year);
  return date.text ?? '';
}

export function lifeYears(person: Pick<PersonSummary, 'birth' | 'death' | 'lifeStatus'>): string {
  const birth = formatYear(person.birth);
  const death = formatYear(person.death);
  if (!birth && !death) return person.lifeStatus === 'living' ? '在世' : '生卒未详';
  if (person.lifeStatus === 'living') return `${birth || '?'} —`;
  return `${birth || '?'} — ${death || '?'}`;
}

export function anniversaryTitle(item: Anniversary): string {
  if (item.kind === 'memorial') return '祭日';
  return item.age ? `${item.age} 岁生日` : '生日';
}

export function anniversaryCountdown(daysUntil: number): string {
  if (daysUntil === 0) return '今天';
  if (daysUntil === 1) return '明天';
  return `${daysUntil} 天后`;
}

export function initials(name: string): string {
  const trimmed = name.trim();
  if (!trimmed) return '族';
  return trimmed.slice(-2);
}

const avatarTones = ['sage', 'sky', 'sand', 'rose', 'lavender', 'slate'] as const;

export function avatarTone(seed: string): (typeof avatarTones)[number] {
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) {
    hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return avatarTones[hash % avatarTones.length];
}

export function maskPhone(phone?: string): string {
  if (!phone) return '';
  if (phone.length < 7) return phone;
  return `${phone.slice(0, 3)}****${phone.slice(-4)}`;
}

export function formatBytes(size: number): string {
  if (!Number.isFinite(size) || size <= 0) return '0 B';
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(0)} KB`;
  return `${(size / 1024 / 1024).toFixed(1)} MB`;
}
