import 'package:flutter/material.dart';

import '../../core/images/image_pick_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/preserve_colors.dart';
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
  late final List<ApiPhoto> _existingPhotos = [...(widget.story?.photos ?? [])];
  final List<PickedImageData> _newPhotos = [];
  String? _personId;
  String _personName = '';
  bool _saving = false;
  String _saveStatus = '';
  String? _error;

  int get _photoCount => _existingPhotos.length + _newPhotos.length;

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

  Future<void> _pickPhotos() async {
    final remaining = 9 - _photoCount;
    if (remaining <= 0) {
      setState(() => _error = '故事最多附带 9 张图片');
      return;
    }
    final picked = await pickMultipleImages(
      maxWidth: 1600,
      imageQuality: 70,
      limit: remaining,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _newPhotos.addAll(picked.take(remaining));
      _error = null;
    });
  }

  Future<List<String>> _uploadNewPhotos(AppSession session) async {
    final ids = <String>[];
    for (var index = 0; index < _newPhotos.length; index++) {
      if (!mounted) return ids;
      setState(
        () => _saveStatus = '正在压缩并上传图片 ${index + 1}/${_newPhotos.length}',
      );
      final file = _newPhotos[index];
      final photo = await session.uploadPhoto(
        bytes: file.bytes,
        filename: file.filename,
        personIds: _personId == null ? const [] : [_personId!],
      );
      ids.add(photo.id);
    }
    return ids;
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
      _saveStatus = '';
      _error = null;
    });
    final session = SessionScope.of(context);
    final uploadedIDs = <String>[];
    try {
      uploadedIDs.addAll(await _uploadNewPhotos(session));
      final photoIDs = [
        ..._existingPhotos.map((photo) => photo.id),
        ...uploadedIDs,
      ];
      if (photoIDs.length > 9) {
        throw const ApiException('故事最多附带 9 张图片');
      }
      setState(() => _saveStatus = '正在保存故事');
      if (widget.story == null) {
        await session.createStory(
          title: title,
          body: body,
          personId: _personId ?? '',
          photoIds: photoIDs,
        );
      } else {
        await session.updateStory(
          storyId: widget.story!.id,
          title: title,
          body: body,
          personId: _personId ?? '',
          photoIds: photoIDs,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      // Do not leave orphaned uploads if creating/updating the story failed.
      for (final id in uploadedIDs) {
        try {
          await session.deletePhoto(id);
        } catch (_) {
          // Best-effort cleanup only.
        }
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveStatus = '';
        _error = error.message;
      });
    } catch (_) {
      for (final id in uploadedIDs) {
        try {
          await session.deletePhoto(id);
        } catch (_) {
          // Best-effort cleanup only.
        }
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveStatus = '';
        _error = '保存故事失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.story != null;
    final session = SessionScope.of(context);
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
                  Row(
                    children: [
                      const Text(
                        '故事配图',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$_photoCount/9 · 上传前自动压缩',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _saving || _photoCount >= 9
                            ? null
                            : _pickPhotos,
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          '添加图片',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (
                        var index = 0;
                        index < _existingPhotos.length;
                        index++
                      )
                        _PhotoTile(
                          image: Image.network(
                            session.photoUrl(
                              _existingPhotos[index].contentPath,
                            ),
                            headers: session.photoHeaders,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.slateSoft,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                          onRemove: _saving
                              ? null
                              : () => setState(
                                  () => _existingPhotos.removeAt(index),
                                ),
                        ),
                      for (var index = 0; index < _newPhotos.length; index++)
                        _PhotoTile(
                          image: Image.memory(
                            _newPhotos[index].bytes,
                            fit: BoxFit.cover,
                          ),
                          onRemove: _saving
                              ? null
                              : () =>
                                    setState(() => _newPhotos.removeAt(index)),
                        ),
                      if (_photoCount < 9)
                        InkWell(
                          onTap: _saving ? null : _pickPhotos,
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: AppColors.inkMuted,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '多选',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: _saving
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              if (_saveStatus.isNotEmpty) ...[
                                const SizedBox(width: 9),
                                Text(
                                  _saveStatus,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ],
                            ],
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.image, this.onRemove});

  final Widget image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PreserveColors(child: image),
            if (onRemove != null)
              Positioned(
                right: 2,
                top: 2,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
