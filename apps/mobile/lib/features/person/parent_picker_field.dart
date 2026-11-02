import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_models.dart';
import '../search/member_search_page.dart';

class ParentPickerField extends StatelessWidget {
  const ParentPickerField({
    super.key,
    required this.label,
    required this.personId,
    required this.personName,
    required this.onPick,
    required this.onClear,
    this.hint = '点击选择',
  });

  final String label;
  final String? personId;
  final String personName;
  final ValueChanged<ApiPerson> onPick;
  final VoidCallback onClear;
  final String hint;

  Future<void> _pick(BuildContext context) async {
    final person = await Navigator.of(context).push<ApiPerson>(
      MaterialPageRoute<ApiPerson>(
        builder: (_) => const MemberSearchPage(selectMode: true),
      ),
    );
    if (person != null) onPick(person);
  }

  @override
  Widget build(BuildContext context) {
    final selected = personId != null && personId!.isNotEmpty;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(
              label == '父亲' ? Icons.man_outlined : Icons.woman_outlined,
              size: 19,
              color: selected ? AppColors.primary : AppColors.inkMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    selected ? personName : hint,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.ink : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              IconButton(
                onPressed: onClear,
                tooltip: '清除',
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.inkMuted,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: AppColors.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}
