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
  final List<_GenerationRow> _rows = [];
  bool _started = false;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final existing = SessionScope.of(context).generationNames;
    final maxGeneration = existing.isEmpty
        ? 5
        : existing
              .map((item) => item.generationNo)
              .reduce((a, b) => a > b ? a : b);
    final limit = maxGeneration < 5 ? 5 : maxGeneration;
    final byGeneration = {
      for (final item in existing) item.generationNo: item.name,
    };
    for (var generation = 1; generation <= limit; generation++) {
      _rows.add(
        _GenerationRow(
          generation: generation,
          controller: TextEditingController(
            text: byGeneration[generation] ?? '',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  void _addGeneration() {
    if (_rows.length >= 99) return;
    setState(() {
      _rows.add(
        _GenerationRow(
          generation: _rows.length + 1,
          controller: TextEditingController(),
        ),
      );
    });
  }

  Future<void> _save() async {
    final items = <ApiGenerationName>[];
    for (final row in _rows) {
      final name = row.controller.text.trim();
      if (name.isEmpty) continue;
      if (name.runes.length > 20) {
        setState(() => _error = '第${row.generation}世的字辈不能超过 20 个字');
        return;
      }
      items.add(ApiGenerationName(generationNo: row.generation, name: name));
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).saveGenerationNames(items);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '字辈', subtitle: '按世代记录家族字辈'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
                children: [
                  const SoftCard(
                    padding: EdgeInsets.all(15),
                    child: Text(
                      '字辈按“第几世”对应，例如第 1 世“永”、第 2 世“远”。\n'
                      '添加或修改人物时选择字辈，会自动对应到该世代；如果选错世代，会提示你确认。',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.75,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final row in _rows) ...[
                    _GenerationField(
                      generation: row.generation,
                      controller: row.controller,
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _addGeneration,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('增加下一世'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
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
                        borderRadius: BorderRadius.circular(15),
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
}

class _GenerationRow {
  _GenerationRow({required this.generation, required this.controller});

  final int generation;
  final TextEditingController controller;
}

class _GenerationField extends StatelessWidget {
  const _GenerationField({required this.generation, required this.controller});

  final int generation;
  final TextEditingController controller;

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
            maxLength: 20,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: '例如：永',
              counterText: '',
              filled: true,
              fillColor: AppColors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
