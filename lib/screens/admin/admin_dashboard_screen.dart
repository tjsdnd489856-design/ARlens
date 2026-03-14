import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _activityLogs = [];
  Map<String, int> _ageDistribution = {};
  int _totalTryOns = 0;
  double _avgDurationSec = 0.0;
  int _activeUsers = 0;
  List<int> _weeklyTryOns = List.filled(7, 0);
  
  String _selectedPeriod = '이번 주';
  final List<String> _periods = ['이번 주', '이번 달', '전체'];

  final TextEditingController _pushTitleController = TextEditingController();
  final TextEditingController _pushBodyController = TextEditingController();
  bool _isSendingPush = false;
  bool _isIOSPreview = true; 

  // [Grand Master] 렌즈 인벤토리 검색 및 정렬 상태
  final TextEditingController _lensSearchController = TextEditingController();
  String _lensSearchQuery = '';
  String _lensSortOption = '최신순';
  final List<String> _sortOptions = ['최신순', '인기순', '이름순'];

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
      setState(() {}); 
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
      
      final uniqueUsers = _activityLogs
          .map((log) => log['user_id']?.toString() ?? log['anonymous_id']?.toString())
          .whereType<String>()
          .toSet();
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
      context.read<UserProvider>().clear();
      context.read<BrandProvider>().clear();
      context.read<LensProvider>().clear();
      context.read<StoreProvider>().clear();
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그아웃 실패: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _sendActualPushNotification() async {
    if (_pushTitleController.text.isEmpty || _pushBodyController.text.isEmpty) return;
    setState(() => _isSendingPush = true);
    try {
      final String? proxyUrl = dotenv.env['SUPABASE_FUNCTION_URL'];
      if (proxyUrl == null || proxyUrl.isEmpty) throw Exception('푸시 서버 설정 누락');
      
      final response = await http.post(
        Uri.parse(proxyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ""}',
        },
        body: jsonEncode({
          'title': _pushTitleController.text,
          'body': _pushBodyController.text,
          'brand_id': context.read<BrandProvider>().currentBrand.id,
          'topic': 'all_users',
        }),
      );
      
      if (response.statusCode == 200) { 
        if (mounted) _showSimpleSnackBar('푸시 메시지 발송 요청 성공'); 
      } else { 
        throw Exception('서버 응답 오류 (${response.statusCode})'); 
      }
    } catch (e) { 
      if (mounted) _showSimpleSnackBar('발송 오류: $e', isError: true); 
    } finally { 
      if (mounted) setState(() => _isSendingPush = false); 
    }
  }

  void _showSimpleSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inventoryScrollController.dispose();
    _pushTitleController.dispose();
    _pushBodyController.dispose();
    _lensSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWeb = constraints.maxWidth > 900; 
          return SafeArea(
            child: Row(
              children: [
                if (isWeb) _buildSidebar(context),
                Expanded(
                  child: Column(
                    children: [
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

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 375,
      decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.black.withOpacity(0.05)))),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(36), child: Text('ARlens Admin', style: TextStyle(fontSize: 33, fontWeight: FontWeight.bold, color: Colors.black87))),
          const Divider(),
          _buildSidebarItem(0, Icons.layers, '렌즈 관리'),
          _buildSidebarItem(1, Icons.analytics, '인사이트'),
          _buildSidebarItem(2, Icons.store, '매장 관리'),
          _buildSidebarItem(3, Icons.campaign, '마케팅 푸시'),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent, size: 27), 
            title: const Text('로그아웃', style: TextStyle(color: Colors.redAccent, fontSize: 21, fontWeight: FontWeight.bold)), 
            onTap: _logout,
            contentPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final bool isSelected = _tabController.index == index;
    final primaryColor = Theme.of(context).primaryColor;
    return ListTile(
      leading: Icon(icon, color: isSelected ? primaryColor : Colors.grey[800], size: 30),
      title: Text(label, style: TextStyle(color: isSelected ? primaryColor : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 21)),
      selected: isSelected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
      onTap: () => _tabController.animateTo(index),
    );
  }

  Widget _buildSlimTopBarWithTabs(BuildContext context, {required bool showTabs}) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.fromLTRB(36, 24, 36, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('B2B DATA PLATFORM', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                  Consumer<LensProvider>(builder: (c, lp, _) => Text('${lp.lenses.length}개의 리소스', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/admin/add'),
                icon: const Icon(Icons.add, size: 24), label: const Text('새 렌즈 등록', style: TextStyle(fontSize: 21)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (showTabs)
            TabBar(
              controller: _tabController,
              labelColor: primaryColor, unselectedLabelColor: Colors.grey[600], indicatorColor: primaryColor,
              labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              tabs: const [Tab(text: '렌즈'), Tab(text: '인사이트'), Tab(text: '매장'), Tab(text: '마케팅')],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) => Container(
    width: 300, padding: const EdgeInsets.all(30), decoration: _boxDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.black87, fontSize: 19, fontWeight: FontWeight.bold)), Icon(icon, color: color.withOpacity(0.7), size: 30)]),
      const SizedBox(height: 24),
      Text(value, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.black87))
    ]));

  // [Grand Master] 렌즈 인벤토리 실시간 검색 및 정렬 바
  Widget _buildLensInventoryTab(BuildContext context) {
    return Column(
      children: [
        _buildInventoryInsights(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 36, 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lensSearchController,
                  decoration: InputDecoration(
                    hintText: '렌즈명 또는 브랜드명으로 검색',
                    hintStyle: const TextStyle(fontSize: 18, color: Colors.black38),
                    prefixIcon: const Icon(Icons.search, color: Colors.black54),
                    suffixIcon: _lensSearchQuery.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _lensSearchController.clear(); setState(() => _lensSearchQuery = ''); })
                      : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
                  ),
                  onChanged: (val) => setState(() => _lensSearchQuery = val.toLowerCase()),
                ),
              ),
              const SizedBox(width: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                child: DropdownButton<String>(
                  value: _lensSortOption,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.sort, color: Colors.black54),
                  items: _sortOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 18, color: Colors.black87)))).toList(),
                  onChanged: (val) => setState(() => _lensSortOption = val!),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<LensProvider>(
            builder: (context, lp, _) {
              if (lp.isLoading && lp.lenses.isEmpty) return const Center(child: CircularProgressIndicator());
              
              var filteredLenses = lp.lenses.where((lens) => 
                lens.name.toLowerCase().contains(_lensSearchQuery) || 
                (lens.brandId?.toLowerCase().contains(_lensSearchQuery) ?? false)
              ).toList();

              // 정렬 적용
              if (_lensSortOption == '이름순') {
                filteredLenses.sort((a, b) => a.name.compareTo(b.name));
              } else if (_lensSortOption == '인기순') {
                filteredLenses.sort((a, b) => b.tryOnCount.compareTo(a.tryOnCount));
              } else {
                // 최신순 (기본 데이터가 최신순일 가능성이 높지만 명시적으로 정렬 가능)
                filteredLenses.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
              }

              if (filteredLenses.isEmpty) return const Center(child: Text('검색 결과가 없습니다.', style: TextStyle(fontSize: 18, color: Colors.black54)));

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36), 
                child: GridView.builder(
                  controller: _inventoryScrollController, 
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, childAspectRatio: 0.8, crossAxisSpacing: 24, mainAxisSpacing: 24), 
                  itemCount: filteredLenses.length + (lp.hasMore && _lensSearchQuery.isEmpty ? 1 : 0), 
                  itemBuilder: (c, i) => i < filteredLenses.length 
                    ? _buildLensCard(filteredLenses[i]) 
                    : const Center(child: CircularProgressIndicator())
                )
              );
            }
          )
        )
      ]
    );
  }

  Widget _buildLensCard(Lens lens) {
    return InkWell(
      onDoubleTap: () => context.push('/admin/add', extra: lens),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 195,
            height: 195,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: ClipOval(
              child: lens.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: lens.thumbnailUrl, fit: BoxFit.cover, memCacheHeight: 400, memCacheWidth: 400, placeholder: (context, url) => Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(color: Colors.white)), errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.black12))
                  : const Icon(Icons.image, color: Colors.black12, size: 75),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.black.withOpacity(0.05))),
            child: Text(lens.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 19, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryInsights(BuildContext context) => Consumer<LensProvider>(builder: (context, lp, _) => lp.lenses.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.fromLTRB(36, 0, 36, 36), child: Row(children: [_buildInsightCard(title: "누적 체험 수", value: "${lp.lenses.fold(0, (s, l) => s + l.tryOnCount)}", icon: Icons.visibility, color: Colors.blueAccent), const SizedBox(width: 24), _buildInsightCard(title: "인기 렌즈", value: lp.lenses.isEmpty ? '-' : lp.lenses.first.name, icon: Icons.star, color: Colors.orangeAccent)])));

  Widget _buildInsightCard({required String title, required String value, required IconData icon, required Color color}) => Expanded(child: Container(padding: const EdgeInsets.all(24), decoration: _boxDecoration(), child: Row(children: [Icon(icon, color: color, size: 30), const SizedBox(width: 18), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 21))])])));

  Widget _buildAnalyticsTab(BuildContext context) {
    if (_isLoadingStats) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ARlens 브랜드 분석 보고서', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                  SizedBox(height: 6),
                  Text('딥 트래킹 및 인구통계 기반의 데이터가 시각화됩니다.', style: TextStyle(fontSize: 21, color: Colors.black87)),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                    child: DropdownButton<String>(
                      value: _selectedPeriod,
                      underline: const SizedBox(),
                      items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 19, color: Colors.black87)))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedPeriod = val!);
                        _fetchAnalyticsData();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.black87, size: 30), onPressed: _initializeDashboard),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final brand = context.read<BrandProvider>().currentBrand;
                      final lenses = context.read<LensProvider>().lenses;
                      await ReportService.instance.generateAndPrintBrandReport(brand: brand, lenses: lenses, stats: {'totalTryOns': _totalTryOns, 'avgDuration': _avgDurationSec, 'activeUsers': _activeUsers});
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 27), label: const Text('리포트 추출', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildMetricCard(title: '누적 체험 수', value: '$_totalTryOns', icon: Icons.visibility, color: Colors.blueAccent),
              _buildMetricCard(title: '평균 착용 시간', value: '${_avgDurationSec.toStringAsFixed(1)}s', icon: Icons.timer, color: Colors.green),
              _buildMetricCard(title: '활성 유저', value: '$_activeUsers', icon: Icons.people_alt, color: Colors.purpleAccent),
              _buildMetricCard(title: '가장 인기 있는 렌즈', value: _totalTryOns > 0 ? '베스트 제품' : '데이터 없음', icon: Icons.star, color: Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(flex: 2, child: Container(height: 525, decoration: _boxDecoration(), child: Padding(padding: const EdgeInsets.all(36), child: LineChart(_weeklyLineChartData(primaryColor))))),
              const SizedBox(width: 36),
              Expanded(flex: 1, child: Container(height: 525, decoration: _boxDecoration(), child: Padding(padding: const EdgeInsets.all(36), child: PieChart(PieChartData(sections: _getPieSections(primaryColor)))))),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _weeklyLineChartData(Color color) => LineChartData(
    lineBarsData: [LineChartBarData(spots: List.generate(7, (index) => FlSpot(index.toDouble(), _weeklyTryOns[index].toDouble())), isCurved: true, color: color, barWidth: 6, belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)))],
    titlesData: FlTitlesData(topTitles: AxisTitles(), rightTitles: AxisTitles(), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(DateFormat('MM/dd').format(DateTime.now().subtract(Duration(days: 6-v.toInt()))), style: const TextStyle(fontSize: 15, color: Colors.black87))))),
  );

  List<PieChartSectionData> _getPieSections(Color color) => _ageDistribution.entries.map((e) => PieChartSectionData(color: {'10s': color, '20s': Colors.blueAccent, '30s': Colors.orangeAccent}[e.key] ?? Colors.green, value: e.value.toDouble(), title: '${(e.value/(_activeUsers > 0 ? _activeUsers : 1)*100).toStringAsFixed(0)}%', radius: 75, titleStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))).toList();

  Widget _buildStoreManagementTab(BuildContext context) {
    final sp = context.watch<StoreProvider>();
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('오프라인 매장 관리', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)),
              ElevatedButton.icon(
                onPressed: () => _showAddStoreDialog(context),
                icon: const Icon(Icons.add, size: 27),
                label: const Text('신규 매장 등록', style: TextStyle(fontSize: 21)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.pinkAccent, elevation: 0, side: const BorderSide(color: Colors.black12), padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Expanded(
            child: sp.isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : ListView.builder(
                  itemCount: sp.stores.length, 
                  itemBuilder: (c, i) {
                    final store = sp.stores[i];
                    return Card(
                      elevation: 0, margin: const EdgeInsets.only(bottom: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.black12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 21)),
                        subtitle: Text(store.address, style: const TextStyle(color: Colors.black54, fontSize: 16)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 27), onPressed: () => _showAddStoreDialog(context, existingStore: store)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 27), onPressed: () => _confirmDeleteStore(context, store)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          )
        ],
      ),
    );
  }

  void _confirmDeleteStore(BuildContext context, Store store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매장 삭제', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 24)),
        content: Text('"${store.name}" 매장을 영구히 삭제하시겠습니까?', style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(fontSize: 18))),
          TextButton(
            onPressed: () async {
              await context.read<StoreProvider>().deleteStore(store.id);
              if (context.mounted) Navigator.pop(context);
            }, 
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  void _showAddStoreDialog(BuildContext context, {Store? existingStore}) {
    final nameController = TextEditingController(text: existingStore?.name);
    final addressController = TextEditingController(text: existingStore?.address);
    LatLng? selectedLatLng = existingStore != null ? LatLng(existingStore.latitude, existingStore.longitude) : null;
    bool isVerifying = false;
    bool isAddressChanged = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingStore == null ? '신규 매장 등록' : '매장 정보 수정', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, style: const TextStyle(fontSize: 18), decoration: const InputDecoration(labelText: '매장명')),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addressController, 
                          style: const TextStyle(fontSize: 18), 
                          decoration: const InputDecoration(labelText: '주소'),
                          onChanged: (val) {
                            if (!isAddressChanged) setDialogState(() { isAddressChanged = true; selectedLatLng = null; });
                          },
                        )
                      ),
                      IconButton(
                        icon: isVerifying ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search, size: 30),
                        onPressed: () async {
                          setDialogState(() => isVerifying = true);
                          try {
                            final coords = await GeocodingService.instance.getLatLngFromAddress(addressController.text);
                            if (coords != null) {
                              setDialogState(() { selectedLatLng = LatLng(coords.latitude, coords.longitude); isAddressChanged = false; });
                            }
                          } finally { setDialogState(() => isVerifying = false); }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  if (selectedLatLng != null)
                    Container(
                      height: 225, width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(target: selectedLatLng!, zoom: 15),
                          markers: {Marker(markerId: const MarkerId('selected'), position: selectedLatLng!)},
                          zoomControlsEnabled: false, mapToolbarEnabled: false,
                        ),
                      ),
                    ),
                  if (isAddressChanged)
                    const Padding(padding: EdgeInsets.only(top: 12), child: Text('⚠️ 주소 검색 버튼을 눌러 위치를 확정해 주세요.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14))),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(fontSize: 18))),
            ElevatedButton(
              onPressed: (selectedLatLng == null || isAddressChanged) ? null : () async {
                final brandId = context.read<UserProvider>().currentProfile?.brandId;
                if (existingStore != null) {
                  await context.read<StoreProvider>().updateStore(existingStore.id, {'name': nameController.text, 'address': addressController.text, 'latitude': selectedLatLng!.latitude, 'longitude': selectedLatLng!.longitude}, brandId: brandId);
                } else {
                  await context.read<StoreProvider>().addStore({'name': nameController.text, 'address': addressController.text, 'latitude': selectedLatLng!.latitude, 'longitude': selectedLatLng!.longitude, 'brand_id': brandId});
                }
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              child: Text(existingStore == null ? '등록' : '저장', style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketingTab(BuildContext context) {
    final brandProvider = context.watch<BrandProvider>();
    final brand = brandProvider.currentBrand;
    final primaryColor = brand.primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('브랜드 마케팅 푸시', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          const Text('사용자들에게 브랜드 소식과 프로모션을 실시간으로 전송하세요.', style: TextStyle(color: Colors.black87, fontSize: 21)),
          const SizedBox(height: 60),
          
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth > 1200;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 3 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('메시지 템플릿 (클립보드)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 21)),
                        const SizedBox(height: 18),
                        if (brand.pushTemplates.isEmpty)
                          const Text('저장된 템플릿이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 19))
                        else
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: brand.pushTemplates.length,
                              itemBuilder: (context, index) {
                                final template = brand.pushTemplates[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: InputChip(
                                    label: Text(template['title']!, style: const TextStyle(color: Colors.black87, fontSize: 16)),
                                    avatar: const Icon(Icons.bookmark_outline, size: 24, color: Colors.black87),
                                    onPressed: () {
                                      _pushTitleController.text = template['title']!;
                                      _pushBodyController.text = template['body']!;
                                      setState(() {});
                                    },
                                    onDeleted: () => brandProvider.deletePushTemplate(index),
                                    deleteIcon: const Icon(Icons.close, size: 21, color: Colors.black87),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 48),
                        TextField(
                          controller: _pushTitleController,
                          style: const TextStyle(color: Colors.black87, fontSize: 21),
                          decoration: const InputDecoration(labelText: '알림 제목', labelStyle: TextStyle(color: Colors.black87, fontSize: 18), border: OutlineInputBorder()),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _pushBodyController,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.black87, fontSize: 21),
                          decoration: const InputDecoration(labelText: '알림 내용', labelStyle: TextStyle(color: Colors.black87, fontSize: 18), border: OutlineInputBorder()),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 36),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                if (_pushTitleController.text.isEmpty) return;
                                await brandProvider.savePushTemplate(_pushTitleController.text, _pushBodyController.text);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('템플릿으로 저장되었습니다.')));
                              },
                              icon: const Icon(Icons.save_alt, size: 24),
                              label: const Text('템플릿으로 저장', style: TextStyle(fontSize: 18)),
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                            ),
                            const SizedBox(width: 18),
                            ElevatedButton.icon(
                              onPressed: _isSendingPush ? null : _sendActualPushNotification, 
                              icon: _isSendingPush ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.send, size: 24),
                              label: const Text('전체 유저에게 전송', style: TextStyle(fontSize: 18)),
                              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isWide) const SizedBox(width: 72),
                  if (!isWide) const SizedBox(height: 72),
                  Expanded(
                    flex: isWide ? 2 : 0,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('모바일 미리보기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 18)),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(24)),
                              child: Row(
                                children: [
                                  _buildOSToggleItem('iOS', _isIOSPreview, () => setState(() => _isIOSPreview = true)),
                                  _buildOSToggleItem('Android', !_isIOSPreview, () => setState(() => _isIOSPreview = false)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
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

  Widget _buildOSToggleItem(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)] : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 18, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.black87 : Colors.black45)),
      ),
    );
  }

  Widget _buildMobileNotificationPreview(Color brandColor) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480), 
      width: double.infinity,
      height: 675, 
      clipBehavior: Clip.antiAlias, 
      decoration: BoxDecoration(
        color: Colors.black, 
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: Colors.grey[900]!, width: 12),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.black)),
          if (_isIOSPreview)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 18),
                width: 150, height: 36,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(18)),
              ),
            )
          else
            Positioned(
              top: 18, left: 0, right: 0,
              child: Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle))),
            ),
          
          Positioned(
            top: 90, left: 24, right: 24,
            child: _isIOSPreview 
              ? _buildIOSNotificationCard(brandColor) 
              : _buildAndroidNotificationCard(brandColor),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSNotificationCard(Color brandColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(33),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15)]
      ),
      child: Row(
        children: [
          Container(
            width: 57, height: 57,
            decoration: BoxDecoration(color: brandColor, borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 33),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_pushTitleController.text.isEmpty ? 'ARlens' : _pushTitleController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 21, color: Colors.black87)),
                    const Text('지금', style: TextStyle(fontSize: 16, color: Colors.black45)),
                  ],
                ),
                Text(
                  _pushBodyController.text.isEmpty ? '여기에 메시지 내용이 표시됩니다.' : _pushBodyController.text,
                  style: const TextStyle(fontSize: 19, color: Colors.black87, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidNotificationCard(Color brandColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.remove_red_eye, color: brandColor, size: 21),
              const SizedBox(width: 12),
              const Text('ARlens • 지금', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_pushTitleController.text.isEmpty ? '알림 제목' : _pushTitleController.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 21)),
          Text(
            _pushBodyController.text.isEmpty ? '메시지 내용' : _pushBodyController.text,
            style: const TextStyle(color: Colors.white70, fontSize: 19),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.05)));
}
