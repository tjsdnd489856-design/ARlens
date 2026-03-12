import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/lens_provider.dart';
import '../../models/lens_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Set<String> _selectedTags = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean Light Grey
      body: SafeArea(
        child: Row(
          children: [
            // 1. 좌측 태그 필터 사이드바 (250px 고정)
            _buildSidebar(context),

            // 2. 우측 메인 콘텐츠
            Expanded(
              child: Column(
                children: [
                  _buildSlimTopBar(context),
                  Expanded(
                    child: Consumer<LensProvider>(
                      builder: (context, lensProvider, child) {
                        if (lensProvider.isLoading) {
                          return _buildSkeletonGrid();
                        }

                        // 필터링 로직 적용
                        final allLenses = lensProvider.lenses;
                        final filteredLenses = _selectedTags.isEmpty
                            ? allLenses
                            : allLenses.where((lens) {
                                return lens.tags.any(
                                  (tag) => _selectedTags.contains(tag),
                                );
                              }).toList();

                        if (filteredLenses.isEmpty) {
                          return _buildEmptyState();
                        }

                        // 3. 조밀한 그리드 시스템 (maxCrossAxisExtent 축소)
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 200, // 더 조밀하게 조정
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: filteredLenses.length,
                            itemBuilder: (context, index) {
                              return _LensCard(lens: filteredLenses[index]);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (_selectedTags.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedTags.clear()),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<LensProvider>(
              builder: (context, lensProvider, child) {
                // 중복 없는 태그 리스트 추출
                final allTags = lensProvider.lenses
                    .expand((lens) => lens.tags)
                    .toSet()
                    .toList();
                allTags.sort();

                if (allTags.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tags available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: allTags.length,
                  itemBuilder: (context, index) {
                    final tag = allTags[index];
                    final isSelected = _selectedTags.contains(tag);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? Colors.black87 : Colors.black54,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlimTopBar(BuildContext context) {
    final lensCount = context.watch<LensProvider>().lenses.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LENS INVENTORY',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$lensCount Items',
                style: const TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () => context.go('/admin-secret-page/add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D2D2D),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Row(
              children: [
                Icon(Icons.add, size: 20),
                SizedBox(width: 8),
                Text('Add New', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 8,
        itemBuilder: (context, index) => const _SkeletonCard(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear_outlined, size: 64, color: Colors.black12),
          const SizedBox(height: 16),
          const Text(
            'No lenses match the selected filters.',
            style: TextStyle(color: Colors.black38, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _LensCard extends StatefulWidget {
  final Lens lens;
  const _LensCard({required this.lens});

  @override
  State<_LensCard> createState() => _LensCardState();
}

class _LensCardState extends State<_LensCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Thumbnail Image
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: widget.lens.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: const Color(0xFFF1F3F5)),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, color: Colors.grey),
                ),
              ),

              // 2. Info Overlay (Bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12), // 조밀하게 조정
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lens.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14, // 더 작게 조정
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Pretendard',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: widget.lens.tags.map((tag) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    '#$tag',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10, // 더 작게 조정
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Action Buttons (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isHovered ? 1.0 : 0.0, // 평소엔 숨김 처리로 더 깔끔하게
                  child: Row(
                    children: [
                      _buildRoundAction(
                        icon: Icons.edit_outlined,
                        color: const Color(0xFF2D2D2D),
                        onTap: () => _showEditDialog(context, widget.lens),
                      ),
                      const SizedBox(width: 4),
                      _buildRoundAction(
                        icon: Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        onTap: () => _showDeleteDialog(context, widget.lens),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6), // 더 작게 조정
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 14), // 더 작게 조정
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Lens lens) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Delete Lens',
          style: TextStyle(color: Color(0xFF2D2D2D)),
        ),
        content: Text(
          'Do you want to delete "${lens.name}"?',
          style: const TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black38),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<LensProvider>().deleteLens(lens);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Lens lens) {
    final nameController = TextEditingController(text: lens.name);
    final descController = TextEditingController(text: lens.description);
    final tagsController = TextEditingController(text: lens.tags.join(', '));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Edit Lens',
          style: TextStyle(color: Color(0xFF2D2D2D)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Color(0xFF2D2D2D)),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: const TextStyle(color: Colors.black38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                style: const TextStyle(color: Color(0xFF2D2D2D)),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(color: Colors.black38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagsController,
                style: const TextStyle(color: Color(0xFF2D2D2D)),
                decoration: InputDecoration(
                  labelText: 'Tags (comma separated)',
                  labelStyle: const TextStyle(color: Colors.black38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
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
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D2D2D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
