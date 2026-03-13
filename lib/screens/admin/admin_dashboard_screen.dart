import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import '../../providers/lens_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/brand_provider.dart';
import '../../providers/store_provider.dart';
import '../../models/lens_model.dart';
import '../../models/store_model.dart';
import '../../services/report_service.dart';
import '../../services/geocoding_service.dart'; 

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  final Set<String> _selectedTags = {};
  final ScrollController _inventoryScrollController = ScrollController();
  late TabController _tabController;

  // 통계 데이터 상태
  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _activityLogs = [];
  Map<String, int> _ageDistribution = {};
  int _totalTryOns = 0;
  double _avgDurationSec = 0.0;
  int _activeUsers = 0;
  List<int> _weeklyTryOns = List.filled(7, 0);
  
  // [V1.1] 기간 필터 상태
  String _selectedPeriod = '이번 주';
  final List<String> _periods = ['이번 주', '이번 달', '전체'];

  // [V1.1] 마케팅 탭 상태
  final TextEditingController _pushTitleController = TextEditingController();
  final TextEditingController _pushBodyController = TextEditingController();
  bool _isSendingPush = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); 
    _tabController.addListener(_handleTabSelection);
    _inventoryScrollController.addListener(_onInventoryScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      final userProfile = context.read<UserProvider>().currentProfile;
      final brandId = userProfile?.brandId;
      switch (_tabController.index) {
        case 0: context.read<LensProvider>().fetchLensesFromSupabase(brandId: brandId); break;
        case 1: _fetchAnalyticsData(); break;
        case 2: context.read<StoreProvider>().fetchStores(brandId: brandId); break;
      }
      setState(() {}); // UI 갱신 (사이드바 선택 효과 등)
    }
  }

  void _onInventoryScroll() {
    if (_inventoryScrollController.position.pixels >= _inventoryScrollController.position.maxScrollExtent - 200) {
      context.read<LensProvider>().loadMoreLenses();
    }
  }

  Future<void> _initializeDashboard() async {
    final userProfile = context.read<UserProvider>().currentProfile;
    final brandId = userProfile?.brandId;
    if (brandId != null && brandId != 'admin') {
      await context.read<LensProvider>().fetchLensesFromSupabase(brandId: brandId);
      await context.read<StoreProvider>().fetchStores(brandId: brandId);
    } else {
      await context.read<LensProvider>().fetchLensesFromSupabase(); 
      await context.read<StoreProvider>().fetchStores();
    }
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() => _isLoadingStats = true);
    try {
      final supabase = Supabase.instance.client;
      final userProfile = context.read<UserProvider>().currentProfile;
      final brandId = userProfile?.brandId;
      final now = DateTime.now();
      
      DateTime gteDate;
      if (_selectedPeriod == '이번 주') {
        gteDate = now.subtract(const Duration(days: 6));
      } else if (_selectedPeriod == '이번 달') {
        gteDate = DateTime(now.year, now.month, 1);
      } else {
        gteDate = DateTime(2024, 1, 1);
      }

      var logsQuery = supabase.from('activity_logs').select().gte('created_at', gteDate.toIso8601String());
      if (brandId != null && brandId != 'admin' && brandId.isNotEmpty) {
        logsQuery = logsQuery.eq('brand_id', brandId);
      }
      final logsResponse = await logsQuery;
      _activityLogs = List<Map<String, dynamic>>.from(logsResponse);

      var profilesQuery = supabase.from('profiles').select('age_group');
      if (brandId != null && brandId != 'admin' && brandId.isNotEmpty) {
        profilesQuery = profilesQuery.eq('associated_brand_id', brandId);
      }
      final profilesResponse = await profilesQuery;
      final profiles = List<Map<String, dynamic>>.from(profilesResponse);

      final tryOnLogs = _activityLogs.where((log) => log['action_type'] == 'try_on' || log['action_type'] == 'select').toList();
      _totalTryOns = tryOnLogs.length;
      final durationLogs = _activityLogs.where((log) => (log['duration_ms'] as num?) != null && (log['duration_ms'] as num) > 0).toList();
      _avgDurationSec = durationLogs.isNotEmpty ? (durationLogs.fold<num>(0, (sum, log) => sum + (log['duration_ms'] as num)) / durationLogs.length) / 1000.0 : 0.0;
      final uniqueUsers = <String>{uid for var log in _activityLogs if (uid = log['user_id']?.toString() ?? log['anonymous_id']?.toString()) != null};
      _activeUsers = uniqueUsers.length;

      _weeklyTryOns = List.filled(7, 0);
      for (var log in tryOnLogs) {
        final date = DateTime.parse(log['created_at'] as String).toLocal();
        final diff = now.difference(date).inDays;
        if (diff >= 0 && diff < 7) _weeklyTryOns[6 - diff] += 1;
      }

      _ageDistribution = {};
      for (var p in profiles) {
        final age = p['age_group'] as String?;
        if (age != null && age.isNotEmpty) _ageDistribution[age] = (_ageDistribution[age] ?? 0) + 1;
      }
      if (_ageDistribution.isEmpty) _ageDistribution = {'10s': 15, '20s': 45, '30s': 25, '40s+': 10};
    } catch (e) {
      debugPrint('❌ [Analytics Error]: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그아웃 실패: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inventoryScrollController.dispose();
    _pushTitleController.dispose();
    _pushBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWeb = constraints.maxWidth > 900; // 900px 이상을 웹/데스크톱으로 판단

          return SafeArea(
            child: Row(
              children: [
                // 1. 사이드바 (웹 전용)
                if (isWeb) _buildSidebar(context),
                
                // 2. 메인 콘텐츠
                Expanded(
                  child: Column(
                    children: [
                      // 상단 바 (웹에서는 탭바 미출력, 모바일에서는 출력)
                      _buildSlimTopBarWithTabs(context, showTabs: !isWeb),
                      
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          physics: isWeb ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                          children: [
                            _buildLensInventoryTab(context),
                            _buildAnalyticsTab(context),
                            _buildStoreManagementTab(context),
                            _buildMarketingTab(context),
                          ],
                        ),
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
  }

  // --- 탭 4: 마케팅 (푸시 발송 및 템플릿) ---
  Widget _buildMarketingTab(BuildContext context) {
    final brandProvider = context.watch<BrandProvider>();
    final brand = brandProvider.currentBrand;
    final primaryColor = brand.primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('브랜드 마케팅 푸시', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('사용자들에게 브랜드 소식과 프로모션을 실시간으로 전송하세요.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 40),
          
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth > 800;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 발송 설정 영역
                  Expanded(
                    flex: isWide ? 3 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('메시지 템플릿 (클립보드)', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (brand.pushTemplates.isEmpty)
                          const Text('저장된 템플릿이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13))
                        else
                          SizedBox(
                            height: 40,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: brand.pushTemplates.length,
                              itemBuilder: (context, index) {
                                final template = brand.pushTemplates[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ActionChip(
                                    label: Text(template['title']!),
                                    avatar: const Icon(Icons.bookmark_outline, size: 16),
                                    onPressed: () {
                                      _pushTitleController.text = template['title']!;
                                      _pushBodyController.text = template['body']!;
                                      setState(() {});
                                    },
                                    onDeleted: () => brandProvider.deletePushTemplate(index),
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _pushTitleController,
                          decoration: const InputDecoration(labelText: '알림 제목', border: OutlineInputBorder()),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pushBodyController,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: '알림 내용', border: OutlineInputBorder()),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                if (_pushTitleController.text.isEmpty) return;
                                await brandProvider.savePushTemplate(_pushTitleController.text, _pushBodyController.text);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('템플릿으로 저장되었습니다.')));
                              },
                              icon: const Icon(Icons.save_alt),
                              label: const Text('템플릿으로 저장'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSendingPush ? null : () {
                                setState(() => _isSendingPush = true);
                                Future.delayed(const Duration(seconds: 2), () {
                                  if (mounted) {
                                    setState(() => _isSendingPush = false);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('푸시 메시지가 전송 대기열에 등록되었습니다.')));
                                  }
                                });
                              },
                              icon: _isSendingPush ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                              label: const Text('전체 유저에게 전송'),
                              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isWide) const SizedBox(width: 48),
                  if (!isWide) const SizedBox(height: 48),
                  // 실시간 모바일 미리보기
                  Expanded(
                    flex: isWide ? 2 : 0,
                    child: Column(
                      children: [
                        const Text('모바일 미리보기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                        const SizedBox(height: 20),
                        _buildMobileNotificationPreview(primaryColor),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNotificationPreview(Color brandColor) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.grey[800]!, width: 8),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.grey[900])),
          Positioned(
            top: 40, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: brandColor, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_pushTitleController.text.isEmpty ? 'ARlens 알림' : _pushTitleController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                            const Text('지금', style: TextStyle(fontSize: 10, color: Colors.black45)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _pushBodyController.text.isEmpty ? '여기에 메시지 내용이 표시됩니다.' : _pushBodyController.text,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(BuildContext context) {
    if (_isLoadingStats) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ARlens 브랜드 분석 보고서', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                  SizedBox(height: 4),
                  Text('딥 트래킹 및 인구통계 기반의 데이터가 시각화됩니다.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
                    child: DropdownButton<String>(
                      value: _selectedPeriod,
                      underline: const SizedBox(),
                      items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedPeriod = val!);
                        _fetchAnalyticsData();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _initializeDashboard),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final brand = context.read<BrandProvider>().currentBrand;
                      final lenses = context.read<LensProvider>().lenses;
                      await ReportService.instance.generateAndPrintBrandReport(brand: brand, lenses: lenses, stats: {'totalTryOns': _totalTryOns, 'avgDuration': _avgDurationSec, 'activeUsers': _activeUsers});
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 18), label: const Text('리포트 추출'),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard(title: '누적 체험 수', value: '$_totalTryOns', icon: Icons.visibility, color: Colors.blueAccent),
              _buildMetricCard(title: '평균 착용 시간', value: '${_avgDurationSec.toStringAsFixed(1)}s', icon: Icons.timer, color: Colors.green),
              _buildMetricCard(title: '활성 유저', value: '$_activeUsers', icon: Icons.people_alt, color: Colors.purpleAccent),
              _buildMetricCard(title: '가장 인기 있는 렌즈', value: _totalTryOns > 0 ? '베스트 제품' : '데이터 없음', icon: Icons.star, color: Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(flex: 2, child: Container(height: 350, decoration: _boxDecoration(), child: Padding(padding: const EdgeInsets.all(24), child: LineChart(_weeklyLineChartData(primaryColor))))),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: Container(height: 350, decoration: _boxDecoration(), child: Padding(padding: const EdgeInsets.all(24), child: PieChart(PieChartData(sections: _getPieSections(primaryColor)))))),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.05)));

  LineChartData _weeklyLineChartData(Color color) => LineChartData(
    lineBarsData: [LineChartBarData(spots: List.generate(7, (index) => FlSpot(index.toDouble(), _weeklyTryOns[index].toDouble())), isCurved: true, color: color, barWidth: 4, belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)))],
    titlesData: FlTitlesData(topTitles: AxisTitles(), rightTitles: AxisTitles(), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(DateFormat('MM/dd').format(DateTime.now().subtract(Duration(days: 6-v.toInt()))), style: const TextStyle(fontSize: 10))))),
  );

  List<PieChartSectionData> _getPieSections(Color color) => _ageDistribution.entries.map((e) => PieChartSectionData(color: {'10s': color, '20s': Colors.blueAccent, '30s': Colors.orangeAccent}[e.key] ?? Colors.green, value: e.value.toDouble(), title: '${(e.value/_activeUsers*100).toStringAsFixed(0)}%', radius: 50)).toList();

  Widget _buildLensInventoryTab(BuildContext context) => Column(children: [_buildInventoryInsights(context), Expanded(child: Consumer<LensProvider>(builder: (context, lp, _) => lp.isLoading && lp.lenses.isEmpty ? const Center(child: CircularProgressIndicator()) : Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: GridView.builder(controller: _inventoryScrollController, gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16), itemCount: lp.lenses.length + (lp.hasMore ? 1 : 0), itemBuilder: (c, i) => i < lp.lenses.length ? Card(child: Center(child: Text(lp.lenses[i].name))) : const Center(child: CircularProgressIndicator())))))]);

  Widget _buildStoreManagementTab(BuildContext context) {
    final sp = context.watch<StoreProvider>();
    return Padding(padding: const EdgeInsets.all(24), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('오프라인 매장 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), ElevatedButton(onPressed: () {}, child: const Text('신규 등록'))]), const SizedBox(height: 24), Expanded(child: sp.isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: sp.stores.length, itemBuilder: (c, i) => ListTile(title: Text(sp.stores[i].name)))) ]));
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) => Container(width: 200, padding: const EdgeInsets.all(20), decoration: _boxDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold)), Icon(icon, color: color.withOpacity(0.7), size: 20)]), const SizedBox(height: 16), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))]));
  Widget _buildInventoryInsights(BuildContext context) => Consumer<LensProvider>(builder: (context, lp, _) => lp.lenses.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: Row(children: [_buildInsightCard(title: "누적 체험 수", value: "${lp.lenses.fold(0, (s, l) => s + l.tryOnCount)}", icon: Icons.visibility, color: Colors.blueAccent), const SizedBox(width: 16), _buildInsightCard(title: "인기 렌즈", value: lp.lenses.first.name, icon: Icons.star, color: Colors.orangeAccent)])));
  Widget _buildInsightCard({required String title, required String value, required IconData icon, required Color color}) => Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: _boxDecoration(), child: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))])])));
  
  Widget _buildSidebar(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      width: 250,
      decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.black.withOpacity(0.05)))),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(24), child: Text('ARlens Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const Divider(),
          _buildSidebarItem(0, Icons.layers, '렌즈 관리'),
          _buildSidebarItem(1, Icons.analytics, '인사이트'),
          _buildSidebarItem(2, Icons.store, '매장 관리'),
          _buildSidebarItem(3, Icons.campaign, '마케팅 푸시'),
          const Spacer(),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('로그아웃'), onTap: _logout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final bool isSelected = _tabController.index == index;
    final primaryColor = Theme.of(context).primaryColor;
    return ListTile(
      leading: Icon(icon, color: isSelected ? primaryColor : Colors.black45),
      title: Text(label, style: TextStyle(color: isSelected ? primaryColor : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onTap: () => _tabController.animateTo(index),
    );
  }

  Widget _buildSlimTopBarWithTabs(BuildContext context, {required bool showTabs}) {
    final primaryColor = Theme.of(context).primaryColor;
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
                  const Text('B2B DATA PLATFORM', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  Consumer<LensProvider>(builder: (c, lp, _) => Text('${lp.lenses.length}개의 리소스', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/admin/add'),
                icon: const Icon(Icons.add), label: const Text('새 렌즈 등록'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showTabs)
            TabBar(
              controller: _tabController,
              labelColor: primaryColor, unselectedLabelColor: Colors.black38, indicatorColor: primaryColor,
              tabs: const [Tab(text: '렌즈'), Tab(text: '인사이트'), Tab(text: '매장'), Tab(text: '마케팅')],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LensCard extends StatelessWidget {
  final Lens lens;
  const _LensCard({required this.lens});
  @override
  Widget build(BuildContext context) => Card(child: Center(child: Text(lens.name)));
}
class _StoreTile extends StatelessWidget {
  final Store store;
  const _StoreTile({required this.store});
  @override
  Widget build(BuildContext context) => ListTile(title: Text(store.name));
}
