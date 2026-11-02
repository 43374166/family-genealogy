import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// One picked and already compressed image ready to upload.
class PickedImageData {
  const PickedImageData({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  int get sizeBytes => bytes.length;
}

/// Picks a single image. `imageQuality` / `maxWidth` are handled by the native
/// picker, which JPEG-compresses before the bytes reach Dart.
Future<PickedImageData?> pickSingleImage({
  ImageSource source = ImageSource.gallery,
  int maxWidth = 1600,
  int imageQuality = 80,
}) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: maxWidth.toDouble(),
    imageQuality: imageQuality,
  );
  if (picked == null) return null;
  return PickedImageData(
    bytes: await picked.readAsBytes(),
    filename: picked.name,
  );
}

/// Picks multiple images at once. The native picker compresses each image.
Future<List<PickedImageData>> pickMultipleImages({
  int maxWidth = 1600,
  int imageQuality = 72,
  int limit = 9,
}) async {
  final picked = await ImagePicker().pickMultiImage(
    maxWidth: maxWidth.toDouble(),
    imageQuality: imageQuality,
    limit: limit,
  );
  final result = <PickedImageData>[];
  for (final file in picked.take(limit)) {
    result.add(
      PickedImageData(bytes: await file.readAsBytes(), filename: file.name),
    );
  }
  return result;
}
