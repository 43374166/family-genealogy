import { useEffect, useMemo, useState } from 'react';
import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import {
  Avatar,
  Badge,
  Button,
  Dropdown,
  Input,
  Spin,
  Tooltip,
  Toast,
} from '@douyinfe/semi-ui';

import {
  IconBell,
  IconChevronDown,
  IconExit,
  IconMenu,
  IconMoon,
  IconSearch,
  IconSetting,
  IconSun,
  IconUser,
  IconChevronLeft,
  IconChevronRight,
  IconHome,
  IconClose,
} from '@douyinfe/semi-icons';
import { BrandMark } from '@/components/BrandMark';
import { LoadingScreen } from '@/components/LoadingScreen';
import { useAppDispatch, useAppSelector, useIsReviewer } from '@/store/hooks';
import { logoutSession, switchFamily } from '@/store/authSlice';
import { resetNotifications } from '@/store/notificationSlice';
import { fetchUnreadCount } from '@/store/notificationSlice';
import { setMobileNavOpen, setThemeMode, toggleSidebar, type ThemeMode } from '@/store/uiSlice';
import { cn } from '@/utils/cn';
import { roleLabel } from '@/utils/format';
import {
  collaborationNav,
  isNavActive,
  mobileNav,
  pageTitleForPath,
  primaryNav,
  type NavItem,
} from './navigation';
import './AppShell.scss';

function NavLinkItem({
  item,
  collapsed,
  onNavigate,
  unreadCount,
}: {
  item: NavItem;
  collapsed: boolean;
  onNavigate?: () => void;
  unreadCount: number;
}) {
  const navigate = useNavigate();
  const location = useLocation();
  const active = isNavActive(item, location.pathname);
  const Icon = item.icon;

  const content = (
    <button
      type="button"
      className={cn('shell-nav__item', active && 'is-active', collapsed && 'is-collapsed')}
      onClick={() => {
        navigate(item.path);
        onNavigate?.();
      }}
      aria-current={active ? 'page' : undefined}
    >
      <span className="shell-nav__icon">
        <Icon size="default" />
        {item.key === 'messages' && unreadCount > 0 ? (
          <span className="shell-nav__badge">{unreadCount > 99 ? '99+' : unreadCount}</span>
        ) : null}
      </span>
      {!collapsed ? <span className="shell-nav__label">{item.label}</span> : null}
      {!collapsed && active ? <span className="shell-nav__active-dot" /> : null}
    </button>
  );

  return collapsed ? (
    <Tooltip content={item.label} position="right" key={`${item.key}-${item.path}`}>
      {content}
    </Tooltip>
  ) : (
    <div key={`${item.key}-${item.path}`}>{content}</div>
  );
}

