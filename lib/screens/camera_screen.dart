import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart'; 
import 'package:share_plus/share_plus.dart'; 
import 'package:image/image.dart' as img; 
import 'package:http/http.dart' as http; 
import 'package:path_provider/path_provider.dart'; 
import 'package:flutter/foundation.dart'; 
import '../providers/lens_provider.dart';
import '../providers/brand_provider.dart';
import '../providers/user_provider.dart';
import '../services/vision_service.dart';
import '../services/analytics_service.dart';
import '../widgets/ar_lens_painter.dart';
import '../models/lens_model.dart';

Future<Uint8List> _applyWatermarkIsolate(Map<String, dynamic> params) async {
  try {
    final Uint8List imageBytes = params['imageBytes'];
    final Uint8List? logoBytes = params['logoBytes'];

    img.Image? baseImage = img.decodeImage(imageBytes);
    if (baseImage == null) return imageBytes;

    if (logoBytes != null) {
      img.Image? watermark = img.decodeImage(logoBytes);
      if (watermark != null) {
        int wWidth = (baseImage.width * 0.15).toInt();
        watermark = img.copyResize(watermark, width: wWidth);
        int x = baseImage.width - watermark.width - 40;
        int y = baseImage.height - watermark.height - 40;
        img.compositeImage(baseImage, watermark, dstX: x, dstY: y);
      }
    }
    return Uint8List.fromList(img.encodePng(baseImage));
  } catch (e) {
    debugPrint('⚠️ 워터마크 합성 실패 (Isolate): $e');
    return params['imageBytes']; 
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  final VisionService _visionService = VisionService();
  bool _isCameraInitialized = false;
  bool _hasAttemptedInit = false;
  bool _isPermissionDenied = false;
  bool _isSaving = false;
  CameraDescription? _cameraDescription;
  
  bool _showFlash = false;

  Uint8List? _lastCapturedImage;
  String? _tempSavedPath; 
  bool _showThumbnail = false;
  Timer? _thumbnailTimer;

  String _selectedTag = 'For You';
  final ScrollController _lensScrollController = ScrollController();

  double _currentZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  Offset? _focusPoint;
  Timer? _focusTimer;

  double _skinValue = 0.5;
  double _eyeValue = 0.5;
  double _chinValue = 0.5;
  bool _showBeautyPanel = false;
  Lens? _lastSelectedLens;

  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _checkInitialPermissions();
    _lensScrollController.addListener(_onLensScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController?.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      _isCameraInitialized = false;
      _initializeCamera(description: _cameraDescription);
    }
  }

  void _onLensScroll() {
    if (_lensScrollController.position.pixels >= _lensScrollController.position.maxScrollExtent - 200) {
      context.read<LensProvider>().loadMoreLenses();
    }
  }

  Future<void> _checkInitialPermissions() async {
    final status = await Permission.camera.status;
    if (status.isGranted) { _initializeCamera(); }
  }

  Future<void> _toggleCamera() async {
    HapticFeedback.selectionClick();
    final cameras = await availableCameras();
    if (cameras.length < 2) return;
    final newDirection = _cameraDescription?.lensDirection == CameraLensDirection.front ? CameraLensDirection.back : CameraLensDirection.front;
    final newCamera = cameras.firstWhere((c) => c.lensDirection == newDirection, orElse: () => cameras.first);
    _initializeCamera(description: newCamera);
  }

  Future<void> _initializeCamera({CameraDescription? description}) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) { setState(() { _isPermissionDenied = true; _hasAttemptedInit = true; }); return; }
    setState(() { _hasAttemptedInit = true; _isCameraInitialized = false; _isPermissionDenied = false; });
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
    } catch (e) { if (mounted) setState(() { _isCameraInitialized = true; _cameraController = null; }); }
  }

  Future<void> _onTapFocus(TapDownDetails details, BoxConstraints constraints) async {
    if (_showBeautyPanel) { setState(() => _showBeautyPanel = false); return; }
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    final Offset tapOffset = details.localPosition;
    final double x = tapOffset.dx / constraints.maxWidth;
    final double y = tapOffset.dy / constraints.maxHeight;
    setState(() { _focusPoint = tapOffset; });
    try {
      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setExposurePoint(Offset(x, y));
    } catch (e) { debugPrint('Focus error: $e'); }
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(seconds: 2), () { if (mounted) setState(() => _focusPoint = null); });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    double newZoom = (_currentZoomLevel * details.scale).clamp(1.0, _maxZoomLevel);
    _cameraController!.setZoomLevel(newZoom);
    _currentZoomLevel = newZoom;
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
    
    HapticFeedback.lightImpact();
    setState(() { _showFlash = true; _isSaving = true; });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showFlash = false);
    });

    try {
      RenderRepaintBoundary boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image capturedUiImage = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await capturedUiImage.toByteData(format: ui.ImageByteFormat.png);
      Uint8List originalBytes = byteData!.buffer.asUint8List();

      final brandProvider = context.read<BrandProvider>();
      
      Uint8List finalBytes = await compute(_applyWatermarkIsolate, {
        'imageBytes': originalBytes,
        'logoBytes': brandProvider.cachedLogoBytes,
      });

      final String fileName = "ARlens_${DateTime.now().millisecondsSinceEpoch}.png";
      await Gal.putImageBytes(finalBytes, name: fileName);
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = await File('${tempDir.path}/$fileName').create();
      await tempFile.writeAsBytes(finalBytes);

      setState(() {
        _lastCapturedImage = finalBytes;
        _tempSavedPath = tempFile.path;
        _showThumbnail = true;
      });

      _thumbnailTimer?.cancel();
      _thumbnailTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showThumbnail = false);
      });

      AnalyticsService.instance.logEvent(
        actionType: 'capture',
        lensId: context.read<LensProvider>().selectedLens?.id,
        brandId: brandProvider.currentBrand.id,
      );

      if (!mounted) return;
      _showGlassSnackBar(context: context, message: "저장되었습니다! ✨", isError: false);
    } catch (e) {
      if (mounted) _showGlassSnackBar(context: context, message: "저장에 실패했습니다.", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _shareCapturedImage() async {
    if (_lastCapturedImage == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/shared_arlens.png').create();
      await file.writeAsBytes(_lastCapturedImage!);
      await Share.shareXFiles([XFile(file.path)], text: 'ARlens로 찍은 정교한 렌즈 체험샷! ✨');
    } catch (e) {
      debugPrint('❌ 공유 실패: $e');
    }
  }

  void _deleteCapturedImage() async {
    if (_tempSavedPath == null) return;
    try {
      final file = File(_tempSavedPath!);
      if (await file.exists()) await file.delete();
      setState(() {
        _lastCapturedImage = null;
        _showThumbnail = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
    } catch (e) {
      debugPrint('❌ 삭제 실패: $e');
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
    WidgetsBinding.instance.removeObserver(this); 
    _focusTimer?.cancel();
    _thumbnailTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _visionService.dispose();
    _lensScrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentBrandId = context.watch<BrandProvider>().currentBrand.id;
    final userProfile = context.watch<UserProvider>().currentProfile;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
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
                                      skinValue: _skinValue, eyeValue: _eyeValue, chinValue: _chinValue,
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

              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showFlash ? 0.8 : 0.0,
                  duration: const Duration(milliseconds: 50),
                  child: Container(color: Colors.white),
                ),
              ),

              if (_focusPoint != null)
                Positioned(left: _focusPoint!.dx - 35, top: _focusPoint!.dy - 35, child: Container(width: 70, height: 70, decoration: BoxDecoration(border: Border.all(color: Colors.yellow, width: 2), borderRadius: BorderRadius.circular(8)))),

              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<BrandProvider>(
                        builder: (context, brandProvider, child) {
                          final brand = brandProvider.currentBrand;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                if (brand.logoUrl != null && brand.logoUrl!.isNotEmpty)
                                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(brand.logoUrl!, height: 32, width: 32, fit: BoxFit.cover))
                                else
                                  RichText(text: TextSpan(style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Roboto'), children: [TextSpan(text: brand.name.length > 2 ? brand.name.substring(0, 2) : brand.name, style: TextStyle(color: primaryColor, shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))])), TextSpan(text: brand.name.length > 2 ? brand.name.substring(2) : '', style: const TextStyle(color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))]))])),
                                if (brand.tagline != null && brand.tagline!.isNotEmpty) ...[const SizedBox(width: 12), Expanded(child: Text(brand.tagline!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black87, blurRadius: 2)]), maxLines: 1, overflow: TextOverflow.ellipsis))],
                              ],
                            ),
                          );
                        },
                      ),

                      Consumer<LensProvider>(
                        builder: (context, lensProvider, child) {
                          final Set<String> allTags = {};
                          for (var lens in lensProvider.lenses) {
                            allTags.addAll(lens.tags);
                          }
                          final List<String> tags = ['For You', 'All', ...allTags.toList()..sort()];

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

              if (_showThumbnail && _lastCapturedImage != null)
                Positioned(
                  bottom: 160, left: 24,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(_lastCapturedImage!)),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildDialogButton(Icons.share, '공유하기', Colors.white, _shareCapturedImage),
                                  const SizedBox(width: 16),
                                  _buildDialogButton(Icons.delete_forever, '삭제하기', Colors.redAccent, _deleteCapturedImage),
                                ],
                              ),
                              const SizedBox(height: 20),
                              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white, size: 32)),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'captured_image',
                      child: Container(
                        width: 70, height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_lastCapturedImage!, fit: BoxFit.cover)),
                      ),
                    ),
                  ),
                ),

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
                            if (_selectedTag == 'For You') {
                               if (userProfile?.preferredStyle == null) return true; 
                               return lens.tags.any((tag) => tag.toLowerCase().contains(userProfile!.preferredStyle!.toLowerCase()));
                            }
                            return lens.tags.contains(_selectedTag);
                          }).toList();

                          return ListView.builder(
                            controller: _lensScrollController, scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), 
                            itemCount: filteredLenses.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final isNoneSelected = lensProvider.selectedLens == null;
                                return GestureDetector(
                                  onTap: () => _handleLensToggle(lensProvider),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [AnimatedContainer(duration: const Duration(milliseconds: 200), width: isNoneSelected ? 72 : 60, height: isNoneSelected ? 72 : 60, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1), border: Border.all(color: isNoneSelected ? Colors.white : Colors.white24, width: isNoneSelected ? 3 : 1.5)), child: const Icon(Icons.block, color: Colors.white, size: 28)), const SizedBox(height: 8), const Text("None", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black)]))]),
                                  ),
                                );
                              }
                              final lens = filteredLenses[index - 1];
                              final isSelected = lensProvider.selectedLens?.id == lens.id;
                              return GestureDetector(
                                onTap: () { if (!isSelected) { HapticFeedback.selectionClick(); lensProvider.selectLens(lens, currentBrandId: currentBrandId); } },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [AnimatedContainer(duration: const Duration(milliseconds: 200), width: isSelected ? 72 : 60, height: isSelected ? 72 : 60, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.white : Colors.white24, width: isSelected ? 3 : 1.5), boxShadow: isSelected ? [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)] : []), child: Opacity(opacity: isSelected ? 1.0 : 0.6, child: ClipOval(child: CachedNetworkImage(imageUrl: lensProvider.getOptimizedThumbnail(lens.thumbnailUrl), fit: BoxFit.cover)))), const SizedBox(height: 8), SizedBox(width: 80, child: Text(lens.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black)])))]),
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
                          if (_isSaving) CircularProgressIndicator(color: primaryColor), 
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 140, right: 20, 
                child: Column(
                  children: [
                    _buildGlassBox(borderRadius: 50, child: GestureDetector(onTap: _toggleCamera, child: Container(width: 50, height: 50, child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white)))),
                    const SizedBox(height: 16),
                    _buildGlassBox(borderRadius: 50, opacity: 1.0, child: GestureDetector(onTap: () { HapticFeedback.selectionClick(); context.push('/map'); }, child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.location_on, color: primaryColor)))),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildDialogButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}
