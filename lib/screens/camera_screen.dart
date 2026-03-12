import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/lens_provider.dart';
import '../services/vision_service.dart';
import '../widgets/ar_lens_painter.dart';

// 상태가 변하는(카메라가 켜지고 꺼지는) 화면이므로 StatefulWidget으로 변경합니다.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  final VisionService _visionService = VisionService(); // 우리가 만든 비전 엔진
  bool _isCameraInitialized = false;
  CameraDescription? _cameraDescription;

  @override
  void initState() {
    super.initState();
    _initializeCamera(); // 화면이 켜지자마자 카메라 준비 시작
  }

  // 카메라를 찾고 연결하는 핵심 로직
  Future<void> _initializeCamera() async {
    try {
      // 내 폰에 달린 모든 카메라 렌즈 목록을 가져옵니다.
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // 거울처럼 내 얼굴을 봐야 하니 전면 카메라(셀카 렌즈)를 우선적으로 찾습니다.
      _cameraDescription = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first, // 없으면 후면 카메라라도 사용
      );

      // 카메라 조종기를 만듭니다. (성능을 위해 해상도는 너무 높지 않게 Medium으로 설정)
      _cameraController = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false, // 동영상 녹화가 아니므로 마이크는 끕니다.
      );

      await _cameraController!.initialize();
      _isCameraInitialized = true;
      if (mounted) {
        setState(() {}); // 카메라가 준비되었으니 화면을 다시 그리라고 알려줍니다.
      }

      // [핵심] 1초에 수십 장씩 찍히는 사진(프레임)을 실시간으로 가져와서 비전 엔진에 넘겨줍니다!
      _cameraController!.startImageStream((CameraImage image) {
        _visionService.processImage(
          image,
          _cameraDescription!.sensorOrientation,
        );
      });
    } catch (e) {
      debugPrint('카메라 초기화 실패: $e');
    }
  }

  @override
  void dispose() {
    // 화면이 꺼질 때는 카메라와 비전 엔진도 깔끔하게 꺼서 배터리를 아껴줍니다.
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _visionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'ARlens',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true, // 앱바 뒤로 카메라 화면이 꽉 차게 올라가도록 설정
      body: Stack(
        // 여러 위젯을 샌드위치처럼 겹겹이 쌓는 도구
        children: [
          // 1층: 실제 카메라 프리뷰 화면
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover, // 화면에 빈틈없이 꽉 차게
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: Colors.pinkAccent,
              ), // 카메라 켜지는 동안 로딩 표시
            ),

          // 2층: AR 렌즈를 그려주는 투명한 도화지 (마스킹 오버레이)
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: Consumer<LensProvider>(
                // 어떤 렌즈가 선택되었는지 관찰
                builder: (context, lensProvider, child) {
                  return ListenableBuilder(
                    // 비전 엔진이 새 눈 좌표를 찾을 때마다 다시 그림
                    listenable: _visionService,
                    builder: (context, _) {
                      final previewSize = _cameraController!.value.previewSize!;

                      return CustomPaint(
                        painter: ARLensPainter(
                          eyeData: _visionService.eyeData,
                          selectedLens: lensProvider.selectedLens,
                          // 카메라가 세로로 찍힐 때 가로/세로 비율이 반대로 들어오는 것을 보정해줍니다.
                          imageSize: Size(
                            previewSize.height,
                            previewSize.width,
                          ),
                          isFrontCamera:
                              _cameraDescription?.lensDirection ==
                              CameraLensDirection.front,
                        ),
                      );
                    },
                  );
                },
              ),
            ),

          // 3층: 사용자가 렌즈를 고르는 하단 슬라이더
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 100,
              child: Consumer<LensProvider>(
                builder: (context, lensProvider, child) {
                  final lenses = lensProvider.lenses;

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: lenses.length,
                    itemBuilder: (context, index) {
                      final lens = lenses[index];
                      final isSelected =
                          lensProvider.selectedLens?.id == lens.id;

                      return GestureDetector(
                        onTap: () {
                          lensProvider.selectLens(lens);
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [
                                    const BoxShadow(
                                      color: Colors.pinkAccent,
                                      blurRadius: 15,
                                      spreadRadius: 5,
                                    ),
                                  ]
                                : [],
                            border: Border.all(
                              color: isSelected
                                  ? Colors.pinkAccent
                                  : Colors.grey.shade800,
                              width: isSelected ? 3 : 2,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(lens.thumbnailUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