function Sidebar() {
  const dispatch = useAppDispatch();
  const navigate = useNavigate();
  const auth = useAppSelector((state) => state.auth);
  const collapsed = useAppSelector((state) => state.ui.sidebarCollapsed);
  const unreadCount = useAppSelector((state) => state.notifications.unreadCount);
  const isReviewer = useIsReviewer();
  const [switching, setSwitching] = useState(false);

  const collabItems = useMemo(
    () =>
      collaborationNav.filter(
        (item) =>
          (!item.reviewerOnly || isReviewer) &&
          (!item.memberOnly || !isReviewer),
      ),
    [isReviewer],
  );

  const familyItems = useMemo(() => {
    const seen = new Set<string>();
    return (auth.families ?? []).filter((entry) => {
      if (seen.has(entry.family.id)) return false;
      seen.add(entry.family.id);
      return true;
    });
  }, [auth.families]);

  const handleSwitchFamily = async (familyId: string) => {
    if (!familyId || familyId === auth.family?.id) return;
    setSwitching(true);
    try {
      await dispatch(switchFamily(familyId)).unwrap();
      dispatch(resetNotifications());
      dispatch(fetchUnreadCount());
      Toast.success({ content: '已切换家族空间', duration: 2.2 });
      navigate('/');
    } catch (error) {
      Toast.error({ content: typeof error === 'string' ? error : '切换家族失败' });
    } finally {
      setSwitching(false);
    }
  };

  const familyButton = (
    <button className="family-switcher__button" type="button" disabled={switching}>
      <span className="family-switcher__text">
        <small>当前家族</small>
        <strong>{auth.family?.name ?? '加载中…'}</strong>
        <span>
          {roleLabel(auth.membership?.role)} · {auth.family?.region || '家族空间'}
        </span>
      </span>
      {switching ? <Spin size="small" /> : <IconChevronDown />}
    </button>
  );

  return (
    <aside className={cn('app-sidebar', collapsed && 'is-collapsed')}>
      <button className="app-sidebar__brand" type="button" onClick={() => navigate('/')}>
        <BrandMark size={collapsed ? 'sm' : 'md'} />
        {!collapsed ? (
          <span className="app-sidebar__brand-text">
            <strong>家族族谱</strong>
            <small>寻根溯源 · 传承家风</small>
          </span>
        ) : null}
      </button>

      <div className={cn('family-switcher', collapsed && 'is-collapsed')}>
        {collapsed ? (
          <Tooltip content={auth.family?.name ?? '当前家族'} position="right">
            <button className="family-switcher__seal" type="button" onClick={() => navigate('/family')}>
              {auth.family?.surname?.[0] ?? '族'}
            </button>
          </Tooltip>
        ) : familyItems.length > 1 ? (
          <Dropdown
            trigger="click"
            position="bottomLeft"
            clickToHide
            render={
              <Dropdown.Menu>
                {familyItems.map((entry) => (
                  <Dropdown.Item
                    key={entry.family.id}
                    active={entry.family.id === auth.family?.id}
                    onClick={() => handleSwitchFamily(entry.family.id)}
                  >
                    <div className="family-switch-item">
                      <span>{entry.family.name}</span>
                      <small>
                        {roleLabel(entry.membership.role)} · {entry.family.memberCount} 人
                      </small>
                    </div>
                  </Dropdown.Item>
                ))}
              </Dropdown.Menu>
            }
          >
            {familyButton}
          </Dropdown>
        ) : (
          familyButton
        )}
      </div>

      <nav className="shell-nav" aria-label="主导航">
        <div className="shell-nav__group">
          {!collapsed ? <p className="shell-nav__group-title">家族</p> : <span className="shell-nav__rule" />}
          {primaryNav.map((item) => (
            <NavLinkItem
              key={item.key}
              item={item}
              collapsed={collapsed}
              unreadCount={unreadCount}
            />
          ))}
        </div>
        <div className="shell-nav__group">
          {!collapsed ? <p className="shell-nav__group-title">协作</p> : <span className="shell-nav__rule" />}
          {collabItems.map((item) => (
            <NavLinkItem
              key={`${item.key}-${item.path}`}
              item={item}
              collapsed={collapsed}
              unreadCount={unreadCount}
            />
          ))}
        </div>
      </nav>

      <div className="app-sidebar__footer">
        {!collapsed ? (
          <button className="sidebar-user" type="button" onClick={() => navigate('/profile')}>
            <Avatar size="small" className="sidebar-user__avatar">
              {auth.user?.displayName?.slice(-1) ?? '族'}
            </Avatar>
            <span className="sidebar-user__text">
              <strong>{auth.user?.displayName ?? '成员'}</strong>
              <small>{roleLabel(auth.membership?.role)}</small>
            </span>
            <span className="sidebar-user__more">
              <IconChevronRight size="small" />
            </span>
          </button>
        ) : (
          <Tooltip content={auth.user?.displayName ?? '我的'} position="right">
            <Avatar size="small" className="sidebar-user__avatar">
              {auth.user?.displayName?.slice(-1) ?? '族'}
            </Avatar>
          </Tooltip>
        )}
        <button
          className="sidebar-collapse"
          type="button"
          onClick={() => dispatch(toggleSidebar())}
          aria-label={collapsed ? '展开侧栏' : '收起侧栏'}
        >
          {collapsed ? <IconChevronRight /> : <IconChevronLeft />}
        </button>
      </div>
    </aside>
  );
}

