import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';

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
  // 구글 ML Kit 얼굴 인식기 설정
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isProcessing = false; // 현재 사진을 분석 중인지 체크하는 안전장치
  bool _isVisionSupported = true; // 에뮬레이터 호환성 문제 방어용 플래그
  EyeData _eyeData = EyeData(); // 추출된 눈 좌표 데이터

  bool get isProcessing => _isProcessing;
  bool get isVisionSupported => _isVisionSupported;
  EyeData get eyeData => _eyeData;

  // 카메라에서 실시간으로 넘어오는 프레임(사진)을 분석하는 메인 함수
  Future<void> processImage(CameraImage image, int sensorOrientation) async {
    // 1. 이미 비전 엔진이 지원하지 않는 환경(에뮬레이터 등)으로 판명났다면, 아예 시도조차 하지 않고 버립니다. (앱 멈춤 방지)
    if (!_isVisionSupported) return;

    // 2. 이전 사진을 아직 분석 중이면 이번 사진은 버립니다.
    if (_isProcessing) return;
    _isProcessing = true;

    try {
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

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final Face firstFace = faces.first;
        final leftEyeLandmark = firstFace.landmarks[FaceLandmarkType.leftEye];
        final rightEyeLandmark = firstFace.landmarks[FaceLandmarkType.rightEye];
        final leftEyeContour =
            firstFace.contours[FaceContourType.leftEye]?.points ?? [];
        final rightEyeContour =
            firstFace.contours[FaceContourType.rightEye]?.points ?? [];

        _eyeData = EyeData(
          leftEyeCenter: leftEyeLandmark?.position,
          rightEyeCenter: rightEyeLandmark?.position,
          leftEyeContour: leftEyeContour,
          rightEyeContour: rightEyeContour,
        );
      } else {
        _eyeData = EyeData();
      }
    } on PlatformException catch (e) {
      // [핵심] 에뮬레이터에서 흔히 발생하는 이미지 포맷 변환 에러를 잡습니다.
      if (_isVisionSupported) {
        debugPrint(
          '⚠️ [VisionService 경고] 에뮬레이터 환경에서 지원하지 않는 이미지 포맷입니다. 이후 비전 연산을 영구 중단합니다. (에러: ${e.code})',
        );
        _isVisionSupported = false; // 플래그를 내려서 다음 프레임부터는 아예 분석을 시도하지 않게 만듭니다.
      }
    } catch (e) {
      debugPrint('VisionService Error: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }
}
