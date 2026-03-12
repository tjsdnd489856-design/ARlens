import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// 눈과 관련된 좌표 데이터들을 묶어둘 상자(데이터 모델)
class EyeData {
  final Point<int>? leftEyeCenter;
  final Point<int>? rightEyeCenter;
  final List<Point<int>> leftEyeContour;
  final List<Point<int>> rightEyeContour;

  EyeData({
    this.leftEyeCenter,
    this.rightEyeCenter,
    this.leftEyeContour = const [],
    this.rightEyeContour = const [],
  });
}

class VisionService extends ChangeNotifier {
  // 구글 ML Kit 얼굴 인식기 설정 (윤곽선과 특징점을 모두 찾도록 설정하고 빠른 모드 사용)
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isProcessing = false; // 현재 사진을 분석 중인지 체크하는 안전장치
  EyeData _eyeData = EyeData(); // 추출된 눈 좌표 데이터

  bool get isProcessing => _isProcessing;
  EyeData get eyeData => _eyeData;

  // 카메라에서 실시간으로 넘어오는 프레임(사진)을 분석하는 메인 함수
  Future<void> processImage(CameraImage image, int sensorOrientation) async {
    // 이전 사진을 아직 분석 중이면 이번 사진은 그냥 버립니다 (성능 보호)
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // 1. CameraImage(카메라 원본)를 ML Kit이 읽을 수 있는 InputImage로 변환
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final InputImageRotation imageRotation =
          InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final InputImageFormat inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      // 2. 변환된 이미지에서 얼굴 찾기
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        // 첫 번째(가장 잘 보이는) 얼굴을 기준으로 눈 데이터 추출
        final Face firstFace = faces.first;

        // 눈동자 중심점 (랜드마크)
        final leftEyeLandmark = firstFace.landmarks[FaceLandmarkType.leftEye];
        final rightEyeLandmark = firstFace.landmarks[FaceLandmarkType.rightEye];

        // 눈꺼풀 윤곽선 점들의 모음 (컨투어)
        final leftEyeContour =
            firstFace.contours[FaceContourType.leftEye]?.points ?? [];
        final rightEyeContour =
            firstFace.contours[FaceContourType.rightEye]?.points ?? [];

        // 찾아낸 데이터를 묶음
        _eyeData = EyeData(
          leftEyeCenter: leftEyeLandmark?.position,
          rightEyeCenter: rightEyeLandmark?.position,
          leftEyeContour: leftEyeContour,
          rightEyeContour: rightEyeContour,
        );
      } else {
        // 얼굴을 못 찾으면 데이터 비우기
        _eyeData = EyeData();
      }
    } catch (e) {
      debugPrint('VisionService Error: $e');
    } finally {
      // 분석이 끝났으므로 다른 사진을 받을 수 있도록 잠금 해제
      _isProcessing = false;
      notifyListeners(); // 새 눈 좌표가 나왔으니 화면을 다시 그리라고 알려줌
    }
  }

  // 앱이 꺼질 때 인식기도 정리해줍니다.
  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }
}