function TopHeader() {
  const dispatch = useAppDispatch();
  const navigate = useNavigate();
  const location = useLocation();
  const auth = useAppSelector((state) => state.auth);
  const unreadCount = useAppSelector((state) => state.notifications.unreadCount);
  const themeMode = useAppSelector((state) => state.ui.themeMode);
  const [search, setSearch] = useState('');
  const isReviewer = useIsReviewer();
  const baseTitle = pageTitleForPath(location.pathname);
  const title =
    location.pathname.startsWith('/requests') && !isReviewer ? '我的申请' : baseTitle;

  const themeMenu = (
    <Dropdown.Menu>
      <Dropdown.Item
        icon={<IconSun />}
        active={themeMode === 'light'}
        onClick={() => dispatch(setThemeMode('light' as ThemeMode))}
      >
        亮色纸本
      </Dropdown.Item>
      <Dropdown.Item
        icon={<IconMoon />}
        active={themeMode === 'dark'}
        onClick={() => dispatch(setThemeMode('dark' as ThemeMode))}
      >
        暮色墨本
      </Dropdown.Item>
      <Dropdown.Item
        icon={<IconHome />}
        active={themeMode === 'system'}
        onClick={() => dispatch(setThemeMode('system' as ThemeMode))}
      >
        跟随系统
      </Dropdown.Item>
    </Dropdown.Menu>
  );

  const userMenu = (
    <Dropdown.Menu>
      <Dropdown.Item icon={<IconUser />} onClick={() => navigate('/profile')}>
        个人中心
      </Dropdown.Item>
      <Dropdown.Item icon={<IconSetting />} onClick={() => navigate('/family')}>
        家族管理
      </Dropdown.Item>
      <Dropdown.Divider />
      <Dropdown.Item
        icon={<IconExit />}
        onClick={async () => {
          await dispatch(logoutSession());
          navigate('/login', { replace: true });
        }}
      >
        退出登录
      </Dropdown.Item>
    </Dropdown.Menu>
  );

  const submitSearch = () => {
    const keyword = search.trim();
    navigate(keyword ? `/members?q=${encodeURIComponent(keyword)}` : '/members');
  };

  return (
    <header className="app-topbar">
      <div className="app-topbar__left">
        <Button
          className="app-topbar__menu-btn"
          theme="borderless"
          icon={<IconMenu />}
          onClick={() => dispatch(setMobileNavOpen(true))}
          aria-label="打开导航"
        />
        <div className="app-topbar__crumb">
          <span>{auth.family?.name ?? '家族空间'}</span>
          <i>/</i>
          <strong>{title}</strong>
        </div>
      </div>

      <div className="app-topbar__right">
        <Input
          className="app-topbar__search"
          prefix={<IconSearch />}
          placeholder="搜索成员姓名、字号或别名"
          value={search}
          onChange={setSearch}
          onEnterPress={submitSearch}
          showClear
          aria-label="搜索成员"
        />
        <Tooltip content="消息中心" position="bottom">
          <Button
            theme="borderless"
            className="topbar-icon-btn"
            icon={
              unreadCount > 0 ? (
                <Badge count={unreadCount} overflowCount={99}>
                  <IconBell />
                </Badge>
              ) : (
                <IconBell />
              )
            }
            onClick={() => navigate('/messages')}
            aria-label={`消息中心${unreadCount ? `，${unreadCount} 条未读` : ''}`}
          />
        </Tooltip>
        <Dropdown trigger="click" position="bottomRight" render={themeMenu} clickToHide>
          <Button
            theme="borderless"
            className="topbar-icon-btn"
            icon={themeMode === 'dark' ? <IconMoon /> : <IconSun />}
            aria-label="切换主题"
          />
        </Dropdown>
        <Dropdown trigger="click" position="bottomRight" render={userMenu} clickToHide>
          <button className="topbar-user" type="button">
            <Avatar size="small" className="topbar-user__avatar">
              {auth.user?.displayName?.slice(-1) ?? '族'}
            </Avatar>
            <span className="topbar-user__name">{auth.user?.displayName ?? '成员'}</span>
            <IconChevronDown size="small" className="topbar-user__arrow" />
          </button>
        </Dropdown>
      </div>
    </header>
  );
}

