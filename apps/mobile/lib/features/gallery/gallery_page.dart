import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_data.dart';
import '../../models/family_member.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles =
        <({FamilyMember person, String title, String note, Color tint})>[
          (
            person: DemoData.zhangTianming,
            title: '先祖画像',
            note: '清 · 乾隆年间',
            tint: const Color(0xFFD9CEBC),
          ),
          (
            person: DemoData.linShi,
            title: '祖妣画像',
            note: '清 · 乾隆年间',
            tint: const Color(0xFFE4D9D2),
          ),
          (
            person: DemoData.zhangYi,
            title: '杭州合影',
            note: '2025 · 春祭',
            tint: const Color(0xFFCBDDE0),
          ),
          (
            person: DemoData.yuMeng,
            title: '新居留影',
            note: '2024 · 初冬',
            tint: const Color(0xFFDCD7E7),
          ),
        ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '家族相册',
              subtitle: '128 位成员 · 36 张影像',
              actions: [
                HeaderIconButton(
                  icon: Icons.add_photo_alternate_outlined,
                  onTap: () => _notice(context),
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
                  _FeatureMemory(onTap: () => _notice(context)),
                  const SizedBox(height: 20),
                  const SectionTitle(title: '影像集', actionLabel: '全部'),
                  const SizedBox(height: 11),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tiles.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.92,
                        ),
                    itemBuilder: (context, index) {
                      final tile = tiles[index];
                      return _MemoryTile(
                        person: tile.person,
                        title: tile.title,
                        note: tile.note,
                        tint: tile.tint,
                        onTap: () => _showMemory(
                          context,
                          tile.person,
                          tile.title,
                          tile.note,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  SoftCard(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.tealSoft,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(width: 11),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '家族影像仅对族人可见',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '上传、查看原图与下载能力将在服务端接入后开放',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: AppColors.inkMuted,
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
          ],
        ),
      ),
    );
  }

  void _notice(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('相册上传将在服务端接入后开放')));
  }

  void _showMemory(
    BuildContext context,
    FamilyMember person,
    String title,
    String note,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            AspectRatio(
              aspectRatio: 1.5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE9E1D2), Color(0xFFC9DADC)],
                  ),
                ),
                child: Center(
                  child: InkPortrait(
                    person: person,
                    width: 126,
                    height: 154,
                    radius: 18,
                    showBorder: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.serif(fontSize: 20)),
                      const SizedBox(height: 3),
                      Text(
                        note,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TagPill(
                  label: '家族影像',
                  color: AppColors.teal,
                  background: AppColors.tealSoft,
                  icon: Icons.photo_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '这是一张用于界面演示的插画占位图。接入媒体服务后，此处将展示经权限校验的原图与说明。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.7,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureMemory extends StatelessWidget {
  const _FeatureMemory({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 198,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1520323B),
              blurRadius: 22,
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
              alignment: const Alignment(0.2, -0.4),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB31A292F)],
                  stops: [0.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 17,
              top: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '封面影像',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 18,
              right: 18,
              bottom: 17,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '青溪老宅 · 春祭',
                    style: TextStyle(
                      fontSize: 19,
                      fontFamily: AppTheme.serifFamily,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '2025 年 4 月 · 长房',
                    style: TextStyle(fontSize: 10.5, color: Color(0xD9FFFFFF)),
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

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({
    required this.person,
    required this.title,
    required this.note,
    required this.tint,
    required this.onTap,
  });

  final FamilyMember person;
  final String title;
  final String note;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -18,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -4,
              child: InkPortrait(
                person: person,
                width: 118,
                height: 142,
                radius: 0,
              ),
            ),
            Positioned(
              left: 13,
              top: 14,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            Positioned(
              left: 13,
              bottom: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontFamily: AppTheme.serifFamily,
                      color: AppColors.ink.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.ink.withValues(alpha: 0.52),
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
