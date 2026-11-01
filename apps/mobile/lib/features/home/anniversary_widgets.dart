import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_models.dart';
import '../person/api_person_detail_page.dart';

class AnniversarySection extends StatelessWidget {
  const AnniversarySection({
    super.key,
    required this.items,
    required this.loading,
    required this.onMore,
  });

  final List<ApiAnniversary> items;
  final bool loading;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) return const SizedBox.shrink();
    final preview = items.take(3).toList(growable: false);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cake_outlined,
                size: 17,
                color: AppColors.cinnabar,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  '近期生日与祭日',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: onMore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('全部', style: TextStyle(fontSize: 10.5)),
                ),
            ],
          ),
          if (preview.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '未来 60 天没有已记录的生日或祭日',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
            )
          else
            for (var i = 0; i < preview.length; i++) ...[
              AnniversaryRow(item: preview[i]),
              if (i != preview.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class AnniversaryRow extends StatelessWidget {
  const AnniversaryRow({super.key, required this.item, this.showYear = false});

  final ApiAnniversary item;
  final bool showYear;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntil == 0 ? '今天' : '${item.daysUntil} 天后';
    final kind = item.isBirthday ? '生日' : '祭日';
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ApiPersonDetailPage(personId: item.personId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.isBirthday
                    ? AppColors.cinnabarSoft
                    : AppColors.slateSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                item.isBirthday
                    ? Icons.cake_outlined
                    : Icons.local_florist_outlined,
                size: 17,
                color: item.isBirthday ? AppColors.cinnabar : AppColors.slate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        kind,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: item.isBirthday
                              ? AppColors.cinnabar
                              : AppColors.slate,
                        ),
                      ),
                      if (item.age != null) ...[
                        const SizedBox(width: 5),
                        Text(
                          item.isBirthday ? '${item.age} 岁' : '${item.age} 年',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '公历 ${item.solarText}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  Text(
                    '农历 ${item.lunarText}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  days,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: item.daysUntil == 0
                        ? AppColors.cinnabar
                        : AppColors.primary,
                  ),
                ),
                if (showYear) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.date,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class AnniversariesPage extends StatelessWidget {
  const AnniversariesPage({super.key, required this.items});

  final List<ApiAnniversary> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '生日与祭日',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                '未来 60 天没有已记录的生日或祭日',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                18,
                8,
                18,
                MediaQuery.paddingOf(context).bottom + 22,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: AnniversaryRow(item: items[index], showYear: true),
              ),
            ),
    );
  }
}
