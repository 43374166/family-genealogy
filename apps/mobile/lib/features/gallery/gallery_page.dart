import 'package:flutter/material.dart';

import '../../core/images/image_pick_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/preserve_colors.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../search/member_search_page.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({
    super.key,
    this.personId,
    this.personName,
    this.solePerson = false,
  });

  final String? personId;
  final String? personName;

  /// When opened from a person profile, only photos where that person is the
  /// sole tagged person are shown. Choosing another filter switches back to the
  /// normal family album search.
  final bool solePerson;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<ApiPhoto> _photos = const [];
  late List<ApiPerson> _filterPeople = [
    if (widget.personId != null && widget.personId!.isNotEmpty)
      ApiPerson.brief(
        id: widget.personId!,
        fullName: widget.personName ?? '已选人物',
      ),
  ];
  bool _loading = true;
  bool _uploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  late bool _solePerson = widget.solePerson;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final photos = await SessionScope.of(context).photos(
        personIds: _filterPeople.map((person) => person.id).toList(),
        solePersonId: _solePerson && _filterPeople.length == 1
            ? _filterPeople.single.id
            : null,
      );
      if (!mounted) return;
      setState(() {
        _photos = photos;
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

  Future<void> _pickFilter() async {
    final result = await Navigator.of(context).push<List<ApiPerson>>(
      MaterialPageRoute<List<ApiPerson>>(
        builder: (_) => MemberSearchPage(
          selectMode: true,
          multiSelect: true,
          initialSelected: _filterPeople,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filterPeople = result;
      _solePerson = false;
    });
    await _load();
  }

  Future<void> _upload() async {
    final picked = await pickMultipleImages(
      maxWidth: 2000,
      imageQuality: 78,
      limit: 20,
    );
    if (picked.isEmpty || !mounted) return;
    final meta = await _askMeta(initialPeople: _filterPeople);
    if (meta == null || !mounted) return;
    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadTotal = picked.length;
    });
    final session = SessionScope.of(context);
    final uploaded = <ApiPhoto>[];
    String? failure;
    for (final file in picked) {
      if (!mounted) return;
      try {
        final photo = await session.uploadPhoto(
          bytes: file.bytes,
          filename: file.filename,
          personIds: meta.people.map((person) => person.id).toList(),
          caption: meta.caption,
          takenAt: meta.takenAt,
        );
        uploaded.add(photo);
      } on ApiException catch (error) {
        failure = error.message;
        break;
      } catch (_) {
        failure = '照片上传失败，请稍后重试';
        break;
      }
      if (!mounted) return;
      setState(() => _uploadDone++);
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    if (_filterPeople.isEmpty) {
      setState(() => _photos = [...uploaded.reversed, ..._photos]);
    } else {
      await _load();
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? '已上传 ${uploaded.length} 张照片'
              : '已上传 ${uploaded.length} 张，其余未完成：$failure',
        ),
      ),
    );
  }

  Future<_PhotoMeta?> _askMeta({
    List<ApiPerson> initialPeople = const [],
    ApiPhoto? photo,
  }) async {
    var people = photo == null
        ? [...initialPeople]
        : photo.persons.isNotEmpty
        ? photo.persons
              .map(
                (person) => ApiPerson.brief(
                  id: person.personId,
                  fullName: person.fullName,
                ),
              )
              .toList()
        : photo.personId == null
        ? <ApiPerson>[]
        : [ApiPerson.brief(id: photo.personId!, fullName: photo.personName)];
    var takenAt = photo?.takenAt;
    final caption = TextEditingController(text: photo?.caption ?? '');
    final result = await showDialog<_PhotoMeta>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(photo == null ? '照片信息' : '编辑照片信息'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await Navigator.of(context)
                        .push<List<ApiPerson>>(
                          MaterialPageRoute<List<ApiPerson>>(
                            builder: (_) => MemberSearchPage(
                              selectMode: true,
                              multiSelect: true,
                              initialSelected: people,
                            ),
                          ),
                        );
                    if (selected != null) {
                      setDialogState(() => people = selected);
                    }
                  },
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  label: Text(
                    people.isEmpty ? '关联人物（可多选）' : '关联 ${people.length} 人',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (people.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final person in people)
                        InputChip(
                          label: Text(
                            person.fullName,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onDeleted: () => setDialogState(
                            () => people = people
                                .where((item) => item.id != person.id)
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: caption,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '说明（可选）',
                    hintText: '例如：1980 年春节全家福',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: takenAt ?? now,
                      firstDate: DateTime(1800),
                      lastDate: now,
                      helpText: '选择拍摄时间',
                    );
                    if (picked != null) {
                      setDialogState(() => takenAt = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(
                    takenAt == null ? '拍摄时间（可选）' : _dateLabel(takenAt!),
                  ),
                ),
                if (takenAt != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setDialogState(() => takenAt = null),
                      child: const Text('清除时间'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _PhotoMeta(
                  people: people,
                  caption: caption.text.trim(),
                  takenAt: takenAt,
                ),
              ),
              child: Text(photo == null ? '上传' : '保存'),
            ),
          ],
        ),
      ),
    );
    caption.dispose();
    return result;
  }

  Future<void> _showPhoto(ApiPhoto photo) async {
    final session = SessionScope.of(context);
    final canManage =
        photo.uploadedByUserId == session.user?.id || session.canWrite;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => PreserveColors(
        child: Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    session.photoUrl(photo.contentPath),
                    headers: session.photoHeaders,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        '照片加载失败',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (photo.displayPersonNames.isNotEmpty)
                      Text(
                        photo.displayPersonNames,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (photo.caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          photo.caption,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (photo.takenAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '拍摄于 ${_dateLabel(photo.takenAt!)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    Text(
                      '由 ${photo.uploadedByName} 上传',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('关闭'),
                  ),
                  if (canManage)
                    TextButton(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        final meta = await _askMeta(photo: photo);
                        if (meta == null || !mounted) return;
                        try {
                          final updated = await session.updatePhoto(
                            photoId: photo.id,
                            personIds: meta.people
                                .map((person) => person.id)
                                .toList(),
                            caption: meta.caption,
                            takenAt: meta.takenAt,
                          );
                          if (!mounted) return;
                          setState(() {
                            _photos = _photos
                                .map(
                                  (item) =>
                                      item.id == photo.id ? updated : item,
                                )
                                .toList(growable: false);
                          });
                        } on ApiException catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      },
                      child: const Text('编辑'),
                    ),
                  if (canManage)
                    TextButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('删除照片'),
                            content: const Text('确定从家族相册删除这张照片吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !mounted) return;
                        try {
                          await session.deletePhoto(photo.id);
                          if (!mounted) return;
                          setState(() {
                            _photos = _photos
                                .where((item) => item.id != photo.id)
                                .toList(growable: false);
                          });
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } on ApiException catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      },
                      child: const Text(
                        '删除',
                        style: TextStyle(color: Color(0xFFE8A0A0)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final title = widget.personName == null
        ? '家族相册'
        : '${widget.personName}的照片';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: title,
              subtitle: _uploading
                  ? '正在上传 $_uploadDone/$_uploadTotal'
                  : _loading
                  ? '正在加载照片'
                  : '${_photos.length} 张照片',
              actions: [
                HeaderIconButton(
                  icon: Icons.filter_alt_outlined,
                  onTap: _uploading ? () {} : _pickFilter,
                ),
                HeaderIconButton(
                  icon: Icons.add_photo_alternate_outlined,
                  onTap: _uploading ? () {} : _upload,
                ),
              ],
            ),
            _FilterBar(
              people: _filterPeople,
              onTap: _uploading ? null : _pickFilter,
              onClear: () {
                setState(() {
                  _filterPeople = const [];
                  _solePerson = false;
                });
                _load();
              },
            ),
            if (_uploading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: LinearProgressIndicator(
                  value: _uploadTotal == 0 ? null : _uploadDone / _uploadTotal,
                  minHeight: 3,
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _photos.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 110),
                                const Icon(
                                  Icons.photo_library_outlined,
                                  size: 44,
                                  color: AppColors.inkMuted,
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    _filterPeople.isEmpty
                                        ? '还没有照片'
                                        : '这些人还没有关联照片',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Center(
                                  child: Text(
                                    '点右上角可以一次选择多张照片上传',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : GridView.builder(
                              padding: EdgeInsets.fromLTRB(
                                14,
                                8,
                                14,
                                MediaQuery.paddingOf(context).bottom + 20,
                              ),
                              itemCount: _photos.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 5,
                                    crossAxisSpacing: 5,
                                  ),
                              itemBuilder: (context, index) {
                                final photo = _photos[index];
                                return GestureDetector(
                                  onTap: () => _showPhoto(photo),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        PreserveColors(
                                          child: Image.network(
                                            session.photoUrl(photo.contentPath),
                                            headers: session.photoHeaders,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                Container(
                                                  color: AppColors.slateSoft,
                                                  child: const Icon(
                                                    Icons.broken_image_outlined,
                                                    color: AppColors.inkMuted,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        if (photo.displayPersonNames.isNotEmpty)
                                          Positioned(
                                            left: 4,
                                            right: 4,
                                            bottom: 4,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                photo.displayPersonNames,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.people,
    required this.onTap,
    required this.onClear,
  });

  final List<ApiPerson> people;
  final VoidCallback? onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
        children: [
          if (people.isEmpty)
            ActionChip(
              avatar: const Icon(Icons.people_outline_rounded, size: 15),
              label: const Text('筛选人物', style: TextStyle(fontSize: 11)),
              onPressed: onTap,
            )
          else ...[
            ActionChip(
              avatar: const Icon(Icons.person_pin_circle_outlined, size: 15),
              label: const Text('全部人物', style: TextStyle(fontSize: 11)),
              onPressed: onClear,
            ),
            const SizedBox(width: 6),
            for (final person in people)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InputChip(
                  label: Text(
                    person.fullName,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onDeleted: onTap,
                  onPressed: onTap,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PhotoMeta {
  const _PhotoMeta({
    required this.people,
    required this.caption,
    required this.takenAt,
  });

  final List<ApiPerson> people;
  final String caption;
  final DateTime? takenAt;
}

String _dateLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
