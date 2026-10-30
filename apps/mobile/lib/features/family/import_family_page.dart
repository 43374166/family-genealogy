import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../search/member_search_page.dart';
import 'qr_scan_page.dart';

class ImportFamilyPage extends StatefulWidget {
  const ImportFamilyPage({super.key});

  @override
  State<ImportFamilyPage> createState() => _ImportFamilyPageState();
}

class _ImportFamilyPageState extends State<ImportFamilyPage> {
  final _code = TextEditingController();
  List<ApiBranch> _branches = const [];
  String? _branchId;
  int _generation = 1;
  ApiImportPreview? _preview;
  ApiPerson? _parent;
  String _parentRole = 'father';
  bool _loading = true;
  bool _previewing = false;
  bool _importing = false;
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _loadBranches();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await SessionScope.of(context).branches();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _branchId = branches.isNotEmpty ? branches.first.id : null;
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

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScanPage()),
    );
    if (value != null && mounted) {
      setState(() {
        _code.text = value.trim().toUpperCase();
        _preview = null;
        _error = null;
      });
    }
  }

  Future<void> _loadPreview() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _error = '请输入有效导入码');
      return;
    }
    setState(() {
      _previewing = true;
      _error = null;
    });
    try {
      final preview = await SessionScope.of(context).previewImportPackage(code);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _generation = 1;
        _previewing = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _previewing = false;
        _error = error.message;
      });
    }
  }

  Future<void> _pickParent() async {
    final person = await Navigator.of(context).push<ApiPerson>(
      MaterialPageRoute<ApiPerson>(
        builder: (_) => const MemberSearchPage(selectMode: true),
      ),
    );
    if (person != null && mounted) {
      setState(() => _parent = person);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null || _branchId == null) {
      setState(() => _error = '请先预览并选择目标家支');
      return;
    }
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final result = await SessionScope.of(context).importPackage(
        code: preview.code,
        branchId: _branchId!,
        rootGeneration: _generation,
        parentId: _parent?.id ?? '',
        parentRole: _parent == null ? '' : _parentRole,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入完成'),
          content: Text(
            '已从 ${result.sourceFamilyName} 导入 ${result.personCount} 人，'
            '${result.rootName} 位于第${result.rootGeneration}世。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '导入旁支数据', subtitle: '输入导入码，选择挂靠分支和世代'),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                      children: [
                        TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            labelText: '导入码',
                            hintText: '请目标族长提供',
                            prefixIcon: const Icon(Icons.inbox_outlined),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _previewing ? null : _loadPreview,
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 17,
                                ),
                                label: const Text('预览数据'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _scan,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18,
                              ),
                              label: const Text('扫码'),
                            ),
                          ],
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
                        if (preview != null) ...[
                          const SizedBox(height: 16),
                          SoftCard(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '来自「${preview.sourceFamilyName}」',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '根人物：${preview.rootName} · ${preview.personCount} 人 · '
                                  '${preview.relationshipCount} 条关系',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 5,
                                  children: [
                                    for (final person in preview.persons.take(
                                      12,
                                    ))
                                      Chip(
                                        label: Text(
                                          '${person.fullName} · 第${person.generationNo}世',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    if (preview.persons.length > 12)
                                      Chip(
                                        label: Text(
                                          '还有 ${preview.persons.length - 12} 人',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '放到哪个家支',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _branchId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              for (final branch in _branches)
                                DropdownMenuItem(
                                  value: branch.id,
                                  child: Text(
                                    branch.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _branchId = value),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '根的世代',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: _generation,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              for (var i = 1; i <= 20; i++)
                                DropdownMenuItem(value: i, child: Text('第$i世')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _generation = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '挂到现有长辈下（可选）',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _pickParent,
                            icon: const Icon(
                              Icons.person_pin_circle_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _parent == null
                                  ? '选择父/母（不选则作为独立根）'
                                  : '${_parent!.fullName} · ${_parent!.generationLabel}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                          if (_parent != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('父亲'),
                                  selected: _parentRole == 'father',
                                  onSelected: (_) =>
                                      setState(() => _parentRole = 'father'),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('母亲'),
                                  selected: _parentRole == 'mother',
                                  onSelected: (_) =>
                                      setState(() => _parentRole = 'mother'),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _importing ? null : _import,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _importing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('确认导入'),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
