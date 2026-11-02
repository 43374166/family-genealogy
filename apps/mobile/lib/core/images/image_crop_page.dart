import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Square crop editor used for person avatars. The editor is implemented with
/// `dart:ui` only, so it works on Android and iOS without adding a native
/// cropping plugin.
class ImageCropPage extends StatefulWidget {
  const ImageCropPage({
    super.key,
    required this.bytes,
    this.title = '裁剪头像',
    this.outputSize = 720,
  });

  final Uint8List bytes;
  final String title;
  final int outputSize;

  @override
  State<ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  ui.Image? _image;
  String? _error;
  double _scale = 1;
  double _startScale = 1;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  bool _exporting = false;
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _image = frame.image);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '读取图片失败，请换一张图片重试');
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _zoom(double delta) {
    final image = _image;
    if (image == null) return;
    setState(() {
      _scale = (_scale + delta).clamp(1.0, 5.0);
      _offset = _clampOffset(_offset, image, _scale);
    });
  }

  Offset _clampOffset(Offset value, ui.Image image, double scale) {
    final base = _coverScale(image);
    final displayedWidth = image.width * base * scale;
    final displayedHeight = image.height * base * scale;
    final maxX = math.max(0.0, (displayedWidth - _viewport) / 2);
    final maxY = math.max(0.0, (displayedHeight - _viewport) / 2);
    return Offset(value.dx.clamp(-maxX, maxX), value.dy.clamp(-maxY, maxY));
  }

  double _coverScale(ui.Image image) {
    if (_viewport <= 0) return 1;
    return _viewport / math.min(image.width, image.height);
  }

  Future<void> _confirm() async {
    final image = _image;
    if (image == null || _exporting) return;
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final base = _coverScale(image);
      final totalScale = base * _scale;
      final left = (_viewport - image.width * totalScale) / 2 + _offset.dx;
      final top = (_viewport - image.height * totalScale) / 2 + _offset.dy;
      final sourceLeft = (-left / totalScale).clamp(
        0.0,
        image.width.toDouble(),
      );
      final sourceTop = (-top / totalScale).clamp(0.0, image.height.toDouble());
      final sourceSize = math.min(
        _viewport / totalScale,
        math.min(image.width - sourceLeft, image.height - sourceTop),
      );
      if (sourceSize <= 0) {
        throw StateError('empty crop');
      }
      final source = Rect.fromLTWH(
        sourceLeft,
        sourceTop,
        sourceSize,
        sourceSize,
      );
      final size = widget.outputSize.toDouble();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        source,
        Rect.fromLTWH(0, 0, size, size),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(
        widget.outputSize,
        widget.outputSize,
      );
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      picture.dispose();
      if (data == null) throw StateError('encode failed');
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _error = '裁剪失败，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: const Color(0xFF111716),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _exporting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: image == null || _exporting ? null : _confirm,
                    child: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '确定',
                            style: TextStyle(
                              color: Color(0xFF9FD6C2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(
                      constraints.maxWidth - 32,
                      constraints.maxHeight - 120,
                    );
                    _viewport = size;
                    if (image == null) {
                      return SizedBox(
                        width: size,
                        height: size,
                        child: _error == null
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : Center(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onScaleStart: (details) {
                            _startScale = _scale;
                            _startOffset = _offset;
                            _startFocal = details.localFocalPoint;
                          },
                          onScaleUpdate: (details) {
                            final newScale = (_startScale * details.scale)
                                .clamp(1.0, 5.0);
                            final center = Offset(size / 2, size / 2);
                            final anchor =
                                ((_startFocal - center - _startOffset) /
                                _startScale);
                            final nextOffset =
                                details.localFocalPoint -
                                center -
                                anchor * newScale;
                            setState(() {
                              _scale = newScale;
                              _offset = _clampOffset(
                                nextOffset,
                                image,
                                newScale,
                              );
                            });
                          },
                          child: ClipRect(
                            child: SizedBox(
                              width: size,
                              height: size,
                              child: CustomPaint(
                                painter: _CropPainter(
                                  image: image,
                                  scale: _scale,
                                  offset: _offset,
                                  baseScale: _coverScale(image),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFFFB4AB),
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => _zoom(-0.2),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            const SizedBox(width: 14),
                            const Text(
                              '双指缩放 · 拖动调整位置',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 14),
                            IconButton.filledTonal(
                              onPressed: () => _zoom(0.2),
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                      ],
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

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.scale,
    required this.offset,
    required this.baseScale,
  });

  final ui.Image image;
  final double scale;
  final Offset offset;
  final double baseScale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B100F),
    );
    final total = baseScale * scale;
    final width = image.width * total;
    final height = image.height * total;
    final left = (size.width - width) / 2 + offset.dx;
    final top = (size.height - height) / 2 + offset.dy;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(left, top, width, height),
      Paint()..filterQuality = FilterQuality.high,
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      border,
    );
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.scale != scale ||
      oldDelegate.offset != offset ||
      oldDelegate.baseScale != baseScale;
}

/// Opens the crop editor for an already picked image. Returns PNG bytes.
Future<Uint8List?> cropImageBytes(
  BuildContext context,
  Uint8List bytes, {
  String title = '裁剪头像',
  int outputSize = 720,
}) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute<Uint8List>(
      builder: (_) =>
          ImageCropPage(bytes: bytes, title: title, outputSize: outputSize),
      fullscreenDialog: true,
    ),
  );
}
