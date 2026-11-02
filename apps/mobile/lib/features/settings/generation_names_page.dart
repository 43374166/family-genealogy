import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class GenerationNamesPage extends StatefulWidget {
  const GenerationNamesPage({super.key});

  @override
  State<GenerationNamesPage> createState() => _GenerationNamesPageState();
}

class _GenerationNamesPageState extends State<GenerationNamesPage> {
  final TextEditingController _poem = TextEditingController();
  final List<String> _chars = [];
  final List<TextEditingController> _fieldControllers = [];
  bool _started = false;
  bool _saving = false;
  bool _syncing = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final session = SessionScope.of(context);
    final existing = session.generationNames;
    final maxGeneration = existing.isEmpty
        ? 0
        : existing
              .map((item) => item.generationNo)
              .reduce((a, b) => a > b ? a : b);
    if (maxGeneration > 0) {
      for (var i = 1; i <= maxGeneration; i++) {
        _chars.add('');
      }
      for (final item in existing) {
        if (item.generationNo >= 1 && item.generationNo <= _chars.length) {
          _chars[item.generationNo - 1] = item.name;
        }
      }
      while (_chars.isNotEmpty && _chars.last.isEmpty) {
        _chars.removeLast();
      }
    }
    _poem.text = session.generationPoem.isNotEmpty
        ? session.generationPoem
        : _formatPoem(_chars);
    _rebuildFieldControllers();
  }

  @override
  void dispose() {
    _poem.dispose();
    for (final controller in _fieldControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatPoem(List<String> chars) {
    const perLine = 14; // Two seven-character phrases per row.
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i += perLine) {
      if (i > 0) buffer.write('\n');
      final end = (i + perLine < chars.length) ? i + perLine : chars.length;
      buffer.write(chars.sublist(i, end).join());
    }
    return buffer.toString();
  }

  List<String> _parsePoem(String text) {
    final matches = RegExp(r'[\u4e00-\u9fffA-Za-z0-9]').allMatches(text);
    return matches
        .map((match) => match.group(0)!)
        .take(99)
        .toList(growable: true);
  }

  void _rebuildFieldControllers() {
    final retired = List<TextEditingController>.from(_fieldControllers);
    _fieldControllers.clear();
    for (final char in _chars) {
      _fieldControllers.add(TextEditingController(text: char));
    }
    if (retired.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in retired) {
          controller.dispose();
        }
      });
    }
  }

  void _onPoemChanged(String text) {
    if (_syncing) return;
    final parsed = _parsePoem(text);
    setState(() {
      _chars
        ..clear()
        ..addAll(parsed);
      _rebuildFieldControllers();
    });
  }

  String _replaceNthCharacter(String text, int index, String replacement) {
    final matches = RegExp(
      r'[\u4e00-\u9fffA-Za-z0-9]',
    ).allMatches(text).toList();
    if (index < 0 || index >= matches.length) return text;
    final buffer = StringBuffer();
    var cursor = 0;
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      buffer.write(text.substring(cursor, match.start));
      buffer.write(i == index ? replacement : match.group(0));
      cursor = match.end;
    }
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  void _onCharChanged(int index, String value) {
    if (_syncing) return;
    _syncing = true;
    setState(() => _chars[index] = value);
    final updated = _replaceNthCharacter(_poem.text, index, value);
    _poem.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
    _syncing = false;
  }

  Future<void> _save() async {
    final items = <ApiGenerationName>[];
    for (var i = 0; i < _chars.length; i++) {
      final name = _chars[i].trim();
      if (name.isEmpty) continue;
      items.add(ApiGenerationName(generationNo: i + 1, name: name));
    }
    if (items.isEmpty) {
      setState(() => _error = '请先输入字辈诗或至少一个字的字辈');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SessionScope.of(
        context,
      ).saveGenerationNames(items, poem: _poem.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('字辈已保存，族谱树已同步')));
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = (_chars.length + 6) ~/ 7;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '字辈',
              subtitle: '输入字辈诗，自动解析成世代',
              actions: [
                IconButton(
                  onPressed: _saving ? null : _save,
                  tooltip: '保存字辈',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  icon: const Icon(
                    Icons.save_outlined,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(15, 13, 15, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '字辈诗',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '按原文输入，标点和换行会自动忽略；一般每行两句，每句七字。',
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 9),
                        TextField(
                          controller: _poem,
                          minLines: 4,
                          maxLines: 4,
                          onChanged: _onPoemChanged,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            letterSpacing: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: '例如：\n永怀先祖德，远绍旧家风\n忠厚传家久，诗书继世长',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              height: 1.7,
                              letterSpacing: 0,
                              color: AppColors.inkMuted,
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '已解析 ${_chars.length} 字 · $columns 列',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_chars.isNotEmpty) ...[
                    const Text(
                      '字辈排列',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SoftCard(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var column = 0; column < columns; column++)
                              _CharacterColumn(
                                index: column,
                                chars: _columnChars(column),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    '逐世字辈',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '这里只改单个字，上方字辈诗会自动同步。',
                    style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _chars.length; i++) ...[
                    _GenerationCharField(
                      generation: i + 1,
                      controller: _fieldControllers[i],
                      onChanged: (value) => _onCharChanged(i, value),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_chars.isEmpty)
                    const SoftCard(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '输入字辈诗后，会在这里自动生成每一世的输入框。',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.cinnabar,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('保存字辈'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _columnChars(int column) {
    final start = column * 7;
    final end = (start + 7 < _chars.length) ? start + 7 : _chars.length;
    if (start >= _chars.length) return const [];
    return _chars.sublist(start, end);
  }
}

class _CharacterColumn extends StatelessWidget {
  const _CharacterColumn({required this.index, required this.chars});

  final int index;
  final List<String> chars;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Column(
        children: [
          Text(
            '${index + 1}',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < 7; row++)
            Container(
              width: 34,
              height: 32,
              margin: const EdgeInsets.only(bottom: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: row < chars.length
                    ? AppColors.surfaceWarm
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row < chars.length ? chars[row] : '',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GenerationCharField extends StatelessWidget {
  const _GenerationCharField({
    required this.generation,
    required this.controller,
    required this.onChanged,
  });

  final int generation;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            '第$generation世',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            maxLength: 1,
            onChanged: onChanged,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
