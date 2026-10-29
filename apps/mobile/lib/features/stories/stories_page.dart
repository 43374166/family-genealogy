import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';

class StoriesPage extends StatelessWidget {
  const StoriesPage({super.key});

  static const _stories = [
    (
      title: '青溪张氏：一部写了三百年的家谱',
      excerpt: '从康熙年间的第一册手抄谱，到今天的数字族谱，记录的不只是姓名，更是几代人的生活。',
      tag: '族史',
      date: '2025-04-12',
      readTime: '8 分钟',
      color: AppColors.cinnabar,
      background: AppColors.cinnabarSoft,
    ),
    (
      title: '祖宅门楣上的四个字',
      excerpt: '“耕读传家”四字，是张天明公留给后人的家训，也是青溪老宅最安静的守望。',
      tag: '家训',
      date: '2025-03-28',
      readTime: '5 分钟',
      color: AppColors.jade,
      background: AppColors.jadeSoft,
    ),
    (
      title: '一张 1952 年的全家福',
      excerpt: '照片已经泛黄，但每个人的位置仍被长辈清晰地记得。一次影像征集，牵出了跨越七十年的故事。',
      tag: '影像',
      date: '2025-03-05',
      readTime: '6 分钟',
      color: AppColors.primary,
      background: AppColors.primarySoft,
    ),
  ];

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
              subtitle: '记录先人，也记录我们自己',
              actions: [
                HeaderIconButton(
                  icon: Icons.edit_outlined,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('故事投稿将在服务端接入后开放')),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  MediaQuery.paddingOf(context).bottom + 26,
                ),
                children: [
                  _FeaturedStory(
                    onTap: () => _openStory(
                      context,
                      _stories.first.title,
                      _stories.first.excerpt,
                      _stories.first.tag,
                      _stories.first.date,
                    ),
                  ),
                  const SizedBox(height: 21),
                  const SectionTitle(title: '族人讲述', actionLabel: '全部'),
                  const SizedBox(height: 11),
                  for (var i = 0; i < _stories.length; i++) ...[
                    _StoryRow(
                      story: _stories[i],
                      onTap: () => _openStory(
                        context,
                        _stories[i].title,
                        _stories[i].excerpt,
                        _stories[i].tag,
                        _stories[i].date,
                      ),
                    ),
                    if (i != _stories.length - 1) const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 20),
                  SoftCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.cinnabarSoft,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.auto_stories_outlined,
                                size: 16,
                                color: AppColors.cinnabar,
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Text(
                              '一起续写家族故事',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '如果你家中还留有旧照片、书信或长辈口述的往事，欢迎在后续版本中投稿。所有故事将在审核后公开展示。',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.75,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
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

  void _openStory(
    BuildContext context,
    String title,
    String excerpt,
    String tag,
    String date,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailPage(
          title: title,
          excerpt: excerpt,
          tag: tag,
          date: date,
        ),
      ),
    );
  }
}

class _FeaturedStory extends StatelessWidget {
  const _FeaturedStory({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 252,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1620323B),
              blurRadius: 24,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/hero_ink.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(-0.15, -0.2),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), Color(0xC71D2A30)],
                  stops: [0.24, 1],
                ),
              ),
            ),
            Positioned(
              left: 17,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cinnabar,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '本族故事',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '青溪张氏',
                    style: TextStyle(
                      fontFamily: AppTheme.serifFamily,
                      fontSize: 30,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '一部写了三百年的家谱',
                    style: TextStyle(fontSize: 12.5, color: Color(0xF2FFFFFF)),
                  ),
                  SizedBox(height: 9),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: Color(0xBFFFFFFF),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '8 分钟阅读 · 族史',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color(0xBFFFFFFF),
                        ),
                      ),
                    ],
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

class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story, required this.onTap});

  final ({
    String title,
    String excerpt,
    String tag,
    String date,
    String readTime,
    Color color,
    Color background,
  })
  story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 72,
                decoration: BoxDecoration(
                  color: story.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Text(
                      story.tag.characters.first,
                      style: TextStyle(
                        fontFamily: AppTheme.serifFamily,
                        fontSize: 28,
                        color: story.color.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TagPill(
                          label: story.tag,
                          color: story.color,
                          background: story.background,
                        ),
                        const Spacer(),
                        Text(
                          story.date,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoryDetailPage extends StatelessWidget {
  const StoryDetailPage({
    super.key,
    required this.title,
    required this.excerpt,
    required this.tag,
    required this.date,
  });

  final String title;
  final String excerpt;
  final String tag;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
            backgroundColor: AppColors.surfaceWarm,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: RoundIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.maybePop(context),
                  size: 36,
                  backgroundColor: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
            actions: [
              RoundIconButton(
                icon: Icons.bookmark_border_rounded,
                onTap: () {},
                size: 36,
                backgroundColor: Colors.white.withValues(alpha: 0.88),
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/hero_ink.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(-0.1, -0.2),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.surfaceWarm.withValues(alpha: 0.94),
                        ],
                        stops: const [0.5, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    4,
                    24,
                    MediaQuery.paddingOf(context).bottom + 34,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TagPill(
                            label: tag,
                            color: AppColors.cinnabar,
                            background: AppColors.cinnabarSoft,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: AppTheme.serif(
                          fontSize: 28,
                          height: 1.4,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        excerpt,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.8,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        height: 1,
                        color: AppColors.inkMuted.withValues(alpha: 0.14),
                      ),
                      const SizedBox(height: 22),
                      const _Paragraph(
                        '在青溪村的老祠堂里，保存着一只樟木箱。箱子里是六册手抄族谱，纸页已经发黄，边角被无数次翻阅磨得发亮。最早的一册，落款是康熙二十三年。',
                      ),
                      const SizedBox(height: 16),
                      const _Paragraph(
                        '谱序里写着：“水有源，木有本，族之有谱，所以别亲疏、明世次、敦孝悌也。”对张氏后人来说，族谱并不是一份名单，而是一条可以把今天的人带回从前的路。',
                      ),
                      const SizedBox(height: 16),
                      const _Paragraph(
                        '2024 年冬天，族人开始把这些旧谱逐页扫描、录入。有人负责辨认繁体字，有人负责核对生卒年月，还有人专程去外地寻找迁出的支系。数字化的过程，也成为一次重新认识家族的过程。',
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: const Border(
                            left: BorderSide(
                              color: AppColors.cinnabar,
                              width: 3,
                            ),
                          ),
                        ),
                        child: const Text(
                          '“谱之所载，非止名讳。愿后来者知来处，亦知归处。”',
                          style: TextStyle(
                            fontFamily: AppTheme.serifFamily,
                            fontSize: 14,
                            height: 1.8,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Paragraph(
                        '今天，这套手抄谱仍放在老宅。不同的是，它有了一个可以被更多族人读到的数字版本。故事还在继续，等待着下一代人写下新的页码。',
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: AppColors.cinnabarSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: AppColors.cinnabar,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '张氏族谱编委会',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '整理 · 2025 年 4 月',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, height: 1.95, color: AppColors.ink),
    );
  }
}
