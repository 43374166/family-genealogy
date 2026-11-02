import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import 'lunar_date_picker.dart';
import 'parent_picker_field.dart';

class AddPersonPage extends StatefulWidget {
  const AddPersonPage({super.key});

  @override
  State<AddPersonPage> createState() => _AddPersonPageState();
}

class _AddPersonPageState extends State<AddPersonPage> {
  final _formKey = GlobalKey<FormState>();
  final _surname = TextEditingController();
  final _givenName = TextEditingController();
  final _birthOrder = TextEditingController();
  final _biography = TextEditingController();
  ApiPartialDate? _birth;
  ApiPartialDate? _death;
  ApiPerson? _father;
  ApiPerson? _mother;
  String _lifeStatus = 'living';

  List<ApiBranch> _branches = const [];
  String? _branchId;
  int _generation = 1;
  String _gender = 'male';
  bool _loading = true;
  bool _submitting = false;
  bool _started = false;
  bool _canWrite = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final session = SessionScope.of(context);
    _canWrite = session.canWrite;
    _surname.text = session.family?.surname ?? '凌';
    final generations = session.tree?.persons
        .map((person) => person.generationNo)
        .toList();
    _generation = generations == null || generations.isEmpty
        ? 1
        : generations.reduce((a, b) => a > b ? a : b);
    _loadBranches();
  }

  @override
  void dispose() {
    _surname.dispose();
    _givenName.dispose();
    _birthOrder.dispose();
    _biography.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_branchId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择所属家支')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = SessionScope.of(context);
      final surname = _surname.text.trim();
      final givenName = _givenName.text.trim();
      final birthOrder = int.tryParse(_birthOrder.text.trim());
      final birth = _birth;
      final death = _lifeStatus == 'deceased' ? _death : null;
      final biography = _biography.text.trim();
      if (_father != null && _mother != null && _father!.id == _mother!.id) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('父亲和母亲不能选择同一个人')));
        return;
      }
      if (session.canWrite) {
        final person = await session.createPerson(
          surname: surname,
          givenName: givenName,
          gender: _gender,
          generationNo: _generation,
          branchId: _branchId!,
          birthOrder: birthOrder,
          birth: birth,
          death: death,
          lifeStatus: _lifeStatus,
          biography: biography,
        );
        if (_father != null) {
          await session.addParentChild(
            parentId: _father!.id,
            childId: person.id,
            parentRole: 'father',
          );
        }
        if (_mother != null) {
          await session.addParentChild(
            parentId: _mother!.id,
            childId: person.id,
            parentRole: 'mother',
          );
        }
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('已加入族谱'),
            content: Text(
              '${person.fullName} 已写入 ${person.generationLabel}，可以继续添加父母、配偶或子女关系。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else {
        await session.createWriteRequest(
          requestType: 'create_person',
          payload: {
            'surname': surname,
            'givenName': givenName,
            'gender': _gender,
            'generationNo': _generation,
            'branchId': _branchId,
            'birthOrder': birthOrder,
            ...?birth?.toJson(prefix: 'birth'),
            ...?death?.toJson(prefix: 'death'),
            'lifeStatus': _lifeStatus,
            'biography': biography,
          },
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('申请已提交'),
            content: Text('新增 $surname$givenName 的申请已提交，等待族长或管理员审核。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('新增人物失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyName = SessionScope.of(context).family?.name ?? '当前家庭';
    final generations = _generationOptions();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppPageHeader(
                title: '新增人物',
                subtitle: '$familyName · ${_canWrite ? '直接写入族谱' : '提交族长审核'}',
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : _error != null
                    ? _ErrorBody(error: _error!, onRetry: _loadBranches)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.jadeSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD2E8DD),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.account_tree_outlined,
                                    size: 17,
                                    color: AppColors.jade,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _canWrite
                                        ? '人物会先作为一个独立节点写入族谱。保存后再添加父母、配偶和子女关系。'
                                        : '申请通过后，人物才会写入族谱。保存后再添加父母、配偶和子女关系。',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      height: 1.65,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SoftCard(
                            padding: const EdgeInsets.fromLTRB(17, 16, 17, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionTitle(title: '基本信息'),
                                const SizedBox(height: 15),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _TextField(
                                        controller: _surname,
                                        label: '姓',
                                        hint: '凌',
                                        validator: (value) =>
                                            (value ?? '').trim().isEmpty
                                            ? '请输入姓'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 4,
                                      child: _TextField(
                                        controller: _givenName,
                                        label: '名',
                                        hint: '例如：成铭',
                                        validator: (value) =>
                                            (value ?? '').trim().isEmpty
                                            ? '请输入名'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 13),
                                const _FieldLabel('性别'),
                                DropdownButtonFormField<String>(
                                  initialValue: _gender,
                                  decoration: _inputDecoration(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'male',
                                      child: Text('男'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'female',
                                      child: Text('女'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'other',
                                      child: Text('其他'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'unknown',
                                      child: Text('未注明'),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _gender = value ?? 'male'),
                                ),
                                const SizedBox(height: 13),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _FieldLabel('世代'),
                                          DropdownButtonFormField<int>(
                                            initialValue: _generation,
                                            decoration: _inputDecoration(),
                                            items: [
                                              for (final generation
                                                  in generations)
                                                DropdownMenuItem(
                                                  value: generation,
                                                  child: Text('第$generation世'),
                                                ),
                                            ],
                                            onChanged: (value) => setState(
                                              () => _generation =
                                                  value ?? _generation,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _FieldLabel('出生顺序'),
                                          _TextField(
                                            controller: _birthOrder,
                                            hint: '可选',
                                            keyboardType: TextInputType.number,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 13),
                                const _FieldLabel('所属家支'),
                                DropdownButtonFormField<String>(
                                  initialValue: _branchId,
                                  decoration: _inputDecoration(),
                                  items: [
                                    for (final branch in _orderedBranches())
                                      DropdownMenuItem(
                                        value: branch.id,
                                        child: Text(
                                          '${List.filled(_branchDepth(branch), '　').join()}${branch.name}',
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _branchId = value),
                                ),
                                const SizedBox(height: 13),
                                const _FieldLabel('生卒状态'),
                                DropdownButtonFormField<String>(
                                  initialValue: _lifeStatus,
                                  decoration: _inputDecoration(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'living',
                                      child: Text('在世'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'deceased',
                                      child: Text('已故'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'unknown',
                                      child: Text('未详'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _lifeStatus = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 13),
                                LunarDatePickerField(
                                  label: '出生日期',
                                  value: _birth,
                                  hint: '选择公历或农历生日',
                                  onChanged: (value) =>
                                      setState(() => _birth = value),
                                ),
                                if (_lifeStatus == 'deceased') ...[
                                  const SizedBox(height: 13),
                                  LunarDatePickerField(
                                    label: '逝世日期',
                                    value: _death,
                                    hint: '选择公历或农历祭日',
                                    onChanged: (value) =>
                                        setState(() => _death = value),
                                  ),
                                ],
                                if (_canWrite) ...[
                                  const SizedBox(height: 13),
                                  const _FieldLabel('父母（可选）'),
                                  ParentPickerField(
                                    label: '父亲',
                                    personId: _father?.id,
                                    personName: _father?.fullName ?? '',
                                    onPick: (person) =>
                                        setState(() => _father = person),
                                    onClear: () =>
                                        setState(() => _father = null),
                                  ),
                                  const SizedBox(height: 8),
                                  ParentPickerField(
                                    label: '母亲',
                                    personId: _mother?.id,
                                    personName: _mother?.fullName ?? '',
                                    onPick: (person) =>
                                        setState(() => _mother = person),
                                    onClear: () =>
                                        setState(() => _mother = null),
                                  ),
                                ],
                                const SizedBox(height: 13),
                                const _FieldLabel('生平简介'),
                                _TextField(
                                  controller: _biography,
                                  hint: '可稍后补充',
                                  maxLines: 3,
                                  maxLength: 2000,
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
      ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 9, 18, 12),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: Color(0xFFE9EEF0))),
                ),
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_canWrite ? '保存到族谱' : '提交审核'),
                ),
              ),
            ),
    );
  }

  List<int> _generationOptions() {
    final maxGeneration =
        SessionScope.of(context).tree?.persons
            .map((person) => person.generationNo)
            .fold<int>(1, (max, value) => value > max ? value : max) ??
        1;
    final max = maxGeneration + 1;
    return [for (var i = 1; i <= max; i++) i];
  }

  List<ApiBranch> _orderedBranches() {
    final byParent = <String?, List<ApiBranch>>{};
    for (final branch in _branches) {
      byParent.putIfAbsent(branch.parentId, () => []).add(branch);
    }
    final result = <ApiBranch>[];
    void visit(String? parent) {
      for (final branch in byParent[parent] ?? const <ApiBranch>[]) {
        result.add(branch);
        visit(branch.id);
      }
    }

    visit(null);
    return result;
  }

  int _branchDepth(ApiBranch branch) {
    var depth = 0;
    var parentId = branch.parentId;
    while (parentId != null) {
      depth++;
      ApiBranch? parent;
      for (final item in _branches) {
        if (item.id == parentId) {
          parent = item;
          break;
        }
      }
      parentId = parent?.parentId;
    }
    return depth;
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength = 60,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final TextInputType? keyboardType;
  final int maxLines;
  final int maxLength;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: _inputDecoration(hint: hint),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_FieldLabel(label!), field],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    counterText: '',
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    filled: true,
    fillColor: const Color(0xFFF7F9FA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE9EEF0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
