import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../search/member_search_page.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, this.personId, this.personName});

  final String? personId;
  final String? personName;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<ApiPhoto> _photos = const [];
  bool _loading = true;
  bool _uploading = false;
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
      final photos = await SessionScope.of(
        context,
      ).photos(personId: widget.personId);
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

  Future<void> _upload() async {
    final session = SessionScope.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;
    final meta = await _askMeta(
      initialPersonId: widget.personId,
      initialPersonName: widget.personName,
    );
    if (meta == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final photo = await session.uploadPhoto(
        bytes: bytes,
        filename: picked.name,
        personId: meta.personId,
        caption: meta.caption,
        takenAt: meta.takenAt,
      );
      if (!mounted) return;
      setState(() {
        _photos = [photo, ..._photos];
        _uploading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('照片已上传')));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('照片上传失败，请稍后重试')));
    }
  }

  Future<_PhotoMeta?> _askMeta({
    String? initialPersonId,
    String? initialPersonName,
    ApiPhoto? photo,
  }) async {
    var personId = initialPersonId ?? photo?.personId ?? '';
    var personName = initialPersonName ?? photo?.personName ?? '';
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
                    final person = await Navigator.of(context).push<ApiPerson>(
                      MaterialPageRoute<ApiPerson>(
                        builder: (_) =>
                            const MemberSearchPage(selectMode: true),
                      ),
                    );
                    if (person != null) {
                      setDialogState(() {
                        personId = person.id;
                        personName = person.fullName;
                      });
                    }
                  },
                  icon: const Icon(Icons.person_pin_circle_outlined, size: 18),
                  label: Text(
                    personId.isEmpty ? '关联人物（可选）' : personName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (personId.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setDialogState(() {
                        personId = '';
                        personName = '';
                      }),
                      child: const Text('清除人物'),
                    ),
                  ),
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
                  personId: personId,
                  personName: personName,
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
      builder: (dialogContext) => Dialog(
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
                  if (photo.personName.isNotEmpty)
                    Text(
                      photo.personName,
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
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
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
                          personId: meta.personId,
                          caption: meta.caption,
                          takenAt: meta.takenAt,
                        );
                        if (!mounted) return;
                        setState(() {
                          _photos = _photos
                              .map(
                                (item) => item.id == photo.id ? updated : item,
                              )
                              .toList(growable: false);
                        });
                      } on ApiException catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error.message)));
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
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error.message)));
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
              subtitle: _loading ? '正在加载照片' : '${_photos.length} 张照片',
              actions: [
                HeaderIconButton(
                  icon: Icons.add_photo_alternate_outlined,
                  onTap: _uploading ? () {} : _upload,
                ),
              ],
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
                              children: const [
                                SizedBox(height: 120),
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 44,
                                  color: AppColors.inkMuted,
                                ),
                                SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    '还没有照片',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    '点右上角上传第一张家族照片',
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
                                    borderRadius: BorderRadius.circular(9),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          session.photoUrl(photo.contentPath),
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
                                        if (photo.personName.isNotEmpty)
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
                                                photo.personName,
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
            if (_uploading) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}

class _PhotoMeta {
  const _PhotoMeta({
    required this.personId,
    required this.personName,
    required this.caption,
    required this.takenAt,
  });

  final String personId;
  final String personName;
  final String caption;
  final DateTime? takenAt;
}

String _dateLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
