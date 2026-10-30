import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class EditRequestPage extends StatefulWidget {
  const EditRequestPage({
    super.key,
    required this.personId,
    this.initialPerson,
  });

  final String personId;
  final ApiPerson? initialPerson;

  @override
  State<EditRequestPage> createState() => _EditRequestPageState();
}

class _EditRequestPageState extends State<EditRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _birthPlace = TextEditingController();
  final _residence = TextEditingController();
  final _occupation = TextEditingController();
  final _education = TextEditingController();
  final _biography = TextEditingController();

  ApiPerson? _person;
  String? _error;
  bool _loading = true;
  bool _submitting = false;
  bool _started = false;
  bool _showPreview = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Always load the full record before enabling the form. A search result is
    // only a summary and does not carry the editable fields or relationships.
    _person = null;
    _load();
  }

  @override
  void dispose() {
    _birthPlace.dispose();
    _residence.dispose();
    _occupation.dispose();
    _education.dispose();
    _biography.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final person = await SessionScope.of(
        context,
      ).fetchPerson(widget.personId);
      if (!mounted) return;
      _applyPerson(person);
      setState(() {
        _person = person;
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

  void _applyPerson(ApiPerson person) {
    _birthPlace.text = person.birthPlace;
    _residence.text = person.residence;
    _occupation.text = person.occupation;
    _education.text = person.education;
    _biography.text = person.biography;
  }

  ApiEditChanges _changes() {
    final person = _person;
    if (person == null) return const ApiEditChanges();
    String? diff(TextEditingController controller, String original) {
      final value = controller.text.trim();
      return value == original ? null : value;
    }

    return ApiEditChanges(
      birthPlace: diff(_birthPlace, person.birthPlace),
      residence: diff(_residence, person.residence),
      occupation: diff(_occupation, person.occupation),
      education: diff(_education, person.education),
      biography: diff(_biography, person.biography),
    );
  }

  Future<void> _submit() async {
    final person = _person;
    if (person == null || !_formKey.currentState!.validate()) return;
    final changes = _changes();
    if (changes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('还没有修改任何资料')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await SessionScope.of(context).createEditRequest(
        targetPersonId: person.id,
        baseVersion: person.version,
        changes: changes,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('申请已提交'),
          content: Text(
            '已提交 ${changes.fieldKeys.map(ApiEditChanges.labelFor).join('、')} 的修改申请，等待族长或管理员审核。',
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
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      if (error.code == 'VERSION_CONFLICT') {
        await _load();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提交失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = _person;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppPageHeader(title: '资料申请', subtitle: '提交后由族长或管理员审核'),
              Expanded(
                child: person == null
                    ? _LoadingOrError(
                        loading: _loading,
                        error: _error,
                        onRetry: _load,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.goldSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF2DFC0),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.shield_outlined,
                                    size: 17,
                                    color: AppColors.gold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '提交后不会直接修改正式档案。审核通过后变更才会写入，拒绝时会保留审核意见。',
                                    style: TextStyle(
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
                          _PersonCard(person: person),
                          const SizedBox(height: 14),
                          SoftCard(
                            padding: const EdgeInsets.fromLTRB(17, 16, 17, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionTitle(title: '可修改资料'),
                                const SizedBox(height: 15),
                                _FieldLabel(label: '籍贯'),
                                _EditField(
                                  controller: _birthPlace,
                                  hint: '例如：浙江 · 青溪村',
                                  icon: Icons.place_outlined,
                                  maxLength: 160,
                                ),
                                const SizedBox(height: 12),
                                _FieldLabel(label: '现居地'),
                                _EditField(
                                  controller: _residence,
                                  hint: '当前居住城市',
                                  icon: Icons.home_work_outlined,
                                  maxLength: 160,
                                ),
                                const SizedBox(height: 12),
                                _FieldLabel(label: '职业'),
                                _EditField(
                                  controller: _occupation,
                                  hint: '职业或身份',
                                  icon: Icons.work_outline_rounded,
                                  maxLength: 160,
                                ),
                                const SizedBox(height: 12),
                                _FieldLabel(label: '教育'),
                                _EditField(
                                  controller: _education,
                                  hint: '毕业院校或学历',
                                  icon: Icons.school_outlined,
                                  maxLength: 160,
                                ),
                                const SizedBox(height: 12),
                                _FieldLabel(label: '生平简介'),
                                _EditField(
                                  controller: _biography,
                                  hint: '补充重要经历、家风故事',
                                  icon: Icons.notes_rounded,
                                  maxLines: 4,
                                  maxLength: 2000,
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => setState(
                                    () => _showPreview = !_showPreview,
                                  ),
                                  icon: Icon(
                                    _showPreview
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 17,
                                  ),
                                  label: Text(_showPreview ? '收起变更' : '查看本次变更'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    textStyle: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                if (_showPreview) ...[
                                  const SizedBox(height: 10),
                                  _ChangePreview(changes: _changes()),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const SoftCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 13,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cloud_done_outlined,
                                  size: 17,
                                  color: AppColors.jade,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '提交时携带当前资料版本，服务端会做冲突检查。',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                                TagPill(
                                  label: '实时',
                                  color: AppColors.jade,
                                  background: AppColors.jadeSoft,
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
      bottomNavigationBar: person == null
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
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
                      : const Text('提交审核申请'),
                ),
              ),
            ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final ApiPerson person;

  @override
  Widget build(BuildContext context) {
    final member = person.toFamilyMember('');
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          InkPortrait(
            person: member,
            width: 58,
            height: 68,
            radius: 15,
            showBorder: true,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${person.generationLabel} · 资料版本 v${person.version}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (person.lifeStatus == 'deceased')
            const TagPill(
              label: '已故',
              color: AppColors.inkMuted,
              background: AppColors.slateSoft,
            ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.maxLength = 160,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: const Color(0xFFF7F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFE9EEF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _ChangePreview extends StatelessWidget {
  const _ChangePreview({required this.changes});

  final ApiEditChanges changes;

  @override
  Widget build(BuildContext context) {
    final keys = changes.fieldKeys;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: keys.isEmpty
          ? const Text(
              '尚未修改任何字段',
              style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
            )
          : Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final key in keys)
                  TagPill(
                    label: ApiEditChanges.labelFor(key),
                    color: AppColors.primary,
                    background: AppColors.primarySoft,
                    icon: Icons.edit_outlined,
                  ),
              ],
            ),
    );
  }
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: AppColors.inkMuted,
            ),
            const SizedBox(height: 12),
            Text(
              error ?? '无法读取人物资料',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
