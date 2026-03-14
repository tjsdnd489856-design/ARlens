import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart'; 
import 'package:flutter/foundation.dart'; 
import '../../services/supabase_service.dart';
import '../../providers/lens_provider.dart';
import '../../models/lens_model.dart';
import '../../providers/user_provider.dart'; 
import '../../providers/connectivity_provider.dart'; 
import '../../services/audit_service.dart';
import '../../providers/brand_provider.dart';

class AdminAddLensScreen extends StatefulWidget {
  final Lens? existingLens; 
  final String? initialBrandId;

  const AdminAddLensScreen({super.key, this.existingLens, this.initialBrandId});

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
  bool _hasUploadError = false; 
  double _uploadProgress = 0.0; 
  String? _nameError, _thumbnailError, _textureError;

  String? _selectedBrandId;
  List<Map<String, dynamic>> _allBrands = [];
  bool _isLoadingBrands = false;

  late final String _requestId;

  final ImagePicker _picker = ImagePicker();
  SupabaseClient get supabase => SupabaseService.client;

  @override
  void initState() {
    super.initState();
    _requestId = const Uuid().v4();

    if (widget.existingLens != null) {
      final lens = widget.existingLens!;
      _nameController.text = lens.name;
      _descController.text = lens.description;
      _tags.addAll(lens.tags);
      _existingThumbnailUrl = lens.thumbnailUrl;
      _existingTextureUrl = lens.arTextureUrl;
      _selectedBrandId = lens.brandId;
    } else if (widget.initialBrandId != null) {
      _selectedBrandId = widget.initialBrandId;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<UserProvider>().currentProfile?.brandId == 'admin') {
        _fetchBrands();
      } else {
        _selectedBrandId = context.read<UserProvider>().currentProfile?.brandId;
      }
    });
  }

  Future<void> _fetchBrands() async {
    setState(() => _isLoadingBrands = true);
    try {
      final response = await supabase.from('brands').select('id, name');
      setState(() {
        _allBrands = List<Map<String, dynamic>>.from(response);
        if (_selectedBrandId == null && _allBrands.isNotEmpty) _selectedBrandId = _allBrands.first['id'];
      });
    } catch (e) { debugPrint('Brand Fetch Error: $e'); }
    finally { setState(() => _isLoadingBrands = false); }
  }

  Future<void> _pickImage(bool isThumbnail) async {
    final isOffline = context.read<ConnectivityProvider>().isOffline;
    if (isOffline) return; // [Hardening]

    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      final String fileName = pickedFile.name.toLowerCase();
      final String ext = fileName.split('.').last;
      
      if (!isThumbnail && ext != 'png') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AR 텍스처는 PNG 전용입니다.'), backgroundColor: Colors.orangeAccent));
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      setState(() { 
        if (isThumbnail) {
          _thumbnailFile = pickedFile; _thumbnailBytes = bytes; _existingThumbnailUrl = null;
        } else {
          _textureFile = pickedFile; _textureBytes = bytes; _existingTextureUrl = null;
        }
      });
    }
  }

  void _addTag() {
    final t = _tagInputController.text.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() { _tags.add(t); _tagInputController.clear(); });
    }
  }

  Future<void> _deployLens() async {
    final up = context.read<UserProvider>();
    if (!_validateFields()) return;
    setState(() { _isUploading = true; _hasUploadError = false; _uploadProgress = 0.1; });
    
    try {
      String thumbnailUrl = _existingThumbnailUrl ?? (widget.existingLens?.thumbnailUrl ?? '');
      String textureUrl = _existingTextureUrl ?? (widget.existingLens?.arTextureUrl ?? '');

      if (_thumbnailFile != null) thumbnailUrl = await _uploadFile(_thumbnailFile!, 'thumbnails');
      setState(() => _uploadProgress = 0.5);
      if (_textureFile != null) textureUrl = await _uploadFile(_textureFile!, 'textures');
      setState(() => _uploadProgress = 0.8);

      final String targetBrandId = _selectedBrandId ?? 'admin';
      final Map<String, dynamic> lensData = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'tags': _tags,
        'thumbnailUrl': thumbnailUrl,
        'arTextureUrl': textureUrl,
        'brandId': targetBrandId, 
        if (widget.existingLens == null) 'requestId': _requestId,
      };

      if (widget.existingLens != null) {
        final oldData = widget.existingLens!.toJson();
        await supabase.from('lenses').update(lensData).eq('id', widget.existingLens!.id);
        await AuditService.instance.logAdminAction(action: 'UPDATE_LENS', targetId: widget.existingLens!.id, adminName: up.currentProfile?.name, oldData: oldData, newData: lensData);
      } else {
        final resp = await supabase.from('lenses').insert(lensData).select().single();
        await AuditService.instance.logAdminAction(action: 'CREATE_LENS', targetId: resp['id'].toString(), adminName: up.currentProfile?.name, newData: lensData);
      }

      setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) { context.read<LensProvider>().fetchLensesFromSupabase(); context.pop(); }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 처리된 요청입니다.'), backgroundColor: Colors.orangeAccent));
        if (mounted) context.pop();
      } else { _handleError(e.message); }
    } catch (e) { _handleError(e.toString()); }
  }

  void _handleError(String error) {
    setState(() { _isUploading = true; _hasUploadError = true; _uploadProgress = 1.0; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('배포 실패: $error'), backgroundColor: Colors.redAccent));
  }

  Future<String> _uploadFile(XFile file, String folder) async {
    final String path = "$folder/${const Uuid().v4()}.${file.name.split('.').last}";
    final bytes = await file.readAsBytes();
    await supabase.storage.from('lens-assets').uploadBinary(path, bytes);
    return supabase.storage.from('lens-assets').getPublicUrl(path);
  }

  bool _validateFields() {
    bool isValid = true;
    setState(() {
      if (_nameController.text.trim().isEmpty) { _nameError = '이름 필수'; isValid = false; } else _nameError = null;
      if (_thumbnailFile == null && (_existingThumbnailUrl == null || _existingThumbnailUrl!.isEmpty)) { _thumbnailError = '이미지 필수'; isValid = false; } else _thumbnailError = null;
    });
    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isSuperAdmin = userProvider.currentProfile?.brandId == 'admin';
    final currentBrand = context.watch<BrandProvider>().currentBrand;
    final bool isOffline = context.watch<ConnectivityProvider>().isOffline;

    final bool isSimulating = isSuperAdmin && widget.initialBrandId != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.existingLens != null ? '렌즈 수정' : '렌즈 등록')),
      body: Column(
        children: [
          if (isSimulating)
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), color: Colors.deepPurple, child: Center(child: Text('현재 [${currentBrand.name}] 모드 시뮬레이션 중', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (isSuperAdmin) ...[
                    const Text('배정 브랜드', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _selectedBrandId, isExpanded: true,
                      // [Hardening] 오프라인 시 드롭다운 비활성화
                      onChanged: isOffline ? null : (v) => setState(() => _selectedBrandId = v),
                      items: _allBrands.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String))).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextField(controller: _nameController, readOnly: isOffline, decoration: InputDecoration(labelText: '렌즈명', errorText: _nameError, hintText: isOffline ? '네트워크가 필요합니다' : null)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCircularPicker('썸네일', _thumbnailBytes, _existingThumbnailUrl, isOffline),
                      _buildCircularPicker('AR 텍스처', _textureBytes, _existingTextureUrl, isOffline),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    children: _tags.map((t) => Chip(
                      label: Text(t),
                      // [Hardening] 오프라인 시 태그 삭제 비활성화
                      onDeleted: isOffline ? null : () => setState(() => _tags.remove(t)),
                    )).toList(),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(onPressed: (isOffline || _isUploading) ? null : _deployLens, child: Text(_isUploading ? '배포 중...' : '저장')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularPicker(String label, Uint8List? bytes, String? url, bool isOffline) {
    return Column(
      children: [
        Text(label),
        const SizedBox(height: 8),
        InkWell(
          // [Hardening] 오프라인 시 클릭 차단
          onTap: isOffline ? null : () => _pickImage(label.contains('썸네일')),
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200], border: Border.all(color: isOffline ? Colors.grey : Colors.pinkAccent)),
            child: bytes != null ? ClipOval(child: Image.memory(bytes, fit: BoxFit.cover)) : (url != null ? ClipOval(child: Image.network(url, fit: BoxFit.cover)) : const Icon(Icons.add_a_photo)),
          ),
        ),
      ],
    );
  }
}
