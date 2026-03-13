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
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isProcessing = false; 
  bool _isVisionSupported = true; 
  EyeData _eyeData = EyeData(); 
  
  // [추가] 쓰로틀링을 위한 마지막 실행 시간 기록
  DateTime _lastProcessDateTime = DateTime.now();

  bool get isProcessing => _isProcessing;
  bool get isVisionSupported => _isVisionSupported;
  EyeData get eyeData => _eyeData;

  Future<void> processImage(CameraImage image, int sensorOrientation) async {
    if (!_isVisionSupported) return;

    // [1. 프레임 드랍] 이미 분석 중이면 새로운 프레임은 버립니다.
    if (_isProcessing) return;

    // [2. 쓰로틀링] 마지막 분석으로부터 50ms가 지나지 않았다면 프레임을 버립니다. (초당 최대 20프레임)
    final now = DateTime.now();
    if (now.difference(_lastProcessDateTime).inMilliseconds < 50) return;

    _isProcessing = true;
    _lastProcessDateTime = now; // 실행 시간 업데이트

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
      if (_isVisionSupported) {
        debugPrint('⚠️ [VisionService] 에뮬레이터 환경 비활성화: ${e.code}');
        _isVisionSupported = false;
      }
    } catch (e) {
      debugPrint('VisionService Error: $e');
    } finally {
      // [핵심] 연산 완료 후(성공/실패 무관) 분석 중 플래그를 해제하여 다음 프레임을 받을 수 있게 합니다.
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
