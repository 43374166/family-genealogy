import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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
    final names = SessionScope.of(context).generationNames;
    if (names.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: '字辈',
          border: OutlineInputBorder(),
        ),
        child: const Text(
          '族长尚未设置字辈',
          style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      );
    }
    final selected =
        _selected ??
        (names.any((item) => item.generationNo == widget.currentGeneration)
            ? widget.currentGeneration
            : null);
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '字辈',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selected,
          isExpanded: true,
          hint: const Text(
            '选择字辈，自动匹配世代',
            style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
          items: [
            for (final item in names)
              DropdownMenuItem(
                value: item.generationNo,
                child: Text(
                  '第${item.generationNo}世 · ${item.name}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) _select(value);
          },
        ),
      ),
    );
  }
}
