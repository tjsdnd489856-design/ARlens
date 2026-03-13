import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/vision_service.dart';
import '../models/lens_model.dart';

class ARLensPainter extends CustomPainter {
  final EyeData eyeData;
  final Lens? selectedLens;
  final ui.Image? lensImage; 
  final Size imageSize;
  final bool isFrontCamera;

  // 뷰티 보정 값
  final double skinValue;
  final double eyeValue;
  final double chinValue;

  ARLensPainter({
    required this.eyeData,
    required this.selectedLens,
    this.lensImage,
    required this.imageSize,
    this.isFrontCamera = true,
    this.skinValue = 0.5,
    this.eyeValue = 0.5,
    this.chinValue = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedLens == null) return;
    if (eyeData.leftEyeCenter == null || eyeData.rightEyeCenter == null) return;

    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    Offset scaleOffset(Point<int> point) {
      final double x = isFrontCamera
          ? imageSize.width - point.x.toDouble()
          : point.x.toDouble();
      return Offset(x * scaleX, point.y.toDouble() * scaleY);
    }

    // 1. 피부 보정 (Skin Smoothing)
    if (skinValue > 0.5) {
      final double opacity = (skinValue - 0.5) * 0.2;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }

    // [신규] 블렌딩 모드 맵핑
    BlendMode _getBlendMode(String mode) {
      switch (mode) {
        case 'overlay': return BlendMode.overlay;
        case 'softLight': return BlendMode.softLight;
        case 'multiply': return BlendMode.multiply;
        case 'screen': return BlendMode.screen;
        case 'modulate': return BlendMode.modulate;
        case 'srcOver': default: return BlendMode.srcOver; // 기본
      }
    }

    final blendMode = _getBlendMode(selectedLens!.blendingMode);
    
    // [업그레이드] 하이퍼 리얼리즘 Paint 설정
    final Paint lensPaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = ui.FilterQuality.high
      ..blendMode = blendMode
      ..color = Colors.white.withValues(alpha: selectedLens!.opacity);

    // 2. 눈 크기 보정 (Eye Size)
    final double dynamicLensSize = 30.0 + (eyeValue * 25.0);

    // 왼쪽 눈 그리기
    _drawLens(
      canvas: canvas,
      center: eyeData.leftEyeCenter!,
      contour: eyeData.leftEyeContour,
      scaleOffset: scaleOffset,
      lensPaint: lensPaint,
      lensSize: dynamicLensSize,
      opacity: selectedLens!.opacity,
    );

    // 오른쪽 눈 그리기
    _drawLens(
      canvas: canvas,
      center: eyeData.rightEyeCenter!,
      contour: eyeData.rightEyeContour,
      scaleOffset: scaleOffset,
      lensPaint: lensPaint,
      lensSize: dynamicLensSize,
      opacity: selectedLens!.opacity,
    );
  }

  void _drawLens({
    required Canvas canvas,
    required Point<int> center,
    required List<Point<int>> contour,
    required Offset Function(Point<int>) scaleOffset,
    required Paint lensPaint,
    required double lensSize,
    required double opacity,
  }) {
    if (contour.isEmpty) return;

    final Path eyePath = Path();
    for (int i = 0; i < contour.length; i++) {
      final Offset offset = scaleOffset(contour[i]);
      if (i == 0) {
        eyePath.moveTo(offset.dx, offset.dy);
      } else {
        eyePath.lineTo(offset.dx, offset.dy);
      }
    }
    eyePath.close();

    // 1. 눈 형태에 맞게 클리핑 (가장자리 부드럽게)
    canvas.save();
    canvas.clipPath(eyePath);

    final Offset centerOffset = scaleOffset(center);
    final Rect destRect = Rect.fromCenter(
      center: centerOffset,
      width: lensSize,
      height: lensSize,
    );

    // [신규] 홍채 중심부(동공) 투명도 레이어링 마스크 (RadialGradient)
    // 외곽은 설정된 불투명도를 유지하고 중심부로 갈수록 투명해져 실제 홍채가 보이도록 연출
    final Paint maskPaint = Paint()
      ..shader = ui.Gradient.radial(
        centerOffset,
        lensSize / 2,
        [
          Colors.transparent, // 동공 부위 완전 투명
          Colors.white.withValues(alpha: opacity * 0.5), // 중간 부위 반투명
          Colors.white.withValues(alpha: opacity), // 외곽 렌즈 그래픽 선명
        ],
        [0.1, 0.4, 1.0], // 그라데이션 위치 조정
      )
      ..blendMode = BlendMode.dstIn;

    if (lensImage != null) {
      // 렌즈 이미지 먼저 렌더링
      final Rect srcRect = Rect.fromLTWH(
        0,
        0,
        lensImage!.width.toDouble(),
        lensImage!.height.toDouble(),
      );
      
      // 이미지 그리기
      canvas.saveLayer(destRect, Paint());
      canvas.drawImageRect(lensImage!, srcRect, destRect, lensPaint);
      
      // 중심 투명 마스크 적용
      canvas.drawRect(destRect, maskPaint);
      canvas.restore();
    } else {
       // 이미지가 없을 때의 Fallback (단색 렌즈)
       canvas.saveLayer(destRect, Paint());
       canvas.drawCircle(centerOffset, lensSize / 2, lensPaint);
       canvas.drawRect(destRect, maskPaint);
       canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ARLensPainter oldDelegate) {
    return oldDelegate.eyeData != eyeData ||
        oldDelegate.selectedLens != selectedLens ||
        oldDelegate.lensImage != lensImage ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.skinValue != skinValue ||
        oldDelegate.eyeValue != eyeValue ||
        oldDelegate.chinValue != chinValue;
  }
}
