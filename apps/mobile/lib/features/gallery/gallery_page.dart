import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

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
      final photos = await SessionScope.of(context).photos();
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
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final photo = await session.uploadPhoto(
        bytes: bytes,
        filename: picked.name,
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

  Future<void> _showPhoto(ApiPhoto photo) async {
    final session = SessionScope.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
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
            if (photo.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  photo.caption,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
                if (photo.uploadedByUserId == session.user?.id ||
                    session.canWrite)
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
                        if (context.mounted) Navigator.of(context).pop();
                      } on ApiException catch (error) {
                        if (!context.mounted) return;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '家族相册',
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
                                    child: Image.network(
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
