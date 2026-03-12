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
  // 사용자가 입력한 글자를 가져오기 위한 컨트롤러들
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  // 선택된 이미지 파일을 임시로 담아둘 변수
  XFile? _thumbnailFile;
  XFile? _textureFile;

  // 로딩 스피너(오버레이)를 띄우기 위한 상태값
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  SupabaseClient get supabase => SupabaseService.client;

  // 컴퓨터(또는 폰)에서 이미지를 선택하는 함수
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

  // 스토리지에 이미지를 올리고, 웹 주소(URL)를 받아오는 핵심 함수
  Future<String> _uploadFileToStorage(XFile file, String folderPath) async {
    try {
      Uint8List fileBytes = await file.readAsBytes();

      // 파일명을 안전하게 정제 (한글, 특수문자 제거하여 인코딩 에러 방지)
      final String extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'png';
      final String safeName =
          '${DateTime.now().millisecondsSinceEpoch}_${folderPath}_asset.$extension';
      final String fullPath = '$folderPath/$safeName';

      debugPrint('🚀 [Storage] 업로드 시도: $fullPath (Bucket: lens-assets)');

      // 바구니 이름(lens-assets)을 정확히 참조하고 .trim()으로 공백 제거
      await supabase.storage
          .from('lens-assets'.trim())
          .uploadBinary(
            fullPath,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String publicUrl = supabase.storage
          .from('lens-assets'.trim())
          .getPublicUrl(fullPath);

      debugPrint('✅ [Storage] 업로드 성공: $publicUrl');
      return publicUrl;
    } catch (e) {
      // 에러 객체의 상세 내용을 터미널에 상세히 출력
      debugPrint('❌ [Storage] 업로드 중 에러 발생 상세 내역:');
      debugPrint('   - 전체 에러 내용: $e');
      if (e is StorageException) {
        debugPrint('   - 상세 메시지: ${e.message}');
        debugPrint('   - 에러 코드: ${e.error}');
        debugPrint('   - HTTP 상태 코드: ${e.statusCode}');
      }
      rethrow;
    }
  }

  // 폼(Form)에 입력된 정보와 이미지들을 하나로 묶어 클라우드에 최종 배포하는 함수
  Future<void> _deployLens() async {
    // 필수 항목을 다 채웠는지 검사합니다.
    if (_nameController.text.isEmpty ||
        _descController.text.isEmpty ||
        _thumbnailFile == null ||
        _textureFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 항목과 이미지를 등록해주세요!')));
      return;
    }

    // 중복 클릭을 막기 위해 로딩 화면을 켭니다.
    setState(() {
      _isUploading = true;
    });

    try {
      // 1. 선택된 두 개의 이미지를 각각 스토리지에 업로드하고 URL을 받습니다.
      String thumbnailUrl = await _uploadFileToStorage(
        _thumbnailFile!,
        'thumbnails',
      );
      String textureUrl = await _uploadFileToStorage(_textureFile!, 'textures');

      // 2. 태그(쉼표 구분)를 리스트 형태로 예쁘게 잘라냅니다.
      List<String> tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // 3. Supabase 데이터베이스의 'lenses' 테이블에 새 데이터를 만들어 저장합니다.
      await supabase.from('lenses').insert({
        'name': _nameController.text,
        'description': _descController.text,
        'tags': tags,
        'thumbnailUrl': thumbnailUrl,
        'arTextureUrl': textureUrl,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // 4. 성공 시 핑크색 알림창을 띄우고 데이터 강제 갱신!
      if (mounted) {
        // 데이터 강제 갱신
        context.read<LensProvider>().fetchLensesFromSupabase();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 새 렌즈가 성공적으로 배포되었습니다!'),
            backgroundColor: Colors.pinkAccent,
          ),
        );
        // 5. 완료 후 이전 대시보드 화면으로 돌아갑니다.
        context.go('/admin-secret-page');
      }
    } catch (e) {
      debugPrint('배포 중 에러 발생: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Bucket not found')) {
          errorMsg = '스토리지 바구니(lens-assets)를 찾을 수 없습니다.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('배포 실패: $errorMsg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      // 로딩 화면을 끕니다.
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _tagsController.dispose();
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
          onPressed: () => context.go('/admin-secret-page'),
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
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '렌즈 설명 (사용자에게 보일 문구)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: '검색 태그 (쉼표로 구분. 예: y2k, 핑크, 하트)',
                    border: OutlineInputBorder(),
                  ),
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
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(true),
                            icon: const Icon(Icons.image),
                            label: const Text('썸네일 선택'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _thumbnailFile?.name ?? '선택된 파일 없음',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(false),
                            icon: const Icon(Icons.face_retouching_natural),
                            label: const Text('AR 텍스처(WebP/PNG) 선택'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _textureFile?.name ?? '선택된 파일 없음',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
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
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.pinkAccent),
                    SizedBox(height: 16),
                    Text(
                      '클라우드에 배포 중입니다...\n창을 닫지 마세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
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
