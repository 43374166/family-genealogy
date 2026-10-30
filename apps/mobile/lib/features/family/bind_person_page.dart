import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../search/member_search_page.dart';

class BindPersonPage extends StatefulWidget {
  const BindPersonPage({super.key});

  @override
  State<BindPersonPage> createState() => _BindPersonPageState();
}

class _BindPersonPageState extends State<BindPersonPage> {
  ApiPerson? _selected;
  bool _submitting = false;

  Future<void> _pick() async {
    final person = await Navigator.of(context).push<ApiPerson>(
      MaterialPageRoute<ApiPerson>(
        builder: (_) => const MemberSearchPage(selectMode: true),
      ),
    );
    if (person != null && mounted) {
      setState(() => _selected = person);
    }
  }

  Future<void> _submit() async {
    final person = _selected;
    if (person == null) return;
    setState(() => _submitting = true);
    try {
      await SessionScope.of(context).createBindingRequest(person.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('申请已提交'),
          content: const Text('族长或管理员核对身份后，会把你和族谱人物绑定。'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final alreadyBound = session.membership?.personId != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '绑定族谱人物', subtitle: '让账号对应到族谱中的真实成员'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: alreadyBound
                          ? AppColors.jadeSoft
                          : AppColors.goldSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      alreadyBound
                          ? '当前账号已绑定族谱人物。如需换绑，请先联系族长。'
                          : '选择你在族谱中对应的人物。提交后由族长或管理员审核，避免冒认。',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.65,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(title: '选择人物'),
                        const SizedBox(height: 12),
                        if (_selected == null)
                          OutlinedButton.icon(
                            onPressed: alreadyBound ? null : _pick,
                            icon: const Icon(
                              Icons.person_search_rounded,
                              size: 18,
                            ),
                            label: const Text('从族谱中选择'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        else
                          InkWell(
                            onTap: alreadyBound ? null : _pick,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F9FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  InkPortrait(
                                    person: _selected!.toFamilyMember(''),
                                    width: 48,
                                    height: 54,
                                    radius: 11,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selected!.fullName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _selected!.generationLabel,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.inkMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.inkMuted,
                                  ),
                                ],
                              ),
                            ),
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
            onPressed: alreadyBound || _submitting ? null : _submit,
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
                : const Text('提交绑定申请'),
          ),
        ),
      ),
    );
  }
}
