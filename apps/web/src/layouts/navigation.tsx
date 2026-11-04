import {
  IconBook,
  IconBranch,
  IconEdit,
  IconGallery,
  IconHome,
  IconMail,
  IconSetting,
  IconUser,
  IconUserGroup,
  IconBookOpenStroked,
} from '@douyinfe/semi-icons';

export interface NavItem {
  key: string;
  label: string;
  path: string;
  icon: typeof IconHome;
  end?: boolean;
  reviewerOnly?: boolean;
  memberOnly?: boolean;
  ownerOnly?: boolean;
}

export interface NavGroup {
  title: string;
  items: NavItem[];
}

export const primaryNav: NavItem[] = [
  { key: 'home', label: '家族首页', path: '/', icon: IconHome, end: true },
  { key: 'tree', label: '族谱树', path: '/tree', icon: IconBranch },
  { key: 'members', label: '成员查询', path: '/members', icon: IconUserGroup },
  { key: 'gallery', label: '家族相册', path: '/gallery', icon: IconGallery },
  { key: 'stories', label: '家族故事', path: '/stories', icon: IconBookOpenStroked },
];

export const collaborationNav: NavItem[] = [
  { key: 'books', label: '谱书工作区', path: '/books', icon: IconBook },
  { key: 'messages', label: '消息', path: '/messages', icon: IconMail },
  { key: 'requests', label: '审核中心', path: '/requests', icon: IconEdit, reviewerOnly: true },
  { key: 'requests', label: '我的申请', path: '/requests', icon: IconEdit, memberOnly: true },
  { key: 'profile', label: '我的', path: '/profile', icon: IconUser },
  { key: 'family', label: '家族管理', path: '/family', icon: IconSetting, reviewerOnly: true },
];

export const mobileNav: NavItem[] = [
  { key: 'home', label: '首页', path: '/', icon: IconHome, end: true },
  { key: 'tree', label: '族谱树', path: '/tree', icon: IconBranch },
  { key: 'members', label: '成员', path: '/members', icon: IconUserGroup },
  { key: 'messages', label: '消息', path: '/messages', icon: IconMail },
  { key: 'profile', label: '我的', path: '/profile', icon: IconUser },
];

export function isNavActive(item: NavItem, pathname: string): boolean {
  if (item.end) return pathname === item.path;
  if (pathname === item.path) return true;
  if (pathname.startsWith(`${item.path}/`)) return true;
  if (item.key === 'members' && pathname.startsWith('/persons/')) return true;
  if (item.key === 'stories' && pathname.startsWith('/stories/')) return true;
  return false;
}

export function pageTitleForPath(pathname: string): string {
  if (pathname === '/') return '家族首页';
  if (pathname.startsWith('/tree')) return '族谱树';
  if (pathname.startsWith('/members')) return '成员查询';
  if (pathname.startsWith('/persons/')) return '人物档案';
  if (pathname.startsWith('/gallery')) return '家族相册';
  if (pathname.startsWith('/stories/')) return '故事详情';
  if (pathname.startsWith('/stories')) return '家族故事';
  if (pathname.startsWith('/books')) return '谱书工作区';
  if (pathname.startsWith('/messages')) return '消息';
  if (pathname.startsWith('/requests')) return '审核中心';
  if (pathname.startsWith('/family')) return '家族管理';
  if (pathname.startsWith('/profile')) return '我的';
  return '家族族谱';
}
