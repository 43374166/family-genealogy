import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/images/image_crop_page.dart';
import '../../core/images/image_pick_service.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/app_session.dart';

/// Lets a user pick, crop and upload an avatar for [personId].
///
/// The server already allows the family owner and branch admins to change any
/// person's avatar, so this helper is shared by the profile page and person
/// detail page.
Future<bool> showAvatarActions(
  BuildContext context, {
  required String personId,
  required bool canRemove,
}) async {
  final session = SessionScope.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.primary,
            ),
            title: const Text('从相册选择并裁剪'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_camera_outlined,
              color: AppColors.primary,
            ),
            title: const Text('拍照并裁剪'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          if (canRemove)
            ListTile(
              leading: const Icon(
                Icons.restart_alt_rounded,
                color: AppColors.cinnabar,
              ),
              title: const Text('恢复默认头像'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return false;
  if (action == 'remove') {
    try {
      await session.deleteAvatar(personId);
      if (!context.mounted) return true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已恢复默认头像')));
      return true;
    } on ApiException catch (error) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    }
  }
  final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
  final picked = await pickSingleImage(
    source: source,
    maxWidth: 2000,
    imageQuality: 90,
  );
  if (picked == null || !context.mounted) return false;
  final cropped = await cropImageBytes(
    context,
    picked.bytes,
    title: '裁剪头像',
    outputSize: 720,
  );
  if (cropped == null || !context.mounted) return false;
  try {
    await session.uploadAvatar(
      personId: personId,
      bytes: cropped,
      filename: 'avatar.png',
    );
    if (!context.mounted) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('头像已更新，族谱树同步生效')));
    return true;
  } on ApiException catch (error) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  }
}
