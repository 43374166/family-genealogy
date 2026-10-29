import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_data.dart';
import '../../models/family_activity.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final Set<String> _readIds = {};

  int get _unreadCount => DemoData.messages
      .where((message) => message.unread && !_readIds.contains(message.id))
      .length;

  @override
  Widget build(BuildContext context) {
    final today = DemoData.messages
        .where((m) => m.time.startsWith('今天') || m.time.startsWith('昨天'))
        .toList();
    final earlier = DemoData.messages.where((m) => !today.contains(m)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '消息',
              subtitle: _unreadCount == 0 ? '全部消息已读' : '$_unreadCount 条未读消息',
              showBack: false,
              padding: const EdgeInsets.fromLTRB(22, 8, 16, 8),
              actions: [
                HeaderIconButton(
                  icon: Icons.done_all_rounded,
                  onTap: _unreadCount == 0
                      ? () {}
                      : () {
                          setState(() {
                            _readIds.addAll(
                              DemoData.messages.map((message) => message.id),
                            );
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已全部标记为已读')),
                          );
                        },
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                children: [
                  _MessageSummary(
                    unread: _unreadCount,
                    total: DemoData.messages.length,
                    onTap: null,
                  ),
                  const SizedBox(height: 18),
                  if (today.isNotEmpty) ...[
                    const _TimeLabel(label: '最近'),
                    const SizedBox(height: 8),
                    _MessageGroup(
                      messages: today,
                      readIds: _readIds,
                      onTap: _openMessage,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (earlier.isNotEmpty) ...[
                    const _TimeLabel(label: '更早'),
                    const SizedBox(height: 8),
                    _MessageGroup(
                      messages: earlier,
                      readIds: _readIds,
                      onTap: _openMessage,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMessage(FamilyMessage message) {
    setState(() => _readIds.add(message.id));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          MediaQuery.paddingOf(context).bottom + 22,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                _MessageIcon(kind: message.kind, size: 42),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message.time,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.kind == MessageKind.review)
                  const StatusPill(
                    label: '审核',
                    foreground: AppColors.gold,
                    background: AppColors.goldSoft,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              message.body,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.8,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('知道了'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageSummary extends StatelessWidget {
  const _MessageSummary({
    required this.unread,
    required this.total,
    required this.onTap,
  });

  final int unread;
  final int total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 16, 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDF2FF), Color(0xFFF7F4EA)],
        ),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              size: 19,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unread == 0 ? '没有待处理消息' : '有 $unread 条消息待查看',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '消息仅保存在本机演示数据中',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.ink.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$total 条',
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.inkMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MessageGroup extends StatelessWidget {
  const _MessageGroup({
    required this.messages,
    required this.readIds,
    required this.onTap,
  });

  final List<FamilyMessage> messages;
  final Set<String> readIds;
  final ValueChanged<FamilyMessage> onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < messages.length; i++) ...[
            _MessageRow(
              message: messages[i],
              read: readIds.contains(messages[i].id) || !messages[i].unread,
              onTap: () => onTap(messages[i]),
            ),
            if (i != messages.length - 1) const Divider(height: 1, indent: 50),
          ],
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.read,
    required this.onTap,
  });

  final FamilyMessage message;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MessageIcon(kind: message.kind),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: read
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (!read)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.cinnabar,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message.time,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageIcon extends StatelessWidget {
  const _MessageIcon({required this.kind, this.size = 38});

  final MessageKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (kind) {
      MessageKind.review => (
        Icons.fact_check_outlined,
        AppColors.gold,
        AppColors.goldSoft,
      ),
      MessageKind.family => (
        Icons.diversity_3_outlined,
        AppColors.cinnabar,
        AppColors.cinnabarSoft,
      ),
      MessageKind.system => (
        Icons.cloud_done_outlined,
        AppColors.jade,
        AppColors.jadeSoft,
      ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}
