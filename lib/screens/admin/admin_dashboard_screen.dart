import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/lens_provider.dart';
import '../../models/lens_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Set<String> _selectedTags = {};

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean Light Grey
      body: SafeArea(
        child: Row(
          children: [
            // 1. 좌측 태그 필터 사이드바 (250px 고정)
            _buildSidebar(context),

            // 2. 우측 메인 콘텐츠 (확장형 Tab 구조 도입)
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    _buildSlimTopBarWithTabs(context),
                    
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Lens Inventory (기존 렌즈 관리 화면)
                          _buildLensInventoryTab(context),
                          
                          // Tab 2: Advanced Analytics (데이터 플랫폼 확장을 위한 통계 대시보드 구조)
                          _buildAnalyticsTab(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 기존 렌즈 관리 탭 구성 ---
  Widget _buildLensInventoryTab(BuildContext context) {
    return Column(
      children: [
        _buildBusinessInsights(context), // 간편 인사이트 유지
        Expanded(
          child: Consumer<LensProvider>(
            builder: (context, lensProvider, child) {
              if (lensProvider.isLoading) {
                return _buildSkeletonGrid();
              }

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

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
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
    );
  }

  // --- 신규 심화 통계 탭 구성 (준비 상태) ---
  Widget _buildAnalyticsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Advanced Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Deep Tracking 및 인구통계 기반의 데이터가 이곳에 시각화됩니다.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 32),
          
          // 향후 차트가 들어갈 Placeholder 카드들
          Row(
            children: [
              Expanded(
                child: _buildChartPlaceholder(
                  title: 'Age Group Distribution',
                  icon: Icons.pie_chart_outline,
                  height: 250,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildChartPlaceholder(
                  title: 'Brand Engagement Trend',
                  icon: Icons.show_chart,
                  height: 250,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildChartPlaceholder(
            title: 'Action Funnel (Try-on -> Capture -> Share)',
            icon: Icons.filter_alt_outlined,
            height: 300,
          ),
        ],
      ),
    );
  }

  Widget _buildChartPlaceholder({required String title, required IconData icon, required double height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: Colors.black12),
                  const SizedBox(height: 16),
                  const Text('Data visualization ready', style: TextStyle(color: Colors.black38)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSlimTopBarWithTabs(BuildContext context) {
    final lensCount = context.watch<LensProvider>().lenses.length;
    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'B2B DATA PLATFORM',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$lensCount Resources',
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
                onPressed: () => context.go('/admin/add'),
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
                    Text('Add New Lens', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // TabBar 적용
          const TabBar(
            labelColor: Color(0xFF2D2D2D),
            unselectedLabelColor: Colors.black38,
            indicatorColor: Color(0xFF2D2D2D),
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Lens Inventory'),
              Tab(text: 'Advanced Analytics (B2B)'),
            ],
          ),
          const SizedBox(height: 16), // 약간의 여백
        ],
      ),
    );
  }

  Widget _buildBusinessInsights(BuildContext context) {
    return Consumer<LensProvider>(
      builder: (context, lensProvider, child) {
        if (lensProvider.isLoading || lensProvider.lenses.isEmpty) {
          return const SizedBox.shrink();
        }

        final lenses = lensProvider.lenses;
        
        // 통계 계산
        int totalTryOns = lenses.fold(0, (sum, lens) => sum + lens.tryOnCount);
        Lens? mostPopular = lenses.reduce((a, b) => a.tryOnCount > b.tryOnCount ? a : b);

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              _buildInsightCard(
                title: "Total Try-ons",
                value: "$totalTryOns",
                icon: Icons.visibility,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 16),
              _buildInsightCard(
                title: "Most Popular Lens",
                value: mostPopular.tryOnCount > 0 ? mostPopular.name : "N/A",
                subtitle: mostPopular.tryOnCount > 0 ? "${mostPopular.tryOnCount} tries" : null,
                icon: Icons.star,
                color: Colors.orangeAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.black38, fontSize: 11)),
                  ]
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
          const Divider(height: 1),
          // 로그아웃 버튼 추가
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
              label: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                alignment: Alignment.centerLeft,
              ),
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

              // [신규] 통계 배지 (좌측 상단)
              if (widget.lens.tryOnCount > 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.lens.tryOnCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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
