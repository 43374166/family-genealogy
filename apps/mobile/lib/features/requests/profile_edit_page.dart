import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_data.dart';
import '../../models/family_activity.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _residence;
  late final TextEditingController _occupation;
  late final TextEditingController _biography;
  late final TextEditingController _birthPlace;

  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    const person = DemoData.currentUser;
    _residence = TextEditingController(text: person.residence);
    _occupation = TextEditingController(text: person.occupation);
    _biography = TextEditingController(text: person.biography);
    _birthPlace = TextEditingController(text: person.birthPlace);
  }

  @override
  void dispose() {
    _residence.dispose();
    _occupation.dispose();
    _biography.dispose();
    _birthPlace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const person = DemoData.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppPageHeader(
                title: '资料申请',
                subtitle: '修改本人信息 · 需族长审核',
                actions: [
                  HeaderIconButton(
                    icon: Icons.history_rounded,
                    onTap: () => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('暂无历史修改记录'))),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.goldSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF2DFC0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 17,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(
                                    text: '提交后不会直接修改正式档案。',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' 族长或家支管理员审核通过后，变更才会写入；拒绝时会保留审核意见。',
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.65,
                                color: AppColors.ink.withValues(alpha: 0.72),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SoftCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          InkPortrait(
                            person: person,
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
                                  person.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${person.generationLabel} · ${person.tags.first}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _showAvatarNotice(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                color: AppColors.primarySoft,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              textStyle: const TextStyle(fontSize: 10.5),
                            ),
                            child: const Text('更换头像'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SoftCard(
                      padding: const EdgeInsets.fromLTRB(17, 16, 17, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: '基本信息'),
                          const SizedBox(height: 16),
                          _FieldLabel(label: '姓名', fixed: true),
                          _ReadOnlyField(value: person.name),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _FieldLabel(label: '性别', fixed: true),
                                    _ReadOnlyField(
                                      value: person.isFemale ? '女' : '男',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _FieldLabel(
                                      label: '出生年份',
                                      fixed: true,
                                    ),
                                    _ReadOnlyField(
                                      value: '${person.birthYear} 年',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          const _FieldLabel(label: '籍贯'),
                          _EditField(
                            controller: _birthPlace,
                            hint: '例如：江南 · 青溪村',
                            icon: Icons.place_outlined,
                          ),
                          const SizedBox(height: 13),
                          const _FieldLabel(label: '现居地'),
                          _EditField(
                            controller: _residence,
                            hint: '填写当前居住城市',
                            icon: Icons.home_work_outlined,
                            validator: true,
                          ),
                          const SizedBox(height: 13),
                          const _FieldLabel(label: '职业'),
                          _EditField(
                            controller: _occupation,
                            hint: '填写职业或身份',
                            icon: Icons.work_outline_rounded,
                          ),
                          const SizedBox(height: 13),
                          const _FieldLabel(label: '生平简介'),
                          _EditField(
                            controller: _biography,
                            hint: '介绍自己，或补充重要经历',
                            maxLines: 4,
                            maxLength: 160,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 12,
                                color: AppColors.inkMuted,
                              ),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  '姓名、性别与出生年份需联系族长修改',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _showPreview = !_showPreview,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(fontSize: 10.5),
                                ),
                                child: Text(_showPreview ? '收起变更' : '查看变更'),
                              ),
                            ],
                          ),
                          if (_showPreview) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F9FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '本次申请字段',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: const [
                                      TagPill(
                                        label: '籍贯',
                                        color: AppColors.primary,
                                        background: AppColors.primarySoft,
                                      ),
                                      TagPill(
                                        label: '现居地',
                                        color: AppColors.primary,
                                        background: AppColors.primarySoft,
                                      ),
                                      TagPill(
                                        label: '职业',
                                        color: AppColors.primary,
                                        background: AppColors.primarySoft,
                                      ),
                                      TagPill(
                                        label: '生平简介',
                                        color: AppColors.primary,
                                        background: AppColors.primarySoft,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '提交时会携带当前资料版本，服务端会进行冲突检查。',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      height: 1.5,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            size: 17,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '当前为本地演示模式，提交不会写入服务器。',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                          TagPill(
                            label: '原型',
                            color: AppColors.inkMuted,
                            background: AppColors.slateSoft,
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 9, 18, 12),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: Color(0xFFE9EEF0))),
          ),
          child: FilledButton(
            onPressed: _submit,
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
            child: const Text('提交审核申请'),
          ),
        ),
      ),
    );
  }

  void _showAvatarNotice(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          MediaQuery.paddingOf(context).bottom + 22,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '头像上传将在服务端接入后开放',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              '正式版本中，头像会先进入待审核区，审核通过后才会替换。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.65,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('知道了'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          28,
          24,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                color: AppColors.jadeSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 34,
                color: AppColors.jade,
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              '演示申请已生成',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            const Text(
              '当前尚未接入后端，申请仅用于展示审核流程，\n并不会写入服务器或正式族谱。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.7,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text(
                    '状态',
                    style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                  ),
                  const Spacer(),
                  StatusPill.request(RequestStatus.pending),
                  const SizedBox(width: 24),
                  const Text(
                    '预计审核',
                    style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    '1–3 天',
                    style: TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('完成并返回'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
              child: const Text('继续修改', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.fixed = false});

  final String label;
  final bool fixed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
          ),
          if (fixed) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.lock_outline_rounded,
              size: 10,
              color: AppColors.inkMuted,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value.isEmpty ? '未记录' : value,
        style: TextStyle(
          fontSize: 12.5,
          color: AppColors.ink.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.hint,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.validator = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final int? maxLength;
  final bool validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
      validator: validator
          ? (value) {
              if (value == null || value.trim().isEmpty) return '请填写现居地';
              return null;
            }
          : null,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        isDense: true,
        contentPadding: EdgeInsets.fromLTRB(icon == null ? 13 : 38, 13, 13, 13),
        prefixIcon: icon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(icon, size: 16, color: AppColors.inkMuted),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF1F2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}
