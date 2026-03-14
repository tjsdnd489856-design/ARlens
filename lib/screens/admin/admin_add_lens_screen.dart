import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart'; // [신규] UUID 임포트 (기존에 pubspec에 있을 것으로 가정)
import '../../services/supabase_service.dart';
import '../../providers/lens_provider.dart';
import '../../models/lens_model.dart';

class AdminAddLensScreen extends StatefulWidget {
  final Lens? existingLens; 
  const AdminAddLensScreen({super.key, this.existingLens});

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

  XFile? _thumbnailFile;
  Uint8List? _thumbnailBytes;
  String? _existingThumbnailUrl;

  XFile? _textureFile;
  Uint8List? _textureBytes;
  String? _existingTextureUrl;

  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  SupabaseClient get supabase => SupabaseService.client;

  @override
  void initState() {
    super.initState();
    if (widget.existingLens != null) {
      final lens = widget.existingLens!;
      _nameController.text = lens.name;
      _descController.text = lens.description;
      _tags.addAll(lens.tags);
      _existingThumbnailUrl = lens.thumbnailUrl;
      _existingTextureUrl = lens.arTextureUrl;
    }
  }

  void _addStructuredTag() {
    String category = _selectedCategory == "직접 입력" ? "기타" : _selectedCategory;
    final String minorTag = _tagInputController.text.trim();
    if (category.isEmpty || minorTag.isEmpty) return;
    final String fullTag = "$category:$minorTag";
    if (!_tags.contains(fullTag)) {
      setState(() { _tags.add(fullTag); _tagInputController.clear(); });
    }
  }

