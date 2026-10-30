import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../search/member_search_page.dart';

class StoryEditPage extends StatefulWidget {
  const StoryEditPage({super.key, this.story});

  final ApiStory? story;

  @override
  State<StoryEditPage> createState() => _StoryEditPageState();
}

class _StoryEditPageState extends State<StoryEditPage> {
  late final TextEditingController _title = TextEditingController(
    text: widget.story?.title ?? '',
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.story?.body ?? '',
  );
  String? _personId;
  String _personName = '';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _personId = widget.story?.personId;
    _personName = widget.story?.personName ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickPerson() async {
    final person = await Navigator.of(context).push<ApiPerson>(
      MaterialPageRoute<ApiPerson>(
        builder: (_) => const MemberSearchPage(selectMode: true),
      ),
    );
    if (person != null && mounted) {
      setState(() {
        _personId = person.id;
        _personName = person.fullName;
      });
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = '标题和正文都要填写');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = SessionScope.of(context);
      if (widget.story == null) {
        await session.createStory(
          title: title,
          body: body,
          personId: _personId ?? '',
        );
      } else {
        await session.updateStory(
          storyId: widget.story!.id,
          title: title,
          body: body,
          personId: _personId ?? '',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.story != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: editing ? '编辑故事' : '写家族故事',
              subtitle: '记录人物、往事和家族记忆',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  TextField(
                    controller: _title,
                    maxLength: 120,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: '标题',
                      hintText: '例如：祖父留下的那本手抄家谱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickPerson,
                    icon: const Icon(
                      Icons.person_pin_circle_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _personId == null ? '关联人物（可选）' : '关联人物：$_personName',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  if (_personId != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _personId = null;
                          _personName = '';
                        }),
                        child: const Text('清除人物'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _body,
                    minLines: 12,
                    maxLines: null,
                    maxLength: 20000,
                    style: const TextStyle(fontSize: 13, height: 1.8),
                    decoration: const InputDecoration(
                      labelText: '正文',
                      hintText: '写下时间、地点、人物和故事经过…',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.cinnabar,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(editing ? '保存修改' : '发布故事'),
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
