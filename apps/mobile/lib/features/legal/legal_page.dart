import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';

enum LegalKind { terms, privacy }

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.kind});

  final LegalKind kind;

  static const termsVersion = '2026-10-31';

  @override
  Widget build(BuildContext context) {
    final isTerms = kind == LegalKind.terms;
    final sections = isTerms ? _termsSections : _privacySections;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: isTerms ? '用户协议' : '隐私政策',
              subtitle: '版本 $termsVersion',
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  8,
                  22,
                  MediaQuery.paddingOf(context).bottom + 30,
                ),
                children: [
                  Text(
                    isTerms ? '家族族谱用户协议' : '家族族谱隐私政策',
                    style: AppTheme.serif(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '请在使用前仔细阅读。继续使用即表示你理解并同意本内容。',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.7,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (var i = 0; i < sections.length; i++) ...[
                    Text(
                      '${i + 1}. ${sections[i].$1}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      sections[i].$2,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.9,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    '本协议为家族内部使用的基础说明；正式公开运营前，应由运营方补充主体信息、联系方式和适用法律条款。',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.7,
                      color: AppColors.inkMuted,
                    ),
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

const _termsSections = [
  ('服务内容', '本应用用于家族成员共同维护族谱、人物资料、照片、家族故事和审核记录。账号可加入多个家族，当前家族由账号所在家族决定。'),
  (
    '账号与安全',
    '你应妥善保管账号和密码，不得将账号借给他人使用。发现账号异常时，应及时修改密码或联系家族管理员。族长账号涉及全族数据，注销前必须先转让族长身份。',
  ),
  (
    '家族内容',
    '你录入的人物、关系、照片和故事应真实、合法，并尊重在世成员的隐私和名誉。你应确保有权上传相关照片和资料；家族共同维护的内容归家族共同使用。',
  ),
  ('使用规范', '不得利用本应用发布违法、侵权、侮辱、虚假或危害他人的内容，不得批量抓取、倒卖家族数据，不得攻击或干扰服务。'),
  ('审核与权限', '族长、管理员可在授权范围内审核资料修改、绑定申请和管理家支。审核记录会留存，便于追溯。'),
  ('服务变更与终止', '应用可能因维护、升级或不可抗力暂停服务。你可以申请注销账号；家族共同数据不会因单个账号注销而自动删除。'),
  (
    '免责声明',
    '家族资料由成员共同提供，应用不保证所有内容绝对准确。因用户提供错误信息、账号保管不当或不可抗力造成的损失，运营方在适用法律允许范围内不承担责任。',
  ),
];

const _privacySections = [
  (
    '我们收集哪些信息',
    '账号信息（登录名、显示名称、手机号）、家族身份和绑定人物、你录入的族谱人物资料、关系、照片、故事、审核申请，以及登录时间、IP 和会话信息。',
  ),
  ('使用目的', '用于登录和账号安全、展示族谱和家族相册、完成成员绑定与资料审核、发送站内通知、备份和恢复数据。'),
  (
    '存储与保护',
    '数据存储在中国境内的服务器和私有对象存储中。照片通过登录鉴权读取，不生成公开链接。我们采取访问控制、HTTPS、备份和审计记录等措施。',
  ),
  ('共享与委托处理', '除提供云存储、短信等基础服务的必要受托方外，不向无关第三方出售或共享你的个人信息。法律法规另有要求的除外。'),
  (
    '保留期限',
    '账号存续期间保留相关数据；注销账号后，登录身份会被匿名化，家族共同维护的族谱、照片和故事可继续由家族保留。数据库备份按运维周期滚动清理。',
  ),
  (
    '你的权利',
    '你可以查看和修改自己的账号资料、绑定人物和上传内容；可以申请更正家族资料；可以在“设置—账号注销”中申请注销账号。族长账号需先转让族长身份。',
  ),
  ('未成年人', '未成年人应在监护人同意和指导下使用。涉及未成年人照片和资料时，应由监护人确认。'),
  ('联系我们', '如对隐私政策有疑问，可通过家族管理员或应用内反馈渠道联系运营方。正式公开运营前，运营方应补充真实联系方式和投诉渠道。'),
];
