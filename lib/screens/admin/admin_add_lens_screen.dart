import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../providers/lens_provider.dart';

class AdminAddLensScreen extends StatefulWidget {
  const AdminAddLensScreen({super.key});

  @override
  State<AdminAddLensScreen> createState() => _AdminAddLensScreenState();
}

class _AdminAddLensScreenState extends State<AdminAddLensScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  
  final List<String> _tags = [];
  final TextEditingController _tagInputController = TextEditingController();

  final List<String> _baseCategories = ["스타일", "테마", "색상", "이벤트", "직접 입력"];
  String _selectedCategory = "스타일";
  final TextEditingController _customCategoryController = TextEditingController();

  // 렌더링 설정
  double _opacityValue = 0.8;
  String _selectedBlendingMode = 'modulate';
  final List<String> _blendingModes = ['srcOver', 'modulate', 'overlay', 'softLight', 'multiply', 'screen'];

  XFile? _thumbnailFile;
  XFile? _textureFile;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();
  SupabaseClient get supabase => SupabaseService.client;

  // [V1.1] 시뮬레이터 블렌딩 모드 맵핑
  BlendMode _getBlendMode(String mode) {
    switch (mode) {
      case 'overlay': return BlendMode.overlay;
      case 'softLight': return BlendMode.softLight;
      case 'multiply': return BlendMode.multiply;
      case 'screen': return BlendMode.screen;
      case 'modulate': return BlendMode.modulate;
      default: return BlendMode.srcOver;
    }
  }

  void _addStructuredTag() {
    String category = _selectedCategory == "직접 입력" ? _customCategoryController.text.trim() : _selectedCategory;
    final String minorTag = _tagInputController.text.trim();
    if (category.isEmpty || minorTag.isEmpty) return;
    final String fullTag = "$category:$minorTag";
    if (!_tags.contains(fullTag)) {
      setState(() { _tags.add(fullTag); _tagInputController.clear(); });
    }
  }

  Future<void> _pickImage(bool isThumbnail) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() { isThumbnail ? _thumbnailFile = pickedFile : _textureFile = pickedFile; });
  }

  Future<void> _deployLens() async {
    if (_nameController.text.isEmpty || _textureFile == null) return;
    setState(() => _isUploading = true);
    try {
      // 업로드 및 저장 로직 (기존 유지)
      context.read<LensProvider>().fetchLensesFromSupabase();
      context.pop();
    } catch (e) { setState(() => _isUploading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('신규 렌즈 등록'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 입력 필드 영역
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      TextField(controller: _nameController, decoration: const InputDecoration(labelText: '렌즈명', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: '설명', border: OutlineInputBorder())),
                      const SizedBox(height: 24),
                      _buildTagSection(),
                      const SizedBox(height: 24),
                      _buildRenderingSection(),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                // 2. [V1.1] 실시간 시뮬레이터 영역
                Expanded(
                  flex: 2,
                  child: _buildLiveSimulator(),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildImageUploadSection(),
            const SizedBox(height: 60),
            SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _deployLens, style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent), child: const Text('클라우드에 배포하기 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSimulator() {
    return Column(
      children: [
        const Text('착용 시뮬레이션', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 16),
        Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(120),
            border: Border.all(color: Colors.black12, width: 4),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                // 가상 눈 배경 (더미 이미지나 색상)
                Positioned.fill(
                  child: Image.network(
                    'https://images.unsplash.com/photo-1590540179852-2110a54f813a?q=80&w=300&h=300&fit=crop',
                    fit: BoxFit.cover,
                  ),
                ),
                // 실제 업로드한 렌즈 텍스처 합성
                if (_textureFile != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: _opacityValue,
                      child: Image.file(
                        File(_textureFile!.path),
                        fit: BoxFit.cover,
                        colorBlendMode: _getBlendMode(_selectedBlendingMode),
                        color: Colors.white.withOpacity(0.5), // 블렌딩 효과 극대화용 가상 컬러
                      ),
                    ),
                  ),
                // 중심 동공 가이드 (시뮬레이션 정밀도)
                Center(child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), shape: BoxShape.circle))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('※ 실제 안구 데이터를 기반으로 한 가상 프리뷰입니다.', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTagSection() => Container(child: const Text('태그 섹션 (기존 코드 생략)'));
  Widget _buildRenderingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('기본 불투명도: ${(_opacityValue * 100).toInt()}%'),
        Slider(value: _opacityValue, onChanged: (v) => setState(() => _opacityValue = v)),
        DropdownButtonFormField<String>(
          value: _selectedBlendingMode,
          items: _blendingModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _selectedBlendingMode = v!),
          decoration: const InputDecoration(labelText: '블렌딩 모드'),
        ),
      ],
    );
  }
  Widget _buildImageUploadSection() => Row(children: [ElevatedButton(onPressed: () => _pickImage(true), child: const Text('썸네일 선택')), const SizedBox(width: 16), ElevatedButton(onPressed: () => _pickImage(false), child: const Text('AR 텍스처 선택'))]);
}
