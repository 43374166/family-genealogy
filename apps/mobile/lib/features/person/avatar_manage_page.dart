import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../services/app_session.dart';
import '../person/avatar_actions.dart';

/// Owner/admin tool to update any family member's avatar without having to
/// open every person's profile.
class AvatarManagePage extends StatelessWidget {
  const AvatarManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final members = [...session.treeMembers]
      ..sort((a, b) {
        final generation = a.generation.compareTo(b.generation);
        if (generation != 0) return generation;
        return a.name.compareTo(b.name);
      });
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '成员头像', subtitle: '族长和管理员可以为任意成员设置头像'),
            Expanded(
              child: members.isEmpty
                  ? const Center(
                      child: Text(
                        '族谱中还没有人物',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        8,
                        18,
                        MediaQuery.paddingOf(context).bottom + 26,
                      ),
                      itemCount: members.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              InkPortrait(
                                person: member,
                                width: 48,
                                height: 56,
                                radius: 12,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${member.generationLabel} · ${member.hasAvatar ? '已设置头像' : '默认头像'}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => showAvatarActions(
                                  context,
                                  personId: member.id,
                                  canRemove: member.hasAvatar,
                                ),
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  '设置头像',
                                  style: TextStyle(fontSize: 11),
                                ),
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
}