function MobileDrawer() {
  const dispatch = useAppDispatch();
  const navigate = useNavigate();
  const location = useLocation();
  const auth = useAppSelector((state) => state.auth);
  const open = useAppSelector((state) => state.ui.mobileNavOpen);
  const unreadCount = useAppSelector((state) => state.notifications.unreadCount);
  const isReviewer = useIsReviewer();

  const items = [
    ...primaryNav,
    ...collaborationNav.filter(
      (item) =>
        (!item.reviewerOnly || isReviewer) &&
        (!item.memberOnly || !isReviewer),
    ),
  ];

  return (
    <div className={cn('mobile-drawer', open && 'is-open')} aria-hidden={!open}>
      <button
        className="mobile-drawer__backdrop"
        type="button"
        aria-label="关闭导航"
        onClick={() => dispatch(setMobileNavOpen(false))}
      />
      <aside className="mobile-drawer__panel">
        <div className="mobile-drawer__head">
          <div className="brand-lockup">
            <BrandMark size="sm" />
            <div className="brand-lockup__text">
              <strong>家族族谱</strong>
              <span>{auth.family?.name ?? '家族空间'}</span>
            </div>
          </div>
          <Button
            theme="borderless"
            icon={<IconClose />}
            onClick={() => dispatch(setMobileNavOpen(false))}
            aria-label="关闭"
          />
        </div>
        <div className="mobile-drawer__user">
          <Avatar size="default" className="topbar-user__avatar">
            {auth.user?.displayName?.slice(-1) ?? '族'}
          </Avatar>
          <div>
            <strong>{auth.user?.displayName}</strong>
            <span>
              {roleLabel(auth.membership?.role)} · {auth.family?.memberCount ?? 0} 位成员
            </span>
          </div>
        </div>
        <nav className="mobile-drawer__nav">
          {items.map((item) => {
            const Icon = item.icon;
            const active = isNavActive(item, location.pathname);
            return (
              <button
                key={`${item.key}-${item.path}`}
                type="button"
                className={cn('mobile-drawer__item', active && 'is-active')}
                onClick={() => {
                  navigate(item.path);
                  dispatch(setMobileNavOpen(false));
                }}
              >
                <Icon />
                <span>{item.label}</span>
                {item.key === 'messages' && unreadCount ? (
                  <em>{unreadCount > 99 ? '99+' : unreadCount}</em>
                ) : null}
              </button>
            );
          })}
        </nav>
      </aside>
    </div>
  );
}

function MobileTabBar() {
  const navigate = useNavigate();
  const location = useLocation();
  const unreadCount = useAppSelector((state) => state.notifications.unreadCount);

  return (
    <nav className="mobile-tabbar" aria-label="手机导航">
      {mobileNav.map((item) => {
        const Icon = item.icon;
        const active = isNavActive(item, location.pathname);
        return (
          <button
            key={item.key}
            type="button"
            className={cn('mobile-tabbar__item', active && 'is-active')}
            onClick={() => navigate(item.path)}
          >
            <span className="mobile-tabbar__icon">
              <Icon size="large" />
              {item.key === 'messages' && unreadCount > 0 ? <i /> : null}
            </span>
            <span>{item.label}</span>
          </button>
        );
      })}
    </nav>
  );
}

export function AppShell() {
  const auth = useAppSelector((state) => state.auth);
  const collapsed = useAppSelector((state) => state.ui.sidebarCollapsed);
  const familyId = auth.family?.id;
  const dispatch = useAppDispatch();
  const location = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [location.pathname]);

  useEffect(() => {
    if (!familyId) return;
    dispatch(fetchUnreadCount());
    const timer = window.setInterval(() => dispatch(fetchUnreadCount()), 60_000);
    return () => window.clearInterval(timer);
  }, [dispatch, familyId]);

  useEffect(() => {
    dispatch(setMobileNavOpen(false));
  }, [dispatch, location.pathname]);

  if (!auth.initialized || auth.status === 'loading' && !auth.user) {
    return <LoadingScreen />;
  }

  return (
    <div className={`app-shell ${collapsed ? 'is-collapsed' : ''}`}>
      <Sidebar />
      <div className="app-shell__main">
        <TopHeader />
        <main className="app-shell__content" id="main-content">
          <Outlet />
        </main>
      </div>
      <MobileDrawer />
      <MobileTabBar />
    </div>
  );
}
