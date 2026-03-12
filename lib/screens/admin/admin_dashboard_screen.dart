import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/lens_provider.dart';
import '../../models/lens_model.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // 모던한 밝은 회색 배경
      appBar: AppBar(
        title: const Text(
          'ARlens CMS Dashboard',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // 신규 렌즈 등록 화면으로 이동 (GoRouter 사용)
                context.go('/admin-secret-page/add');
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                '신규 렌즈 배포',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent, // 핫핑크 포인트 컬러
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                elevation: 4, // 그림자 효과로 젤리 같은 느낌 부여
                shadowColor: Colors.pinkAccent.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<LensProvider>(
        builder: (context, lensProvider, child) {
          if (lensProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.pinkAccent),
            );
          }

          final lenses = lensProvider.lenses;

          if (lenses.isEmpty) {
            return const Center(
              child: Text(
                '등록된 렌즈가 없습니다.\n우측 상단 버튼을 눌러 새 렌즈를 추가해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            );
          }

          // 웹/PC 환경에 맞춰 넓은 그리드(바둑판) 뷰로 렌즈 목록 표시
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300, // 카드 하나의 최대 너비
                childAspectRatio: 0.7, // 버튼 영역 추가로 세로 비율 조정
                crossAxisSpacing: 24, // 좌우 간격
                mainAxisSpacing: 24, // 상하 간격
              ),
              itemCount: lenses.length,
              itemBuilder: (context, index) {
                final lens = lenses[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 상단 썸네일 이미지 영역
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: lens.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.pinkAccent,
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error, color: Colors.grey),
                          ),
                        ),
                      ),
                      // 하단 렌즈 정보 텍스트 영역
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lens.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lens.description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            // 태그들을 뱃지 모양으로 묶어서 보여줌
                            Wrap(
                              spacing: 6.0,
                              runSpacing: 6.0,
                              children: lens.tags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            // 수정 및 삭제 버튼 영역 추가
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      _showEditDialog(context, lens),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('수정'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blueAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showDeleteDialog(context, lens),
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('삭제'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // 삭제 확인 다이얼로그
  void _showDeleteDialog(BuildContext context, Lens lens) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('렌즈 삭제'),
        content: Text('"${lens.name}"을(를) 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(context); // 다이얼로그 닫기
                await context.read<LensProvider>().deleteLens(lens.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ 삭제가 완료되었습니다.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ 삭제 실패: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 수정용 모달 창 (다이얼로그)
  void _showEditDialog(BuildContext context, Lens lens) {
    final nameController = TextEditingController(text: lens.name);
    final descController = TextEditingController(text: lens.description);
    final tagsController = TextEditingController(text: lens.tags.join(', '));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('렌즈 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '렌즈명'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '설명'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(labelText: '태그 (쉼표로 구분)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final updatedTags = tagsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                await context.read<LensProvider>().updateLens(lens.id, {
                  'name': nameController.text,
                  'description': descController.text,
                  'tags': updatedTags,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ 수정이 완료되었습니다.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ 수정 실패: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
