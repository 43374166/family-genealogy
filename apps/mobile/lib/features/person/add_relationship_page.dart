import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../search/member_search_page.dart';

enum RelationKind { father, mother, spouse }

class AddRelationshipPage extends StatefulWidget {
  const AddRelationshipPage({super.key, this.initialSubject});

  final ApiPerson? initialSubject;

  @override
  State<AddRelationshipPage> createState() => _AddRelationshipPageState();
}

class _AddRelationshipPageState extends State<AddRelationshipPage> {
  ApiPerson? _subject;
  ApiPerson? _target;
  RelationKind _kind = RelationKind.father;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _subject = widget.initialSubject;
  }

  Future<ApiPerson?> _pickPerson({ApiPerson? exclude}) async {
    final person = await Navigator.of(context).push<ApiPerson>(
      MaterialPageRoute<ApiPerson>(
        builder: (_) => const MemberSearchPage(selectMode: true),
      ),
    );
    if (person != null && person.id == exclude?.id) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('不能选择同一个人')));
      }
      return null;
    }
    return person;
  }

  Future<void> _submit() async {
    final subject = _subject;
    final target = _target;
    if (subject == null || target == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择两个人物')));
      return;
    }
    if (subject.id == target.id) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('不能和自己建立关系')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = SessionScope.of(context);
      if (session.canWrite) {
        if (_kind == RelationKind.spouse) {
          await session.addSpouse(personAId: subject.id, personBId: target.id);
        } else {
          await session.addParentChild(
            parentId: target.id,
            childId: subject.id,
            parentRole: _kind == RelationKind.father ? 'father' : 'mother',
          );
        }
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('关系已添加'),
            content: Text(
              _kind == RelationKind.spouse
                  ? '${subject.fullName} 与 ${target.fullName} 已建立配偶关系。'
                  : '${target.fullName} 已设为 ${subject.fullName} 的${_kind == RelationKind.father ? '父亲' : '母亲'}。',
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
          requestType: _kind == RelationKind.spouse
              ? 'add_spouse'
              : 'add_parent_child',
          payload: _kind == RelationKind.spouse
              ? {'personAId': subject.id, 'personBId': target.id}
              : {
                  'parentId': target.id,
                  'childId': subject.id,
                  'parentRole': _kind == RelationKind.father
                      ? 'father'
                      : 'mother',
                },
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('申请已提交'),
            content: const Text('关系申请已提交，等待族长或管理员审核。'),
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
      ).showSnackBar(const SnackBar(content: Text('添加关系失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = _subject;
    final target = _target;
    final canWrite = SessionScope.of(context).canWrite;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '添加关系',
              subtitle: canWrite ? '父母、配偶关系会立即写入族谱' : '提交族长或管理员审核',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF2DFC0)),
                    ),
                    child: const Text(
                      '父母关系要求父母世代高于子女；配偶要求双方同一世代。重复父亲、母亲或配偶会被服务端拒绝。',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.65,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(title: '关系'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final kind in RelationKind.values)
                              _RelationChip(
                                label: switch (kind) {
                                  RelationKind.father => '父亲',
                                  RelationKind.mother => '母亲',
                                  RelationKind.spouse => '配偶',
                                },
                                selected: _kind == kind,
                                onTap: () => setState(() => _kind = kind),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _kind == RelationKind.spouse ? '人物 A' : '子女',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _PersonPickerTile(
                          person: subject,
                          emptyText: '选择子女',
                          onTap: () async {
                            final person = await _pickPerson(exclude: target);
                            if (person != null) {
                              setState(() => _subject = person);
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppColors.line,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 9),
                                child: Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 16,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppColors.line,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          switch (_kind) {
                            RelationKind.father => '父亲',
                            RelationKind.mother => '母亲',
                            RelationKind.spouse => '人物 B',
                          },
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _PersonPickerTile(
                          person: target,
                          emptyText: switch (_kind) {
                            RelationKind.father => '选择父亲',
                            RelationKind.mother => '选择母亲',
                            RelationKind.spouse => '选择配偶',
                          },
                          onTap: () async {
                            final person = await _pickPerson(exclude: subject);
                            if (person != null) {
                              setState(() => _target = person);
                            }
                          },
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
      bottomNavigationBar: SafeArea(
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
                : Text(canWrite ? '保存关系' : '提交审核'),
          ),
        ),
      ),
    );
  }
}

class _RelationChip extends StatelessWidget {
  const _RelationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonPickerTile extends StatelessWidget {
  const _PersonPickerTile({
    required this.person,
    required this.emptyText,
    required this.onTap,
  });

  final ApiPerson? person;
  final String emptyText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9FA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (person != null)
                InkPortrait(
                  person: person!.toFamilyMember(''),
                  width: 40,
                  height: 45,
                  radius: 10,
                )
              else
                Container(
                  width: 40,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 20,
                    color: AppColors.inkMuted,
                  ),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  person == null
                      ? emptyText
                      : '${person!.fullName} · ${person!.generationLabel}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: person == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                    color: person == null ? AppColors.inkMuted : AppColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