  Future<void> _pickImage(bool isThumbnail) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() { 
        if (isThumbnail) {
          _thumbnailFile = pickedFile;
          _thumbnailBytes = bytes;
          _existingThumbnailUrl = null;
        } else {
          _textureFile = pickedFile;
          _textureBytes = bytes;
          _existingTextureUrl = null;
        }
      });
    }
  }

  Future<void> _deleteStorageFileFromUrl(String url) async {
    if (url.isEmpty || !url.contains('lens-assets/')) return;
    try {
      final String path = url.split('lens-assets/').last;
      await supabase.storage.from('lens-assets').remove([path]);
      debugPrint('🗑️ [Storage] 파일 삭제 완료: $path');
    } catch (e) {
      debugPrint('⚠️ [Storage] 삭제 실패: $e');
    }
  }

  // [Phase 3] 파일 업로드 함수 (Storage)
  Future<String> _uploadFile(XFile file, String folder) async {
    final String extension = file.path.split('.').last;
    final String fileName = "${const Uuid().v4()}.$extension";
    final String path = "$folder/$fileName";
    
    final bytes = await file.readAsBytes();
    await supabase.storage.from('lens-assets').uploadBinary(path, bytes);
    return supabase.storage.from('lens-assets').getPublicUrl(path);
  }

  Future<void> _deleteLens() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('렌즈 삭제', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 24)),
        content: const Text('이 렌즈와 등록된 모든 이미지 파일을 영구 삭제하시겠습니까?', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소', style: TextStyle(fontSize: 18))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.redAccent, fontSize: 18))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isUploading = true);
      try {
        final lens = widget.existingLens!;
        await _deleteStorageFileFromUrl(lens.thumbnailUrl);
        await _deleteStorageFileFromUrl(lens.arTextureUrl);
        await supabase.from('lenses').delete().eq('id', lens.id);
        
        if (mounted) {
          context.read<LensProvider>().fetchLensesFromSupabase();
          context.pop();
        }
      } catch (e) {
        setState(() => _isUploading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  Future<void> _deployLens() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isUploading = true);
    
    try {
      String thumbnailUrl = _existingThumbnailUrl ?? (widget.existingLens?.thumbnailUrl ?? '');
      String textureUrl = _existingTextureUrl ?? (widget.existingLens?.arTextureUrl ?? '');

      // 1. [Final Polish] 수정 시 파일이 변경되었다면 이전 파일 삭제
      if (_thumbnailFile != null && widget.existingLens != null) {
        await _deleteStorageFileFromUrl(widget.existingLens!.thumbnailUrl);
        thumbnailUrl = await _uploadFile(_thumbnailFile!, 'thumbnails');
      } else if (_thumbnailFile != null) {
        thumbnailUrl = await _uploadFile(_thumbnailFile!, 'thumbnails');
      }

      if (_textureFile != null && widget.existingLens != null) {
        await _deleteStorageFileFromUrl(widget.existingLens!.arTextureUrl);
        textureUrl = await _uploadFile(_textureFile!, 'textures');
      } else if (_textureFile != null) {
        textureUrl = await _uploadFile(_textureFile!, 'textures');
      }

      final Map<String, dynamic> lensData = {
        'name': _nameController.text,
        'description': _descController.text,
        'tags': _tags,
        'thumbnailUrl': thumbnailUrl,
        'arTextureUrl': textureUrl,
        'brandId': widget.existingLens?.brandId ?? 'admin', // 실제 운영 시 UserProvider 브랜드 ID 사용
      };

      if (widget.existingLens != null) {
        await supabase.from('lenses').update(lensData).eq('id', widget.existingLens!.id);
      } else {
        await supabase.from('lenses').insert(lensData);
      }

      if (mounted) {
        context.read<LensProvider>().fetchLensesFromSupabase();
        context.pop();
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('배포 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.existingLens != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditMode ? '렌즈 수정' : '신규 렌즈 등록', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 27)), 
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        toolbarHeight: 75, 
      ),
      body: Container( 
        padding: const EdgeInsets.symmetric(horizontal: 60.0, vertical: 30.0), 
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(_nameController, '렌즈명', hint: '브랜드 및 제품명 입력'),
                        const SizedBox(height: 24), 
                        _buildTextField(_descController, '설명', maxLines: 2, hint: '제품 특징 설명'), 
                        const SizedBox(height: 30), 
                        _buildTagSection(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 90), 
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('리소스 미리보기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 21)), 
                        const SizedBox(height: 24), 
                        Row(
                          children: [
                            _buildCircularPreviewWithAction('썸네일', _thumbnailBytes, _existingThumbnailUrl, Icons.image, () => _pickImage(true)),
                            const SizedBox(width: 48), 
                            _buildCircularPreviewWithAction('AR 텍스처', _textureBytes, _existingTextureUrl, Icons.texture, () => _pickImage(false)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 48), 
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isEditMode)
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : _deleteLens,
                    icon: const Icon(Icons.delete_outline, size: 27), 
                    label: const Text('렌즈 삭제', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 21)), 
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                
                SizedBox(
                  width: 420, 
                  height: 78, 
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _deployLens,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isUploading 
                      ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text(isEditMode ? '변경사항 저장' : '클라우드 배포', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)), 
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, String? hint}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.black87, fontSize: 21), 
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 18), 
        hintStyle: const TextStyle(fontSize: 18),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18), 
        isDense: true,
      ),
    );
  }

  Widget _buildCircularPreviewWithAction(String label, Uint8List? bytes, String? url, IconData icon, VoidCallback onAction) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)), 
          const SizedBox(height: 18), 
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(150),
            child: Container(
              width: 240, 
              height: 240, 
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[50],
                border: Border.all(color: Colors.black.withOpacity(0.08), width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, spreadRadius: 3)
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: bytes != null
                        ? ClipOval(child: Image.memory(bytes, fit: BoxFit.cover))
                        : (url != null && url.isNotEmpty)
                            ? ClipOval(child: Image.network(url, fit: BoxFit.cover))
                            : Center(child: Icon(icon, color: Colors.black12, size: 72)), 
                  ),
                  Positioned(
                    bottom: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(9), 
                      decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Colors.white, size: 21), 
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('클릭하여 파일 변경', style: TextStyle(fontSize: 16, color: Colors.black38)), 
        ],
      ),
    );
  }

  Widget _buildTagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('카테고리 및 태그', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 21)), 
        const SizedBox(height: 18), 
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black87, fontSize: 19), 
                items: _baseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _tagInputController,
                style: const TextStyle(color: Colors.black87, fontSize: 19),
                decoration: const InputDecoration(
                  hintText: '태그 입력', 
                  border: OutlineInputBorder(), 
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _addStructuredTag, 
              icon: const Icon(Icons.add_box, color: Colors.pinkAccent, size: 54), 
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _tags.map((tag) => Chip(
            label: Text(tag, style: const TextStyle(fontSize: 16)), 
            backgroundColor: Colors.white,
            labelStyle: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold), 
            side: const BorderSide(color: Colors.pinkAccent, width: 1.5), 
            onDeleted: () => setState(() => _tags.remove(tag)),
            deleteIcon: const Icon(Icons.cancel, size: 21, color: Colors.pinkAccent), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            visualDensity: VisualDensity.standard,
          )).toList(),
        ),
      ],
    );
  }
}
