import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/lens_provider.dart';
import '../services/vision_service.dart';
import '../widgets/ar_lens_painter.dart';
import 'edit_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  final VisionService _visionService = VisionService();
  bool _isCameraInitialized = false;
  CameraDescription? _cameraDescription;

  // 화면을 캡처하기 위해 씌워둘 투명한 덮개의 이름표(Key)입니다.
  final GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraDescription = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _isCameraInitialized = true;
      if (mounted) {
        setState(() {});
      }

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

  // 화면을 고화질(pixelRatio: 3.0) 이미지로 찍어내고 편집 화면으로 넘겨주는 함수
  Future<void> _captureAndNavigate() async {
    try {
      // 1. 이름표(Key)를 이용해 덮어둔 화면 영역을 찾습니다.
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      // 2. 화면을 이미지로 변환합니다. (pixelRatio를 높이면 화질이 좋아집니다)
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      // 3. 이미지를 컴퓨터가 이해할 수 있는 바이트(Byte) 데이터로 바꿉니다.
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (!mounted) return;
      // 4. 캡처한 이미지를 들고 편집 화면(Edit Screen)으로 이동합니다.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditScreen(capturedImage: pngBytes),
        ),
      );
    } catch (e) {
      debugPrint('화면 캡처 실패: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _visionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'ARlens',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 0층: 안전장치 (카메라가 켜지지 않아도 기본 배경은 검은색)
          Container(color: Colors.black),

          // 캡처 영역 시작
          RepaintBoundary(
            key: _globalKey,
            child: Stack(
              children: [
                // 1층: 카메라 프리뷰
                if (_isCameraInitialized && _cameraController != null)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width:
                            _cameraController!.value.previewSize?.height ?? 1,
                        height:
                            _cameraController!.value.previewSize?.width ?? 1,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ),

                // 2층: AR 렌즈 (비전 엔진이 지원될 때만 그립니다)
                if (_isCameraInitialized && _cameraController != null)
                  Positioned.fill(
                    child: Consumer<LensProvider>(
                      builder: (context, lensProvider, child) {
                        return ListenableBuilder(
                          listenable: _visionService,
                          builder: (context, _) {
                            // 에뮬레이터 환경 등으로 비전 엔진이 꺼졌다면, 중앙에 안내 문구를 띄웁니다.
                            if (!_visionService.isVisionSupported) {
                              return const Center(
                                child: Text(
                                  '💻 에뮬레이터 환경\n(AR 프리뷰 비활성화)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }

                            // 정상 작동 시 렌즈 그래픽 그리기
                            final previewSize =
                                _cameraController!.value.previewSize!;
                            return CustomPaint(
                              painter: ARLensPainter(
                                eyeData: _visionService.eyeData,
                                selectedLens: lensProvider.selectedLens,
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
              ],
            ),
          ),

          // 3층: 최상단 고정 UI (렌즈 슬라이더 및 촬영 버튼) - 어떠한 상황에서도 무조건 살아있습니다!
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.transparent, // 투명하게 설정하여 뒤의 카메라가 보이게 합니다.
              height: 180,
              child: Column(
                children: [
                  // 렌즈 선택 슬라이더
                  SizedBox(
                    height: 100,
                    child: Consumer<LensProvider>(
                      builder: (context, lensProvider, child) {
                        // 데이터를 가져오는 중이면 Y2K 감성의 로딩 인디케이터를 보여줍니다.
                        if (lensProvider.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.pinkAccent,
                              strokeWidth: 4.0,
                            ),
                          );
                        }

                        final lenses = lensProvider.lenses;

                        // 가져온 렌즈가 없을 경우 안내 문구를 띄워줍니다.
                        if (lenses.isEmpty) {
                          return const Center(
                            child: Text(
                              '불러올 렌즈가 없습니다 😢',
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        }

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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
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
                                  // 한 번 다운받은 렌즈 썸네일은 스마트폰에 저장(캐싱)하여 데이터를 아낍니다.
                                  image: DecorationImage(
                                    image: CachedNetworkImageProvider(
                                      lens.thumbnailUrl,
                                    ),
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
                  const Spacer(),
                  // 네온 블루 촬영(캡처) 버튼
                  GestureDetector(
                    onTap: _captureAndNavigate,
                    child: Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.blueAccent,
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
