import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/app_session.dart';
import 'qr_scan_page.dart';

class JoinFamilyPage extends StatefulWidget {
  const JoinFamilyPage({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<JoinFamilyPage> createState() => _JoinFamilyPageState();
}

class _JoinFamilyPageState extends State<JoinFamilyPage> {
  late final TextEditingController _code;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScanPage()),
    );
    if (value != null && mounted) {
      setState(() {
        _code.text = value.trim().toUpperCase();
        _error = null;
      });
    }
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _error = '请输入有效邀请码');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final me = await SessionScope.of(context).joinFamily(code);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('已加入家族'),
          content: Text('当前家族已切换为 ${me.family.name}，原家族仍然保留。'),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '加入家族', subtitle: '填写邀请码，或扫描族长分享的二维码'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.diversity_3_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            '加入后会新增一个家族身份，不会删除你原来的家族。你可以随时在“我的家族”里切换。',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.65,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 18, letterSpacing: 2),
                    decoration: InputDecoration(
                      labelText: '邀请码',
                      hintText: '例如 A7K9P2QX',
                      prefixIcon: const Icon(Icons.key_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                    label: const Text('扫描邀请二维码'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
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
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _submitting ? null : _join,
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
                        : const Text('加入家族'),
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
