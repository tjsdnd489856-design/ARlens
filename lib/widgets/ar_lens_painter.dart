import 'dart:math';
import 'package:flutter/material.dart';
import '../services/vision_service.dart';
import '../models/lens_model.dart';

class ARLensPainter extends CustomPainter {
  final EyeData eyeData;
  final Lens? selectedLens;
  final Size imageSize;
  final bool isFrontCamera; // 전면 카메라일 경우 좌우 반전 처리를 위한 변수

  ARLensPainter({
    required this.eyeData,
    required this.selectedLens,
    required this.imageSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 렌즈를 선택하지 않았거나, 눈을 인식하지 못했다면 아무것도 그리지 않습니다.
    if (selectedLens == null) return;
    if (eyeData.leftEyeCenter == null || eyeData.rightEyeCenter == null) return;

    // 카메라 원본 사진 크기와 내 스마트폰 화면 크기 비율을 계산합니다.
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // ML Kit에서 나온 좌표를 화면 크기에 맞게, 그리고 거울 모드에 맞게 변환해주는 함수
    Offset scaleOffset(Point<int> point) {
      // 전면 카메라면 거울처럼 좌우를 뒤집어줍니다.
      final double x = isFrontCamera
          ? imageSize.width - point.x.toDouble()
          : point.x.toDouble();
      return Offset(x * scaleX, point.y.toDouble() * scaleY);
    }

    // 선택한 렌즈에 따른 임시 Y2K 감성 색상 물감(Paint)을 만듭니다.
    Color lensColor = Colors.transparent;
    if (selectedLens!.id == 'lens_1')
      lensColor = Colors.pinkAccent.withOpacity(0.6); // 체리밤 핑크
    else if (selectedLens!.id == 'lens_2')
      lensColor = Colors.blueAccent.withOpacity(0.6); // 네온 블루
    else if (selectedLens!.id == 'lens_3')
      lensColor = Colors.grey.withOpacity(0.6); // 사이버 그레이

    final Paint lensPaint = Paint()
      ..color = lensColor
      ..style = PaintingStyle.fill;

    // 왼쪽 눈 그리기
    _drawLens(
      canvas: canvas,
      center: eyeData.leftEyeCenter!,
      contour: eyeData.leftEyeContour,
      scaleOffset: scaleOffset,
      lensPaint: lensPaint,
    );

    // 오른쪽 눈 그리기
    _drawLens(
      canvas: canvas,
      center: eyeData.rightEyeCenter!,
      contour: eyeData.rightEyeContour,
      scaleOffset: scaleOffset,
      lensPaint: lensPaint,
    );
  }

  // 한쪽 눈에 렌즈를 씌우는 핵심 로직
  void _drawLens({
    required Canvas canvas,
    required Point<int> center,
    required List<Point<int>> contour,
    required Offset Function(Point<int>) scaleOffset,
    required Paint lensPaint,
  }) {
    if (contour.isEmpty) return;

    // 1. 눈꺼풀 윤곽선을 이어붙여서 눈 모양의 투명한 틀(Path)을 만듭니다.
    final Path eyePath = Path();
    for (int i = 0; i < contour.length; i++) {
      final Offset offset = scaleOffset(contour[i]);
      if (i == 0) {
        eyePath.moveTo(offset.dx, offset.dy);
      } else {
        eyePath.lineTo(offset.dx, offset.dy);
      }
    }
    eyePath.close(); // 선을 닫아서 온전한 도형으로 만듭니다.

    // 2. 캔버스의 현재 상태를 저장하고, '마스킹(Clip)'을 적용합니다.
    // ※ 매우 중요: 이 코드 덕분에 이후에 그리는 렌즈는 오직 이 눈꺼풀 틀 안에서만 보이게 됩니다. 눈을 깜빡이면 렌즈도 잘립니다!
    canvas.save();
    canvas.clipPath(eyePath);

    // 3. 눈동자 중심에 렌즈(동그라미)를 그립니다. 눈 모양 틀 안에 갇혀있게 됩니다.
    final Offset centerOffset = scaleOffset(center);
    // 임시 크기: 반경 30. 실제 렌즈 이미지(텍스처)를 덮어씌울 때도 같은 원리를 사용합니다.
    canvas.drawCircle(centerOffset, 30.0, lensPaint);

    // 4. 마스킹을 풀고 캔버스를 원래 상태로 돌려놓습니다. (반대쪽 눈을 그리기 위함)
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ARLensPainter oldDelegate) {
    // 눈을 움직였거나, 렌즈를 다른 색으로 바꿨을 때만 화면을 다시 그립니다 (성능 최적화).
    return oldDelegate.eyeData != eyeData ||
        oldDelegate.selectedLens != selectedLens ||
        oldDelegate.imageSize != imageSize;
  }
}
