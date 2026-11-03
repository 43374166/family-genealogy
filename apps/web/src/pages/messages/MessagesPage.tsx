import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Tabs } from '@douyinfe/semi-ui';
import {
  IconBell,
  IconCheckChoiceStroked,
  IconEdit,
  IconMail,
  IconRefresh,
  IconUserGroup,
} from '@douyinfe/semi-icons';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import {
  fetchNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from '@/store/notificationSlice';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import { PageHeader } from '@/components/PageHeader';
import { EmptyState } from '@/components/EmptyState';
import { ErrorState } from '@/components/ErrorState';
import { SectionSkeleton } from '@/components/LoadingScreen';
import type { NotificationItem } from '@/types/api';
import { formatDateTime, fromNow } from '@/utils/format';
import { cn } from '@/utils/cn';
import './MessagesPage.scss';

const kindMeta: Record<string, { icon: ReactNode; tone: string; label: string }> = {
  edit_request: { icon: <IconEdit />, tone: 'blue', label: '资料审核' },
  binding_request: { icon: <IconUserGroup />, tone: 'jade', label: '人物绑定' },
  family_merge_request: { icon: <IconUserGroup />, tone: 'gold', label: '家族合并' },
  family_merge_approved: { icon: <IconCheckChoiceStroked />, tone: 'jade', label: '合并完成' },
  family_merge_rejected: { icon: <IconBell />, tone: 'rose', label: '合并结果' },
};

export default function MessagesPage() {
  useDocumentTitle('消息');
  const dispatch = useAppDispatch();
  const navigate = useNavigate();
  const { items, unreadCount, loading, loaded, error } = useAppSelector(
    (state) => state.notifications,
  );
  const [filter, setFilter] = useState('all');

  useEffect(() => {
    dispatch(fetchNotifications());
  }, [dispatch]);

  const filtered = useMemo(
    () => (filter === 'unread' ? items.filter((item) => !item.isRead) : items),
    [filter, items],
  );

  const openNotification = async (item: NotificationItem) => {
    if (!item.isRead) {
      await dispatch(markNotificationRead(item.id));
    }
    if (item.targetType === 'edit_request' || item.targetType === 'binding_request') {
      navigate('/requests');
    } else if (item.targetType.startsWith('family_merge')) {
      navigate('/profile');
    }
  };

  return (
    <div className="app-page messages-page">
      <PageHeader
        eyebrow="MESSAGES"
        title="消息"
        description="家族里的每一次资料提交、审核与变动，都会在这里留下提醒。"
        actions={
          <>
            <Button
              theme="light"
              icon={<IconRefresh spin={loading} />}
              onClick={() => dispatch(fetchNotifications())}
            >
              刷新
            </Button>
            <Button
              theme="solid"
              type="primary"
              icon={<IconCheckChoiceStroked />}
              disabled={!unreadCount}
              onClick={async () => {
                await dispatch(markAllNotificationsRead());
              }}
            >
              全部已读
            </Button>
          </>
        }
      />

      <section className="messages-summary">
        <div className="messages-summary__mark">
          <IconMail />
          {unreadCount ? <span>{unreadCount > 99 ? '99+' : unreadCount}</span> : null}
        </div>
        <div>
          <strong>{unreadCount ? `${unreadCount} 条未读消息` : '消息都已读完了'}</strong>
          <p>{unreadCount ? '花一点时间看看家族正在发生什么。' : '新的家族动态会第一时间出现在这里。'}</p>
        </div>
        <Tabs
          activeKey={filter}
          onChange={setFilter}
          type="button"
          className="messages-summary__tabs"
        >
          <Tabs.TabPane tab="全部消息" itemKey="all" />
          <Tabs.TabPane tab={`未读${unreadCount ? ` ${unreadCount}` : ''}`} itemKey="unread" />
        </Tabs>
      </section>

      {error && !loaded ? (
        <ErrorState description={error} onRetry={() => dispatch(fetchNotifications())} />
      ) : loading && !loaded ? (
        <div className="surface-card messages-card">
          <SectionSkeleton rows={6} />
        </div>
      ) : filtered.length ? (
        <div className="surface-card messages-card">
          {filtered.map((item) => {
            const meta = kindMeta[item.kind] ?? {
              icon: <IconBell />,
              tone: 'slate',
              label: '家族通知',
            };
            return (
              <button
                type="button"
                key={item.id}
                className={cn('message-row', !item.isRead && 'is-unread')}
                onClick={() => openNotification(item)}
              >
                <span className={cn('message-row__icon', `message-row__icon--${meta.tone}`)}>
                  {meta.icon}
                </span>
                <span className="message-row__body">
                  <span className="message-row__head">
                    <strong>{item.title}</strong>
                    {!item.isRead ? <i>未读</i> : null}
                    <em>{meta.label}</em>
                  </span>
                  <p>{item.body}</p>
                  <span className="message-row__time">
                    {formatDateTime(item.createdAt)} · {fromNow(item.createdAt)}
                  </span>
                </span>
                {!item.isRead ? <span className="message-row__dot" /> : null}
              </button>
            );
          })}
        </div>
      ) : (
        <div className="surface-card messages-empty">
          <EmptyState
            title={filter === 'unread' ? '没有未读消息' : '消息盒还是空的'}
            description={
              filter === 'unread'
                ? '所有消息都已经看过了，去族谱里转转吧。'
                : '当家族里有新的资料申请、审核结果或合并进展时，会在这里提醒你。'
            }
            actionText={filter === 'unread' ? '查看全部消息' : '回到家族首页'}
            onAction={() => (filter === 'unread' ? setFilter('all') : navigate('/'))}
          />
        </div>
      )}
    </div>
  );
}
