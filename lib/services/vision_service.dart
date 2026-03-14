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
  // [Enterprise Ready] 웹 환경에서는 ML Kit을 초기화하지 않음
  final FaceDetector? _faceDetector = kIsWeb ? null : FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isProcessing = false; 
  bool _isVisionSupported = !kIsWeb; // 웹은 기본적으로 미지원 처리
  EyeData _eyeData = EyeData(); 
  
  DateTime _lastProcessDateTime = DateTime.now();

  bool get isProcessing => _isProcessing;
  bool get isVisionSupported => _isVisionSupported;
  EyeData get eyeData => _eyeData;

  void clearState() {
    _eyeData = EyeData();
    _isProcessing = false;
    notifyListeners();
    debugPrint('🧹 [VisionService] EyeData cleared.');
  }

  Future<void> processImage(CameraImage image, int sensorOrientation) async {
    // [Enterprise Ready] 웹 환경 런타임 에러 완벽 방어
    if (kIsWeb || !_isVisionSupported || _faceDetector == null) {
      if (_isVisionSupported) {
        _isVisionSupported = false;
        notifyListeners();
      }
      return;
    }
    
    if (_isProcessing) return;

    final now = DateTime.now();
    if (now.difference(_lastProcessDateTime).inMilliseconds < 50) return;

    _isProcessing = true;
    _lastProcessDateTime = now; 

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
      debugPrint('⚠️ [VisionService] Platform Exception: ${e.code}');
      _isVisionSupported = false;
    } catch (e) {
      debugPrint('VisionService Error: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _faceDetector?.close();
    super.dispose();
  }
}
