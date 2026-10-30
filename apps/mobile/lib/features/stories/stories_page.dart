import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import 'story_detail_page.dart';
import 'story_edit_page.dart';

class StoriesPage extends StatefulWidget {
  const StoriesPage({super.key});

  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
  List<ApiStory> _stories = const [];
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
      final stories = await SessionScope.of(context).stories();
      if (!mounted) return;
      setState(() {
        _stories = stories;
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

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const StoryEditPage()),
    );
    if (created == true && mounted) await _load();
  }

  Future<void> _open(ApiStory story) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StoryDetailPage(storyId: story.id, initial: story),
      ),
    );
    if (changed == true && mounted) await _load();
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
              title: '家族故事',
              subtitle: _loading ? '正在加载' : '${_stories.length} 篇家族记忆',
              actions: [
                HeaderIconButton(icon: Icons.edit_outlined, onTap: _create),
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
                  : _stories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            size: 44,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '还没有家族故事',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            label: const Text('写第一篇'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          8,
                          18,
                          MediaQuery.paddingOf(context).bottom + 26,
                        ),
                        children: [
                          _FeaturedStory(
                            story: _stories.first,
                            onTap: () => _open(_stories.first),
                          ),
                          if (_stories.length > 1) ...[
                            const SizedBox(height: 21),
                            const SectionTitle(title: '族人事迹'),
                            const SizedBox(height: 11),
                            for (var i = 1; i < _stories.length; i++) ...[
                              _StoryRow(
                                story: _stories[i],
                                onTap: () => _open(_stories[i]),
                              ),
                              if (i != _stories.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                          const SizedBox(height: 20),
                          SoftCard(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '写下你记得的家族往事',
                                  style: AppTheme.serif(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '一个人的故事，就是一段家族史。可以写人物、迁徙、老屋、手艺，也可以写一顿饭。',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.7,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _create,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('写一篇'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedStory extends StatelessWidget {
  const _FeaturedStory({required this.story, required this.onTap});

  final ApiStory story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9E3D39), Color(0xFF6E2C2A)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.cinnabar.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const StatusPill(
                  label: '最新故事',
                  foreground: Color(0xFFFFF0DC),
                  background: Color(0x33FFFFFF),
                  compact: true,
                ),
                const Spacer(),
                Text(
                  _storyDate(story.createdAt),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xCCFFF8EC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              story.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _excerpt(story.body),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xD9FFF8EC),
                fontSize: 11,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Text(
                  story.personName.isEmpty
                      ? story.authorName
                      : story.personName,
                  style: const TextStyle(
                    color: Color(0xB3FFF8EC),
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xCCFFF8EC),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story, required this.onTap});

  final ApiStory story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 21,
                color: AppColors.cinnabar,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _excerpt(story.body),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${story.personName.isEmpty ? story.authorName : story.personName} · ${_storyDate(story.createdAt)}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

String _excerpt(String text) {
  final value = text.replaceAll('\n', ' ').trim();
  return value.length <= 80 ? value : '${value.substring(0, 80)}…';
}

String _storyDate(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
