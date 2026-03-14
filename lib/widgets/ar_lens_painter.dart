import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/lens_model.dart';
import '../services/vision_service.dart'; 
import 'dart:math';

class ARLensPainter extends CustomPainter {
  final EyeData eyeData;
  final Lens? selectedLens;
  final ui.Image? lensImage;
  final Size imageSize;
  final bool isFrontCamera;

  ARLensPainter({
    required this.eyeData,
    required this.selectedLens,
    required this.lensImage,
    required this.imageSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? localImage = lensImage;
    if (selectedLens == null || localImage == null) return;
    
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    if (eyeData.leftEyeCenter == null || eyeData.rightEyeCenter == null) return;

    final Offset leftEye = Offset(
      isFrontCamera ? size.width - (eyeData.leftEyeCenter!.x.toDouble() * scaleX) : eyeData.leftEyeCenter!.x.toDouble() * scaleX,
      eyeData.leftEyeCenter!.y.toDouble() * scaleY,
    );
    final Offset rightEye = Offset(
      isFrontCamera ? size.width - (eyeData.rightEyeCenter!.x.toDouble() * scaleX) : eyeData.rightEyeCenter!.x.toDouble() * scaleX,
      eyeData.rightEyeCenter!.y.toDouble() * scaleY,
    );

    _drawLens(canvas, leftEye, rightEye, localImage);
  }

  void _drawLens(Canvas canvas, Offset left, Offset right, ui.Image image) {
    final double eyeDistance = (right - left).distance;
    final double angle = atan2(right.dy - left.dy, right.dx - left.dx);
    final double lensSize = eyeDistance * 1.2;

    final Paint paint = Paint()
      // [Enterprise Ready] 최신 엔진 규격: withValues(alpha: ...)로 교체
      ..color = Colors.white.withValues(alpha: selectedLens!.opacity)
      ..blendMode = _getBlendMode(selectedLens!.blendingMode);

    canvas.save();
    canvas.translate(left.dx, left.dy);
    canvas.rotate(angle);
    _drawSingleLens(canvas, lensSize, paint, image);
    canvas.restore();

    canvas.save();
    canvas.translate(right.dx, right.dy);
    canvas.rotate(angle);
    _drawSingleLens(canvas, lensSize, paint, image);
    canvas.restore();
  }

  void _drawSingleLens(Canvas canvas, double size, Paint paint, ui.Image image) {
    final Rect destRect = Rect.fromCenter(center: Offset.zero, width: size, height: size);
    final Rect srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    
    try {
      canvas.drawImageRect(image, srcRect, destRect, paint);
    } catch (e) {
      debugPrint('🎨 [Painter Error] Drawing Image failed: $e');
    }
  }

  BlendMode _getBlendMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'multiply':
        return BlendMode.multiply;
      case 'screen':
        return BlendMode.screen;
      case 'overlay':
        return BlendMode.overlay;
      case 'hardlight':
        return BlendMode.hardLight;
      case 'modulate':
      default:
        return BlendMode.modulate;
    }
  }

  @override
  bool shouldRepaint(covariant ARLensPainter oldDelegate) {
    return oldDelegate.eyeData != eyeData || 
           oldDelegate.selectedLens != selectedLens ||
           oldDelegate.lensImage != lensImage;
  }
}
