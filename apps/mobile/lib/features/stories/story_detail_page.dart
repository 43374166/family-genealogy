import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../person/api_person_detail_page.dart';
import 'story_edit_page.dart';

class StoryDetailPage extends StatefulWidget {
  const StoryDetailPage({super.key, required this.storyId, this.initial});

  final String storyId;
  final ApiStory? initial;

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  ApiStory? _story;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _story ??= widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final story = await SessionScope.of(context).story(widget.storyId);
      if (!mounted) return;
      setState(() {
        _story = story;
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

  Future<void> _edit(ApiStory story) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => StoryEditPage(story: story)),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete(ApiStory story) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除故事'),
        content: const Text('删除后家族成员将不再看到这篇故事。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SessionScope.of(context).deleteStory(story.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final session = SessionScope.of(context);
    final canEdit =
        story != null &&
        (story.authorUserId == session.user?.id || session.canWrite);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '家族故事',
              subtitle: story?.authorName == null
                  ? '正在加载'
                  : '由 ${story!.authorName} 记录',
              actions: [
                if (canEdit)
                  HeaderIconButton(
                    icon: Icons.edit_outlined,
                    onTap: () => _edit(story),
                  ),
                if (canEdit)
                  HeaderIconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: () => _delete(story),
                  ),
              ],
            ),
            Expanded(
              child: _loading && story == null
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _error != null && story == null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        10,
                        22,
                        MediaQuery.paddingOf(context).bottom + 30,
                      ),
                      children: [
                        Text(
                          story?.title ?? '',
                          style: AppTheme.serif(
                            fontSize: 27,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            StatusPill(
                              label: _dateLabel(story?.createdAt),
                              foreground: AppColors.inkMuted,
                              background: AppColors.slateSoft,
                              compact: true,
                            ),
                            const Spacer(),
                            Text(
                              story?.authorName ?? '',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        if (story != null && story.personName.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ApiPersonDetailPage(
                                  personId: story.personId!,
                                ),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_pin_circle_outlined,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    story.personName,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Container(
                          width: 34,
                          height: 2,
                          color: AppColors.ink.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 18),
                        SelectableText(
                          story?.body ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 2.0,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Center(
                          child: Text(
                            '— 家族记忆，代代相传 —',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
