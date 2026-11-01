import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import 'lunar_date_picker.dart';

class EditPersonPage extends StatefulWidget {
  const EditPersonPage({super.key, required this.person});

  final ApiPerson person;

  @override
  State<EditPersonPage> createState() => _EditPersonPageState();
}

class _EditPersonPageState extends State<EditPersonPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _surname;
  late final TextEditingController _givenName;
  late final TextEditingController _courtesyName;
  late final TextEditingController _alias;
  late final TextEditingController _birthOrder;
  ApiPartialDate? _birth;
  ApiPartialDate? _death;
  late final TextEditingController _birthPlace;
  late final TextEditingController _residence;
  late final TextEditingController _occupation;
  late final TextEditingController _education;
  late final TextEditingController _biography;

  List<ApiBranch> _branches = const [];
  String? _branchId;
  late String _gender;
  late String _lifeStatus;
  late int _generation;
  bool _loadingBranches = true;
  bool _submitting = false;
  bool _started = false;
  bool _canWrite = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    _surname = TextEditingController(text: person.surname);
    _givenName = TextEditingController(text: person.givenName);
    _courtesyName = TextEditingController(text: person.courtesyName);
    _alias = TextEditingController(text: person.alias);
    _birthOrder = TextEditingController(text: person.birthOrder?.toString());
    _birth = person.birth;
    _death = person.death;
    _birthPlace = TextEditingController(text: person.birthPlace);
    _residence = TextEditingController(text: person.residence);
    _occupation = TextEditingController(text: person.occupation);
    _education = TextEditingController(text: person.education);
    _biography = TextEditingController(text: person.biography);
    _gender = person.gender;
    _lifeStatus = person.lifeStatus;
    _generation = person.generationNo;
    _branchId = person.branchId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _canWrite = SessionScope.of(context).canWrite;
    _loadBranches();
  }

  @override
  void dispose() {
    for (final controller in [
      _surname,
      _givenName,
      _courtesyName,
      _alias,
      _birthOrder,
      _birthPlace,
      _residence,
      _occupation,
      _education,
      _biography,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await SessionScope.of(context).branches();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        if (_branchId == null ||
            !branches.any((branch) => branch.id == _branchId)) {
          _branchId = branches.isNotEmpty ? branches.first.id : null;
        }
        _loadingBranches = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loadingBranches = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_branchId == null) {
      setState(() => _error = '请选择所属家支');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = SessionScope.of(context);
      final surname = _surname.text.trim();
      final givenName = _givenName.text.trim();
      final courtesyName = _courtesyName.text.trim();
      final alias = _alias.text.trim();
      final birthOrder = int.tryParse(_birthOrder.text.trim());
      final birth = _birth;
      final death = _lifeStatus == 'deceased' ? _death : null;
      final birthPlace = _birthPlace.text.trim();
      final residence = _residence.text.trim();
      final occupation = _occupation.text.trim();
      final education = _education.text.trim();
      final biography = _biography.text.trim();
      if (_canWrite) {
        await session.updatePerson(
          personId: widget.person.id,
          surname: surname,
          givenName: givenName,
          courtesyName: courtesyName,
          alias: alias,
          gender: _gender,
          generationNo: _generation,
          branchId: _branchId!,
          birthOrder: birthOrder,
          birth: birth,
          death: death,
          lifeStatus: _lifeStatus,
          birthPlace: birthPlace,
          residence: residence,
          occupation: occupation,
          education: education,
          biography: biography,
          version: widget.person.version,
        );
      } else {
        await session.createProfileRequest(
          personId: widget.person.id,
          surname: surname,
          givenName: givenName,
          courtesyName: courtesyName,
          alias: alias,
          gender: _gender,
          generationNo: _generation,
          branchId: _branchId!,
          birthOrder: birthOrder,
          birth: birth,
          death: death,
          lifeStatus: _lifeStatus,
          birthPlace: birthPlace,
          residence: residence,
          occupation: occupation,
          education: education,
          biography: biography,
          version: widget.person.version,
        );
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_canWrite ? '资料已保存' : '申请已提交'),
          content: Text(_canWrite ? '人物资料已更新，族谱会同步刷新。' : '修改申请已提交，等待族长或管理员审核。'),
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
        _submitting = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final generations = <int>{
      1,
      for (var i = -2; i <= 2; i++) _generation + i,
    }.where((value) => value > 0).toList()..sort();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '编辑人物',
              subtitle: _canWrite ? '修改后直接写入族谱并记审计' : '提交族长或管理员审核',
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                  children: [
                    SoftCard(
                      padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: '基本信息'),
                          const SizedBox(height: 12),
                          _field(_surname, '姓', required: true),
                          const SizedBox(height: 10),
                          _field(_givenName, '名', required: true),
                          const SizedBox(height: 10),
                          _field(_courtesyName, '字号'),
                          const SizedBox(height: 10),
                          _field(_alias, '别名'),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(
                              labelText: '性别',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('男')),
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
                                child: Text('未详'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _gender = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _generation,
                            decoration: const InputDecoration(
                              labelText: '世代',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final generation in generations)
                                DropdownMenuItem(
                                  value: generation,
                                  child: Text('第$generation世'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _generation = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          if (_loadingBranches)
                            const LinearProgressIndicator(minHeight: 2)
                          else
                            DropdownButtonFormField<String>(
                              initialValue: _branchId,
                              decoration: const InputDecoration(
                                labelText: '所属家支',
                                border: OutlineInputBorder(),
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
                          DropdownButtonFormField<String>(
                            initialValue: _lifeStatus,
                            decoration: const InputDecoration(
                              labelText: '在世状态',
                              border: OutlineInputBorder(),
                            ),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: '生卒与生平'),
                          const SizedBox(height: 12),
                          LunarDatePickerField(
                            label: '出生日期',
                            value: _birth,
                            hint: '选择公历或农历生日',
                            onChanged: (value) =>
                                setState(() => _birth = value),
                          ),
                          const SizedBox(height: 10),
                          if (_lifeStatus == 'deceased')
                            LunarDatePickerField(
                              label: '逝世日期',
                              value: _death,
                              hint: '选择公历或农历祭日',
                              onChanged: (value) =>
                                  setState(() => _death = value),
                            ),
                          if (_lifeStatus == 'deceased')
                            const SizedBox(height: 10),
                          _field(
                            _birthOrder,
                            '排行',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 10),
                          _field(_birthPlace, '籍贯'),
                          const SizedBox(height: 10),
                          _field(_residence, '现居地'),
                          const SizedBox(height: 10),
                          _field(_occupation, '职业'),
                          const SizedBox(height: 10),
                          _field(_education, '教育'),
                          const SizedBox(height: 10),
                          _field(_biography, '生平', maxLines: 5),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.cinnabar,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
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
                          : Text(_canWrite ? '保存修改' : '提交审核'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: required
          ? (value) => (value ?? '').trim().isEmpty ? '请输入$label' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
