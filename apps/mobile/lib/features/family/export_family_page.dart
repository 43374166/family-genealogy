import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../search/member_search_page.dart';

class ExportFamilyPage extends StatefulWidget {
  const ExportFamilyPage({super.key});

  @override
  State<ExportFamilyPage> createState() => _ExportFamilyPageState();
}

class _ExportFamilyPageState extends State<ExportFamilyPage> {
  ApiPerson? _root;
  ApiImportPackage? _package;
  bool _submitting = false;
  String? _error;

  Future<void> _pick() async {
    final person = await Navigator.of(context).push<ApiPerson>(
      MaterialPageRoute<ApiPerson>(
        builder: (_) => const MemberSearchPage(selectMode: true),
      ),
    );
    if (person != null && mounted) {
      setState(() {
        _root = person;
        _package = null;
        _error = null;
      });
    }
  }

  Future<void> _create() async {
    final root = _root;
    if (root == null) {
      setState(() => _error = '请先选择要导出的根人物');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final package = await SessionScope.of(
        context,
      ).createImportPackage(root.id);
      if (!mounted) return;
      setState(() {
        _package = package;
        _submitting = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('导入码 $code 已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final package = _package;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '导出旁支数据', subtitle: '选择根人物，生成一次性导入码'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.all(15),
                    child: const Text(
                      '只导出所选人物及其后代，连同配偶和内部关系。源家族不会被删除；对方导入后生成新的人物 ID。',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.65,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SectionTitle(title: '选择根人物'),
                  const SizedBox(height: 8),
                  if (_root == null)
                    OutlinedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.person_search_rounded, size: 18),
                      label: const Text('从当前家族选择'),
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
                      onTap: _pick,
                      borderRadius: BorderRadius.circular(13),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            InkPortrait(
                              person: _root!.toFamilyMember(''),
                              width: 46,
                              height: 52,
                              radius: 11,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _root!.fullName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _root!.generationLabel,
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
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _create,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('生成导入码'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
                  if (package != null) ...[
                    const SizedBox(height: 18),
                    SoftCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '导入码（一次性）',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            package.code,
                            style: const TextStyle(
                              fontSize: 26,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: QrImageView(
                              data: package.code,
                              version: QrVersions.auto,
                              size: 150,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${package.rootName} · ${package.personCount} 人 · '
                            '${package.relationshipCount} 条关系',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _copy(package.code),
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('复制导入码'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '把导入码发给目标家族的族长。有效期 7 天，使用一次后失效。',
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.55,
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
          ],
        ),
      ),
    );
  }
}
