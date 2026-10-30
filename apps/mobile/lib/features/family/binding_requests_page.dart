import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class BindingRequestsPage extends StatefulWidget {
  const BindingRequestsPage({super.key});

  @override
  State<BindingRequestsPage> createState() => _BindingRequestsPageState();
}

class _BindingRequestsPageState extends State<BindingRequestsPage> {
  List<ApiBindingRequest> _items = const [];
  bool _loading = true;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await SessionScope.of(
        context,
      ).bindingRequests(status: 'pending');
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _review(ApiBindingRequest request, bool approve) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? '通过绑定' : '拒绝绑定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.requesterName} → ${request.personName}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: approve ? '审核备注（可选）' : '拒绝原因（必填）',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!approve && value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: Text(approve ? '确认通过' : '确认拒绝'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;
    try {
      await SessionScope.of(
        context,
      ).reviewBindingRequest(request.id, approve: approve, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(approve ? '已绑定' : '已拒绝')));
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '绑定审核',
              subtitle: '成员账号与族谱人物绑定',
              actions: [
                HeaderIconButton(icon: Icons.refresh_rounded, onTap: _load),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无待审核的绑定申请',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Container(
                          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.link_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      '${item.requesterName} → ${item.personName}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  const TagPill(
                                    label: '待审核',
                                    color: AppColors.gold,
                                    background: AppColors.goldSoft,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _date(item.submittedAt),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: 11),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _review(item, false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.cinnabar,
                                        side: const BorderSide(
                                          color: AppColors.cinnabar,
                                        ),
                                      ),
                                      child: const Text('拒绝'),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => _review(item, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                      ),
                                      child: const Text('通过'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
