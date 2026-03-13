import 'dart:typed_data';
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

  // [추가] 지능형 분류 시스템을 위한 상태
  final List<String> _baseCategories = ["스타일", "테마", "색상", "이벤트", "직접 입력"];
  String _selectedCategory = "스타일";
  final TextEditingController _customCategoryController = TextEditingController();

  XFile? _thumbnailFile;
  XFile? _textureFile;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  SupabaseClient get supabase => SupabaseService.client;

  // 카테고리별 컬러 매핑 함수
  Color _getCategoryColor(String fullTag) {
    final String category = fullTag.split(':').first;
    switch (category) {
      case "스타일": return Colors.blue;
      case "테마": return Colors.green;
      case "색상": return Colors.red;
      case "이벤트": return Colors.orange;
      default: return Colors.deepPurple;
    }
  }

  // 지능형 태그 추가 함수
  void _addStructuredTag() {
    String category = _selectedCategory == "직접 입력" 
        ? _customCategoryController.text.trim() 
        : _selectedCategory;
    
    final String minorTag = _tagInputController.text.trim();

    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('카테고리명을 입력해주세요.')));
      return;
    }
    if (minorTag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('소분류 태그를 입력해주세요.')));
      return;
    }

    final String fullTag = "$category:$minorTag";

    if (!_tags.contains(fullTag)) {
      setState(() {
        _tags.add(fullTag);
        _tagInputController.clear();
      });
    } else {
      _tagInputController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 등록된 태그입니다.')));
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _pickImage(bool isThumbnail) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        if (isThumbnail) {
          _thumbnailFile = pickedFile;
        } else {
          _textureFile = pickedFile;
        }
      });
    }
  }

  Future<String> _uploadFileToStorage(XFile file, String folderPath) async {
    try {
      Uint8List fileBytes = await file.readAsBytes();
      final String extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'png';
      final String safeName =
          '${DateTime.now().millisecondsSinceEpoch}_${folderPath}_asset.$extension';
      final String fullPath = '$folderPath/$safeName';

      await supabase.storage
          .from('lens-assets'.trim())
          .uploadBinary(
            fullPath,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return supabase.storage
          .from('lens-assets'.trim())
          .getPublicUrl(fullPath);
    } catch (e) {
      debugPrint('❌ [Storage] 업로드 에러: $e');
      rethrow;
    }
  }

  Future<void> _deployLens() async {
    if (_nameController.text.isEmpty ||
        _descController.text.isEmpty ||
        _thumbnailFile == null ||
        _textureFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목과 이미지를 등록해주세요!'))
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String thumbnailUrl = await _uploadFileToStorage(_thumbnailFile!, 'thumbnails');
      String textureUrl = await _uploadFileToStorage(_textureFile!, 'textures');

      await supabase.from('lenses').insert({
        'name': _nameController.text,
        'description': _descController.text,
        'tags': _tags,
        'thumbnailUrl': thumbnailUrl,
        'arTextureUrl': textureUrl,
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        context.read<LensProvider>().fetchLensesFromSupabase();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 새 렌즈가 성공적으로 배포되었습니다!'),
            backgroundColor: Colors.pinkAccent,
          ),
        );
        // [수정] 고정된 경로 대신 pop()을 사용하여 자연스럽게 이전 화면으로 돌아감
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/admin');
        }
      }
    } catch (e) {
      debugPrint('배포 중 에러 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('배포 실패: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _tagInputController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('신규 렌즈 등록', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // [수정] 고정된 경로 대신 pop()을 사용하여 자연스럽게 이전 화면으로 돌아감
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '렌즈 기본 정보',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '렌즈명 (예: 체리밤 핑크)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF8F9FA),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '렌즈 설명 (사용자에게 보일 문구)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF8F9FA),
                  ),
                ),
                const SizedBox(height: 24),
                
                // [개편] 지능형 분류 태그 시스템 UI
                const Text(
                  '지능형 분류 태그 설정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // 1. 대분류 드롭다운
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: '대분류',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _baseCategories.map((cat) {
                                return DropdownMenuItem(value: cat, child: Text(cat));
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedCategory = val!);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 2. 직접 입력 시 나타나는 텍스트 필드
                          if (_selectedCategory == "직접 입력")
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _customCategoryController,
                                decoration: const InputDecoration(
                                  labelText: '새 카테고리',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // 3. 소분류 태그 입력
                          Expanded(
                            child: TextField(
                              controller: _tagInputController,
                              onSubmitted: (_) => _addStructuredTag(),
                              decoration: const InputDecoration(
                                labelText: '소분류 태그 입력 (예: Y2K, 블루)',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 4. 추가 버튼
                          ElevatedButton(
                            onPressed: _addStructuredTag,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('추가', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // [개편] 컬러별 그룹화된 태그 칩 표시
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _tags.map((tag) {
                      final chipColor = _getCategoryColor(tag);
                      return InputChip(
                        label: Text(tag),
                        onDeleted: () => _removeTag(tag),
                        deleteIconColor: Colors.white,
                        backgroundColor: chipColor,
                        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide.none,
                        ),
                      );
                    }).toList(),
                  ),
                
                const SizedBox(height: 40),
                const Text(
                  '이미지 에셋 업로드',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildImagePickerCard(
                        onPressed: () => _pickImage(true),
                        icon: Icons.image,
                        label: '썸네일 선택',
                        fileName: _thumbnailFile?.name,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImagePickerCard(
                        onPressed: () => _pickImage(false),
                        icon: Icons.face_retouching_natural,
                        label: 'AR 텍스처 선택',
                        fileName: _textureFile?.name,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _deployLens,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '클라우드에 배포하기 🚀',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isUploading)
            _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildImagePickerCard({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    String? fileName,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.pinkAccent, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              fileName ?? '선택된 파일 없음',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.pinkAccent),
            const SizedBox(height: 16),
            Text(
              '클라우드에 배포 중입니다...\n창을 닫지 마세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
