import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class GenerationNamePicker extends StatefulWidget {
  const GenerationNamePicker({
    super.key,
    required this.currentGeneration,
    required this.onChanged,
  });

  final int currentGeneration;
  final ValueChanged<int> onChanged;

  @override
  State<GenerationNamePicker> createState() => _GenerationNamePickerState();
}

class _GenerationNamePickerState extends State<GenerationNamePicker> {
  int? _selected;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _syncSelection();
  }

  @override
  void didUpdateWidget(covariant GenerationNamePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentGeneration != widget.currentGeneration) {
      _syncSelection();
    }
  }

  void _syncSelection() {
    final names = SessionScope.of(context).generationNames;
    _selected =
        names.any((item) => item.generationNo == widget.currentGeneration)
        ? widget.currentGeneration
        : null;
  }

  Future<void> _pick() async {
    final names = SessionScope.of(context).generationNames;
    if (names.isEmpty) return;
    final generation = await showDialog<int>(
      context: context,
      builder: (_) => _GenerationGridDialog(names: names, selected: _selected),
    );
    if (generation == null || !mounted) return;
    await _select(generation);
  }

  Future<void> _select(int generation) async {
    if (generation == widget.currentGeneration) {
      setState(() => _selected = generation);
      return;
    }
    final session = SessionScope.of(context);
    final name = session.generationNameFor(generation);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('字辈与世代不一致'),
        content: Text(
          '「$name」属于第$generation世，当前人物是第${widget.currentGeneration}世。\n\n'
          '是否把人物改到第$generation世？',
          style: const TextStyle(fontSize: 12.5, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('切换到该世'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      setState(() => _selected = generation);
      widget.onChanged(generation);
    } else {
      setState(() => _selected = widget.currentGeneration);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final names = session.generationNames;
    final selected =
        _selected ??
        (names.any((item) => item.generationNo == widget.currentGeneration)
            ? widget.currentGeneration
            : null);
    final value = selected == null
        ? '未设置'
        : session.generationLabelFor(selected);
    return InkWell(
      onTap: names.isEmpty ? null : _pick,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '字辈',
          border: const OutlineInputBorder(),
          suffixIcon: Icon(
            names.isEmpty
                ? Icons.lock_outline_rounded
                : Icons.grid_view_rounded,
            size: 18,
            color: AppColors.inkMuted,
          ),
        ),
        child: Text(
          names.isEmpty ? '族长尚未设置字辈' : value,
          style: TextStyle(
            fontSize: 12.5,
            color: names.isEmpty ? AppColors.inkMuted : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _GenerationGridDialog extends StatelessWidget {
  const _GenerationGridDialog({required this.names, required this.selected});

  final List<ApiGenerationName> names;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final ordered = [...names]
      ..sort((a, b) => a.generationNo.compareTo(b.generationNo));
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '选择字辈',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const Text(
                '每列 7 字，从左往右排列；点一个字选中对应世代。',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: SingleChildScrollView(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: ordered.length,
                    itemBuilder: (context, index) {
                      final item = ordered[index];
                      final active = item.generationNo == selected;
                      return InkWell(
                        onTap: () => Navigator.pop(context, item.generationNo),
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primarySoft
                                : AppColors.surfaceWarm,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.line,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? AppColors.primary
                                      : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '第${item.generationNo}世',
                                style: const TextStyle(
                                  fontSize: 7,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
