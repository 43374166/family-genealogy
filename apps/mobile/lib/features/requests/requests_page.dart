import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_data.dart';
import '../../models/family_activity.dart';
import 'profile_edit_page.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, this.initialFilter});

  final RequestStatus? initialFilter;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  RequestStatus? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  List<EditRequest> get _filtered {
    if (_filter == null) return DemoData.requests;
    return DemoData.requests
        .where((request) => request.status == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '我的申请',
              subtitle: '资料修改 · 审核进度',
              actions: [
                HeaderIconButton(
                  icon: Icons.help_outline_rounded,
                  onTap: () => _showHelp(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: _FilterBar(
                selected: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Text(
                    _filter == null ? '全部申请' : _statusTitle(_filter!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${items.length} 条',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '通过后才写入正式档案',
                    style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyRequests()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final request = items[index];
                        return _RequestCard(
                          request: request,
                          onTap: () => _showRequestDetail(context, request),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileEditPage()),
            ),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('发起资料申请'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusTitle(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return '待审核申请';
      case RequestStatus.approved:
        return '已通过申请';
      case RequestStatus.rejected:
        return '已拒绝申请';
      case RequestStatus.cancelled:
        return '已取消申请';
    }
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
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
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 21),
                SizedBox(width: 8),
                Text(
                  '审核说明',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 13),
            const _HelpLine(index: '01', text: '普通成员修改资料时，需先提交审核申请。'),
            const _HelpLine(index: '02', text: '族长或对应家支管理员核对后，正式档案才会更新。'),
            const _HelpLine(index: '03', text: '拒绝申请时必须保留审核意见，历史记录不会被删除。'),
            const SizedBox(height: 6),
            const Text(
              '数据安全边界由服务端统一校验，客户端按钮仅作展示。',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.inkMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetail(BuildContext context, EditRequest request) {
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
                Expanded(
                  child: Text(
                    request.title,
                    style: AppTheme.serif(fontSize: 21),
                  ),
                ),
                StatusPill.request(request.status),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '申请人：${request.targetName} · 提交于 ${request.submittedAt}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              '申请变更字段',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final field in request.changedFields)
                  TagPill(
                    label: field,
                    color: AppColors.primary,
                    background: AppColors.primarySoft,
                    icon: Icons.edit_outlined,
                  ),
              ],
            ),
            if (request.reviewNote != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: request.status == RequestStatus.rejected
                      ? AppColors.cinnabarSoft
                      : AppColors.jadeSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.status == RequestStatus.rejected
                          ? '拒绝原因'
                          : '审核意见',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: request.status == RequestStatus.rejected
                            ? AppColors.cinnabar
                            : AppColors.jade,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      request.reviewNote!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.65,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final RequestStatus? selected;
  final ValueChanged<RequestStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(String, RequestStatus?)>[
      ('全部', null),
      ('待审核', RequestStatus.pending),
      ('已通过', RequestStatus.approved),
      ('已拒绝', RequestStatus.rejected),
    ];
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFF3F5F6)),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option.$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == option.$2
                        ? AppColors.primarySoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    option.$1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected == option.$2
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected == option.$2
                          ? AppColors.primary
                          : AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final EditRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (request.status) {
      RequestStatus.pending => AppColors.gold,
      RequestStatus.approved => AppColors.jade,
      RequestStatus.rejected => AppColors.cinnabar,
      RequestStatus.cancelled => AppColors.inkMuted,
    };
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      request.status == RequestStatus.pending
                          ? Icons.hourglass_top_rounded
                          : Icons.description_outlined,
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '目标成员：${request.targetName}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill.request(request.status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final field in request.changedFields)
                    TagPill(
                      label: field,
                      color: AppColors.inkSoft,
                      background: const Color(0xFFF5F7F8),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Text(
                    request.submittedAt,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '查看详情',
                    style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index,
            style: const TextStyle(
              fontFamily: AppTheme.serifFamily,
              fontSize: 11,
              color: AppColors.cinnabar,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.55,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 30,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '这里还没有记录',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              '发起一次资料申请，审核进度会出现在这里',
              style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
