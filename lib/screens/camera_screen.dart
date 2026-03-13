import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/lens_provider.dart';
import '../providers/brand_provider.dart';
import '../services/vision_service.dart';
import '../services/analytics_service.dart'; // 애널리틱스 추가
import '../widgets/ar_lens_painter.dart';
import 'edit_screen.dart';
import '../models/lens_model.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  final VisionService _visionService = VisionService();
  bool _isCameraInitialized = false;
  bool _hasAttemptedInit = false;
  bool _isPermissionDenied = false;
  bool _isSaving = false;
  CameraDescription? _cameraDescription;
  
  String _selectedTag = 'All';

  double _currentZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  Offset? _focusPoint;
  Timer? _focusTimer;

  OverlayEntry? _detailOverlay;
  DateTime? _detailOpenedAt; // 상세보기 체류시간 측정용

  double _skinValue = 0.5;
  double _eyeValue = 0.5;
  double _chinValue = 0.5;
  bool _showBeautyPanel = false;
  Lens? _lastSelectedLens;

  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      _initializeCamera();
    }
  }

  Future<void> _toggleCamera() async {
    HapticFeedback.selectionClick();
    final cameras = await availableCameras();
    if (cameras.length < 2) return;
    final newDirection = _cameraDescription?.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final newCamera = cameras.firstWhere((c) => c.lensDirection == newDirection, orElse: () => cameras.first);
    _initializeCamera(description: newCamera);
  }

  Future<void> _initializeCamera({CameraDescription? description}) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _isPermissionDenied = true;
        _hasAttemptedInit = true;
      });
      return;
    }

    setState(() { 
      _hasAttemptedInit = true; 
      _isCameraInitialized = false; 
      _isPermissionDenied = false;
    });

    try {
      if (description == null) {
        final cameras = await availableCameras();
        description = cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
      }
      _cameraDescription = description;
      _cameraController = CameraController(description, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
      if (mounted) setState(() { _isCameraInitialized = true; });
      _cameraController!.startImageStream((CameraImage image) {
        if (!mounted) return;
        _visionService.processImage(image, _cameraDescription!.sensorOrientation);
      });
    } catch (e) {
      if (mounted) setState(() { _isCameraInitialized = true; _cameraController = null; });
    }
  }

  Future<void> _onTapFocus(TapDownDetails details, BoxConstraints constraints) async {
    if (_showBeautyPanel) {
      setState(() => _showBeautyPanel = false);
      return;
    }
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    final Offset tapOffset = details.localPosition;
    final double x = tapOffset.dx / constraints.maxWidth;
    final double y = tapOffset.dy / constraints.maxHeight;
    setState(() { _focusPoint = tapOffset; });
    try {
      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setExposurePoint(Offset(x, y));
    } catch (e) {
      debugPrint('Focus error: $e');
    }
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    double newZoom = (_currentZoomLevel * details.scale).clamp(1.0, _maxZoomLevel);
    _cameraController!.setZoomLevel(newZoom);
    _currentZoomLevel = newZoom;
  }

  void _showLensDetail(BuildContext context, Lens lens) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentBrandId = context.read<BrandProvider>().currentBrand.id;
    
    _detailOpenedAt = DateTime.now();

    // 상세보기 로깅
    AnalyticsService.instance.logEvent(
      actionType: 'long_press',
      lensId: lens.id,
      brandId: currentBrandId,
    );
    
    _detailOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(child: GestureDetector(onTap: () => _hideLensDetail(lens.id, currentBrandId), child: Container(color: Colors.black26))),
          Center(
            child: Material(
              color: Colors.transparent,
              child: _buildGlassBox(
                borderRadius: 30,
                opacity: 0.1,
                child: Container(
                  width: 300, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(border: Border.all(color: Colors.white12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: lens.thumbnailUrl, width: 100, height: 100, fit: BoxFit.cover)),
                      const SizedBox(height: 16),
                      Text(lens.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(lens.description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                        children: lens.tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.3))),
                          child: Text(tag.contains(':') ? '#${tag.split(':').last}' : '#$tag', style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_detailOverlay!);
    HapticFeedback.selectionClick();
  }

  void _hideLensDetail(String lensId, String? brandId) {
    _detailOverlay?.remove();
    _detailOverlay = null;

    if (_detailOpenedAt != null) {
      final duration = DateTime.now().difference(_detailOpenedAt!).inMilliseconds;
      AnalyticsService.instance.logEvent(
        actionType: 'close_detail',
        lensId: lensId,
        brandId: brandId,
        durationMs: duration,
      );
      _detailOpenedAt = null;
    }
  }

  void _handleLensToggle(LensProvider lensProvider) {
    HapticFeedback.selectionClick();
    if (lensProvider.selectedLens != null) {
      _lastSelectedLens = lensProvider.selectedLens;
      lensProvider.selectLens(null);
    } else if (_lastSelectedLens != null) {
      final currentBrandId = context.read<BrandProvider>().currentBrand.id;
      lensProvider.selectLens(_lastSelectedLens, currentBrandId: currentBrandId);
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isSaving) return;
    
    HapticFeedback.heavyImpact();
    setState(() => _isSaving = true);

    try {
      RenderRepaintBoundary boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final String fileName = "ARlens_${DateTime.now().millisecondsSinceEpoch}.png";
      await Gal.putImageBytes(pngBytes, name: fileName);
      
      final lensProvider = context.read<LensProvider>();
      final currentBrandId = context.read<BrandProvider>().currentBrand.id;
      
      // 캡처 활동 로깅
      AnalyticsService.instance.logEvent(
        actionType: 'capture',
        lensId: lensProvider.selectedLens?.id,
        brandId: currentBrandId,
      );

      if (!mounted) return;
      _showGlassSnackBar(context: context, message: "갤러리에 저장되었습니다! ✨", isError: false);
    } catch (e) {
      if (!mounted) return;
      _showGlassSnackBar(context: context, message: "저장에 실패했습니다.", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showGlassSnackBar({required BuildContext context, required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent, elevation: 0, behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 160, left: 20, right: 20), duration: const Duration(seconds: 2),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(color: (isError ? Colors.redAccent : Colors.white).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20), const SizedBox(width: 10), Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _visionService.dispose();
    _detailOverlay?.remove();
    super.dispose();
  }

  Widget _buildGlassBox({required Widget child, double borderRadius = 20, double opacity = 0.2}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: opacity), borderRadius: BorderRadius.circular(borderRadius), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
          child: child,
        ),
      ),
    );
  }

  // [화이트 테마 패널] 내부 슬라이더의 아이콘 및 텍스트 색상을 어두운 색으로 변경
  Widget _buildBeautySlider({required IconData icon, required String label, required double value, required ValueChanged<double> onChanged}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 24),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
          Expanded(
            child: Slider(
              value: value,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                onChanged(val);
              },
              activeColor: primaryColor, // 브랜드 컬러 연동
              inactiveColor: Colors.black12,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              (value * 100).toInt().toString(), 
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold, fontFeatures: [ui.FontFeature.tabularFigures()])
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentBrandId = context.watch<BrandProvider>().currentBrand.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 1. 카메라 프리뷰 및 AR 렌즈 렌더링
              RepaintBoundary(
                key: _captureKey,
                child: GestureDetector(
                  onScaleUpdate: _onScaleUpdate,
                  onTapDown: (details) => _onTapFocus(details, constraints),
                  child: Stack(
                    children: [
                      if (_isCameraInitialized && _cameraController != null)
                        SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _cameraController!.value.previewSize?.height ?? 1, height: _cameraController!.value.previewSize?.width ?? 1, child: CameraPreview(_cameraController!))))
                      else Container(color: Colors.black),
                      
                      if (_isCameraInitialized && _cameraController != null)
                        Positioned.fill(
                          child: Consumer<LensProvider>(
                            builder: (context, lensProvider, child) {
                              return ListenableBuilder(
                                listenable: _visionService,
                                builder: (context, _) {
                                  if (!_visionService.isVisionSupported) return const SizedBox.shrink();
                                  final previewSize = _cameraController!.value.previewSize!;
                                  return CustomPaint(
                                    painter: ARLensPainter(
                                      eyeData: _visionService.eyeData, 
                                      selectedLens: lensProvider.selectedLens, 
                                      lensImage: lensProvider.loadedLensImage, 
                                      imageSize: Size(previewSize.height, previewSize.width), 
                                      isFrontCamera: _cameraDescription?.lensDirection == CameraLensDirection.front,
                                      skinValue: _skinValue,
                                      eyeValue: _eyeValue,
                                      chinValue: _chinValue,
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
              ),

              // 포커스 포인트
              if (_focusPoint != null)
                Positioned(left: _focusPoint!.dx - 35, top: _focusPoint!.dy - 35, child: Container(width: 70, height: 70, decoration: BoxDecoration(border: Border.all(color: Colors.yellow, width: 2), borderRadius: BorderRadius.circular(8)))),

              // [신규] 브랜드 슬롯 & 상단 렌즈 태그 필터 바
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 브랜드 영역 슬롯
                      Consumer<BrandProvider>(
                        builder: (context, brandProvider, child) {
                          final brand = brandProvider.currentBrand;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                if (brand.logoUrl != null && brand.logoUrl!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(brand.logoUrl!, height: 32, width: 32, fit: BoxFit.cover),
                                  )
                                else
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.0,
                                        fontFamily: 'Roboto',
                                      ),
                                      children: [
                                        TextSpan(
                                          text: brand.name.length > 2 ? brand.name.substring(0, 2) : brand.name,
                                          style: TextStyle(color: primaryColor, shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))]),
                                        ),
                                        TextSpan(
                                          text: brand.name.length > 2 ? brand.name.substring(2) : '',
                                          style: const TextStyle(color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))]),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (brand.tagline != null && brand.tagline!.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      brand.tagline!,
                                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black87, blurRadius: 2)]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),

                      // 태그 필터
                      Consumer<LensProvider>(
                        builder: (context, lensProvider, child) {
                          final Set<String> allTags = {};
                          for (var lens in lensProvider.lenses) {
                            allTags.addAll(lens.tags);
                          }
                          final List<String> tags = ['All', ...allTags.toList()..sort()];

                          return Container(
                            height: 40,
                            margin: const EdgeInsets.only(top: 5),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: tags.length,
                              itemBuilder: (context, index) {
                                final tag = tags[index];
                                final displayTag = tag.contains(':') ? tag.split(':').last : tag;
                                final isSelected = _selectedTag == tag;
                                
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() { _selectedTag = tag; });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: Text(
                                      displayTag,
                                      style: TextStyle(
                                        color: isSelected ? Colors.black87 : Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 14,
                                        shadows: isSelected ? null : const [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),

              // 3. 하단 렌즈 리스트 및 촬영 버튼
              Positioned(
                bottom: 30, left: 0, right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 120,
                      child: Consumer<LensProvider>(
                        builder: (context, lensProvider, child) {
                          final filteredLenses = lensProvider.lenses.where((lens) {
                            if (_selectedTag == 'All') return true;
                            return lens.tags.contains(_selectedTag);
                          }).toList();

                          return ListView.builder(
                            scrollDirection: Axis.horizontal, 
                            padding: const EdgeInsets.symmetric(horizontal: 20), 
                            itemCount: filteredLenses.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final isNoneSelected = lensProvider.selectedLens == null;
                                return GestureDetector(
                                  onTap: () => _handleLensToggle(lensProvider),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: isNoneSelected ? 72 : 60, height: isNoneSelected ? 72 : 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(alpha: 0.1),
                                            border: Border.all(color: isNoneSelected ? Colors.white : Colors.white24, width: isNoneSelected ? 3 : 1.5),
                                          ),
                                          child: const Icon(Icons.block, color: Colors.white, size: 28),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text("None", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black)])),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              final lens = filteredLenses[index - 1];
                              final isSelected = lensProvider.selectedLens?.id == lens.id;
                              return GestureDetector(
                                onTap: () { 
                                  if (!isSelected) { 
                                    HapticFeedback.selectionClick(); 
                                    lensProvider.selectLens(lens, currentBrandId: currentBrandId); 
                                  } 
                                },
                                onLongPress: () => _showLensDetail(context, lens),
                                onLongPressEnd: (_) => _hideLensDetail(lens.id, currentBrandId),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: isSelected ? 72 : 60, height: isSelected ? 72 : 60,
                                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.white : Colors.white24, width: isSelected ? 3 : 1.5), boxShadow: isSelected ? [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)] : []),
                                        child: Opacity(opacity: isSelected ? 1.0 : 0.6, child: ClipOval(child: CachedNetworkImage(imageUrl: lens.thumbnailUrl, fit: BoxFit.cover))),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(width: 80, child: Text(lens.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black)]))),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _takePicture, 
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)), padding: const EdgeInsets.all(6), child: Container(decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle))),
                          if (_isSaving) CircularProgressIndicator(color: primaryColor), // 브랜드 컬러 적용
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. 우측 유틸리티 버튼들 (카메라 전환, 뷰티 패널 토글)
              Positioned(
                top: 140, 
                right: 20, 
                child: Column(
                  children: [
                    _buildGlassBox(
                      borderRadius: 50, 
                      child: GestureDetector(
                        onTap: _toggleCamera, 
                        child: Container(width: 50, height: 50, child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGlassBox(
                      borderRadius: 50,
                      opacity: _showBeautyPanel ? 0.8 : 0.2,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showBeautyPanel = !_showBeautyPanel);
                        },
                        child: Container(width: 50, height: 50, child: Icon(Icons.auto_fix_high, color: _showBeautyPanel ? Colors.black87 : Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. 패널 바깥 영역 탭 시 패널 닫기 (가림막 효과 연계)
              if (_showBeautyPanel)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showBeautyPanel = false);
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // 6. 완전 불투명 화이트 뷰티 패널 (Stack 최상단 배치로 렌즈 리스트를 덮음)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                bottom: _showBeautyPanel ? 0 : -350, // 완전 은폐 (Zero Peek)
                left: 0,
                right: 0,
                child: Container(
                  height: 320,
                  decoration: BoxDecoration(
                    color: Colors.white, // 화이트 솔리드
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: _showBeautyPanel ? const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: Offset(0, -5),
                      )
                    ] : const [
                      BoxShadow(color: Colors.transparent) // 그림자 완벽 제거
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Grab Handle (세련미)
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            _buildBeautySlider(icon: Icons.face_retouching_natural, label: "피부 보정", value: _skinValue, onChanged: (v) => setState(() => _skinValue = v)),
                            _buildBeautySlider(icon: Icons.remove_red_eye, label: "눈 크기", value: _eyeValue, onChanged: (v) => setState(() => _eyeValue = v)),
                            _buildBeautySlider(icon: Icons.face, label: "턱선 보정", value: _chinValue, onChanged: (v) => setState(() => _chinValue = v)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 권한 거부 알림
              if (_isPermissionDenied)
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Center(
                        child: _buildGlassBox(
                          borderRadius: 30,
                          opacity: 0.1,
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_off_outlined, color: primaryColor, size: 64),
                                const SizedBox(height: 24),
                                const Text(
                                  "AR 렌즈 체험을 위해\n카메라 권한이 필요합니다.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 32),
                                ElevatedButton(
                                  onPressed: () => openAppSettings(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  ),
                                  child: const Text("설정으로 이동", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 권한 확인 대기 중
              if (!_hasAttemptedInit && !_isPermissionDenied)
                Center(child: _buildGlassBox(borderRadius: 30, opacity: 0.1, child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.auto_awesome, color: Colors.white, size: 60), const SizedBox(height: 20), const Text('AR 필터 체험 시작', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 30), ElevatedButton(onPressed: () => _initializeCamera(), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)), child: const Text('카메라 켜기', style: TextStyle(fontWeight: FontWeight.bold)))])))),
            ],
          );
        }
      ),
    );
  }
}
