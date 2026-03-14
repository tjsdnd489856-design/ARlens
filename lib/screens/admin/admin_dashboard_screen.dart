import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../providers/connectivity_provider.dart';
import '../../models/lens_model.dart';
import '../../models/brand_model.dart';
import '../../models/store_model.dart';
import '../../services/report_service.dart';
import '../../services/geocoding_service.dart'; 
import '../../widgets/brand_shimmer.dart'; 

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String? _simulatedBrandId;
  List<Map<String, dynamic>> _allBrands = [];
  bool _isLoadingBrands = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    final up = context.read<UserProvider>();
    if (up.isLoading || up.currentProfile == null) {
      int retryCount = 0;
      while ((up.isLoading || up.currentProfile == null) && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retryCount++;
      }
    }
    if (up.currentProfile?.brandId == 'admin') await _fetchBrands();
  }

  Future<void> _fetchBrands() async {
    setState(() => _isLoadingBrands = true);
    try {
      final response = await Supabase.instance.client.from('brands').select('id, name');
      _allBrands = [{'id': null, 'name': '전체 브랜드 (Admin)'}, ...List<Map<String, dynamic>>.from(response)];
    } catch (e) {
      debugPrint('❌ Brand Fetch Error: $e');
    } finally {
      setState(() => _isLoadingBrands = false);
    }
  }

  Future<void> _syncSimulatedTheme(String? brandId) async {
    final bp = context.read<BrandProvider>();
    final up = context.read<UserProvider>();
    if (brandId == null || brandId == 'admin') {
      if (up.currentProfile?.brandId != null) {
        final resp = await Supabase.instance.client.from('brands').select().eq('id', up.currentProfile!.brandId!).maybeSingle();
        if (resp != null) bp.setBrand(Brand.fromJson(resp));
      }
    } else {
      final resp = await Supabase.instance.client.from('brands').select().eq('id', brandId).maybeSingle();
      if (resp != null) bp.setBrand(Brand.fromJson(resp));
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

  @override
  void dispose() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        if (userProvider.isLoading || userProvider.currentProfile == null) {
          return const Scaffold(backgroundColor: Color(0xFFF8F9FA), body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)));
        }

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
                                LensInventoryTab(simulatedBrandId: _simulatedBrandId),
                                AnalyticsTab(simulatedBrandId: _simulatedBrandId),
                                StoreManagementTab(simulatedBrandId: _simulatedBrandId),
                                const MarketingTab(),
                                const AuditTab(),
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
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final up = context.watch<UserProvider>();
    final isSuperAdmin = up.currentProfile?.brandId == 'admin';
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
          if (isSuperAdmin) _buildSidebarItem(4, Icons.security, '운영 감사'),
          const Spacer(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent, size: 27), title: const Text('로그아웃', style: TextStyle(color: Colors.redAccent, fontSize: 21, fontWeight: FontWeight.bold)), onTap: _logout, contentPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12)),
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
      onTap: () {
        _tabController.animateTo(index);
        setState(() {});
      },
    );
  }

  Widget _buildSlimTopBarWithTabs(BuildContext context, {required bool showTabs}) {
    final up = context.watch<UserProvider>();
    final isSuperAdmin = up.currentProfile?.brandId == 'admin';
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
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('B2B DATA PLATFORM', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)), Consumer<LensProvider>(builder: (c, lp, _) => Text('${lp.lenses.length}개의 리소스', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)))]),
              Row(children: [
                if (isSuperAdmin) ...[
                  Container(width: 250, padding: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)), child: DropdownButton<String?>(isExpanded: true, value: _simulatedBrandId, underline: const SizedBox(), hint: const Text('전체 브랜드 (Admin)'), items: _allBrands.map((b) => DropdownMenuItem<String?>(value: b['id'] as String?, child: Text(b['name'] as String))).toList(), onChanged: (val) async { setState(() => _simulatedBrandId = val); await _syncSimulatedTheme(val); })),
                  const SizedBox(width: 18),
                ],
                ElevatedButton.icon(onPressed: () => context.go('/admin/add${_simulatedBrandId != null ? '?brandId=$_simulatedBrandId' : ''}'), icon: const Icon(Icons.add, size: 24), label: const Text('새 렌즈 등록', style: TextStyle(fontSize: 21)), style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18))),
              ])
            ],
          ),
          const SizedBox(height: 24),
          if (showTabs) TabBar(controller: _tabController, labelColor: primaryColor, unselectedLabelColor: Colors.grey[600], indicatorColor: primaryColor, labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), tabs: [const Tab(text: '렌즈'), const Tab(text: '인사이트'), const Tab(text: '매장'), const Tab(text: '마케팅'), if (isSuperAdmin) const Tab(text: '감사')]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// 탭 컴포넌트 실제 구현

class LensInventoryTab extends StatefulWidget {
  final String? simulatedBrandId;
  const LensInventoryTab({super.key, this.simulatedBrandId});
  @override
  State<LensInventoryTab> createState() => _LensInventoryTabState();
}

class _LensInventoryTabState extends State<LensInventoryTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortOption = '최신순';
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<LensProvider>().loadMoreLenses();
    }
  }

  void _fetch() {
    final up = context.read<UserProvider>();
    context.read<LensProvider>().fetchLensesFromSupabase(brandId: widget.simulatedBrandId ?? up.currentProfile?.brandId);
  }

  @override
  void didUpdateWidget(LensInventoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.simulatedBrandId != widget.simulatedBrandId) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lp = context.watch<LensProvider>();
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    final targetBrandId = widget.simulatedBrandId ?? context.read<UserProvider>().currentProfile?.brandId;

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(36, 0, 36, 24), child: Row(children: [Expanded(child: TextField(controller: _searchController, readOnly: isOffline, decoration: InputDecoration(hintText: isOffline ? '네트워크 필요' : '렌즈명 검색', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12))), onChanged: (val) { setState(() => _searchQuery = val); _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 500), () { if (!mounted) return; context.read<LensProvider>().fetchLensesFromSupabase(brandId: targetBrandId, searchQuery: val.trim()); }); })), const SizedBox(width: 18), Container(padding: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)), child: DropdownButton<String>(value: _sortOption, underline: const SizedBox(), items: const [DropdownMenuItem(value: '최신순', child: Text('최신순')), DropdownMenuItem(value: '인기순', child: Text('인기순')), DropdownMenuItem(value: '이름순', child: Text('이름순'))], onChanged: isOffline ? null : (val) => setState(() { _sortOption = val!; context.read<LensProvider>().fetchLensesFromSupabase(brandId: targetBrandId, searchQuery: _searchQuery, sortOption: val); })))])),
      Expanded(child: lp.isLoading && lp.lenses.isEmpty ? const Center(child: CircularProgressIndicator()) : Padding(padding: const EdgeInsets.symmetric(horizontal: 36), child: GridView.builder(controller: _scrollController, cacheExtent: 300, gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, childAspectRatio: 0.8, crossAxisSpacing: 24, mainAxisSpacing: 24), itemCount: lp.lenses.length + (lp.hasMore ? 1 : 0), itemBuilder: (c, i) => i < lp.lenses.length ? _buildLensCard(lp.lenses[i], targetBrandId) : const Center(child: CircularProgressIndicator()))))
    ]);
  }

  Widget _buildLensCard(Lens lens, String? brandId) => InkWell(onDoubleTap: () => context.push('/admin/add?brandId=$brandId', extra: lens), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 195, height: 195, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black12, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))]), child: ClipOval(child: lens.thumbnailUrl.isNotEmpty ? CachedNetworkImage(imageUrl: lens.thumbnailUrl, fit: BoxFit.cover, cacheHeight: 400, cacheWidth: 400, placeholder: (context, url) => const BrandShimmer(shape: BoxShape.circle), errorWidget: (context, url, error) => const BrandImageError(size: 60)) : const Icon(Icons.image, color: Colors.black12, size: 75))), const SizedBox(height: 18), Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.black12)), child: Text(lens.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 19, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center))]));
}

class AnalyticsTab extends StatefulWidget {
  final String? simulatedBrandId;
  const AnalyticsTab({super.key, this.simulatedBrandId});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  int _total = 0;
  double _avg = 0.0;
  int _users = 0;
  List<int> _weekly = List.filled(7, 0);
  String _period = '이번 주';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final up = context.read<UserProvider>();
      final brandId = widget.simulatedBrandId ?? up.currentProfile?.brandId;
      final now = DateTime.now();
      DateTime gte = _period == '이번 주' ? now.subtract(const Duration(days: 6)) : (_period == '이번 달' ? DateTime(now.year, now.month, 1) : DateTime(2024, 1, 1));

      var q = supabase.from('activityLogs').select().gte('createdAt', gte.toIso8601String());
      if (brandId != null && brandId != 'admin') q = q.eq('brandId', brandId);
      final resp = await q;
      _logs = List<Map<String, dynamic>>.from(resp);

      final tryOns = _logs.where((l) => l['actionType'] == 'try_on' || l['actionType'] == 'select' || l['actionType'] == 'wear_session_sync').toList();
      _total = tryOns.length;
      final durs = _logs.where((l) => (l['durationMs'] as num?) != null && (l['durationMs'] as num) > 0).toList();
      _avg = durs.isNotEmpty ? (durs.fold<num>(0, (s, l) => s + (l['durationMs'] as num)) / durs.length) / 1000.0 : 0.0;
      _users = _logs.map((l) => l['userId'] ?? l['anonymousId']).toSet().length;

      _weekly = List.filled(7, 0);
      for (var l in tryOns) {
        final d = DateTime.parse(l['createdAt']).toLocal();
        final diff = now.difference(d).inDays;
        if (diff >= 0 && diff < 7) _weekly[6 - diff] += 1;
      }
    } catch (e) { debugPrint('Analytics Error: $e'); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final color = Theme.of(context).primaryColor;
    return SingleChildScrollView(padding: const EdgeInsets.all(36), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('인사이트 보고서', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)), DropdownButton<String>(value: _period, items: const [DropdownMenuItem(value: '이번 주', child: Text('이번 주')), DropdownMenuItem(value: '이번 달', child: Text('이번 달')), DropdownMenuItem(value: '전체', child: Text('전체'))], onChanged: (v) { setState(() => _period = v!); _fetch(); })]), const SizedBox(height: 48), Wrap(spacing: 24, runSpacing: 24, children: [_buildMetric('체험 수', '$_total', Icons.visibility, Colors.blue), _buildMetric('평균 시간', '${_avg.toStringAsFixed(1)}s', Icons.timer, Colors.green), _buildMetric('활성 유저', '$_users', Icons.people, Colors.purple)]), const SizedBox(height: 48), Container(height: 400, decoration: _box(), child: Padding(padding: const EdgeInsets.all(36), child: LineChart(_lineData(color))))]));
  }

  Widget _buildMetric(String t, String v, IconData i, Color c) => Container(width: 250, padding: const EdgeInsets.all(24), decoration: _box(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, color: c, size: 30), const SizedBox(height: 12), Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), Text(v, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900))]));
  LineChartData _lineData(Color c) => LineChartData(lineBarsData: [LineChartBarData(spots: List.generate(7, (i) => FlSpot(i.toDouble(), _weekly[i].toDouble())), isCurved: true, color: c, barWidth: 4, belowBarData: BarAreaData(show: true, color: c.withOpacity(0.1)))], titlesData: FlTitlesData(topTitles: const AxisTitles(), rightTitles: const AxisTitles(), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(DateFormat('MM/dd').format(DateTime.now().subtract(Duration(days: 6-v.toInt()))))))));
  BoxDecoration _box() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.05)));
}

class StoreManagementTab extends StatefulWidget {
  final String? simulatedBrandId;
  const StoreManagementTab({super.key, this.simulatedBrandId});
  @override
  State<StoreManagementTab> createState() => _StoreManagementTabState();
}

class _StoreManagementTabState extends State<StoreManagementTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    final up = context.read<UserProvider>();
    context.read<StoreProvider>().fetchStores(brandId: widget.simulatedBrandId ?? up.currentProfile?.brandId);
  }

  @override
  void didUpdateWidget(StoreManagementTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.simulatedBrandId != widget.simulatedBrandId) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sp = context.watch<StoreProvider>();
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    return Padding(padding: const EdgeInsets.all(36), child: ListView.builder(itemCount: sp.stores.length, itemBuilder: (c, i) { final s = sp.stores[i]; return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)), child: ListTile(title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), subtitle: Text(s.address), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: isOffline ? null : () => context.read<StoreProvider>().deleteStore(s.id)))); }));
  }
}

class MarketingTab extends StatefulWidget {
  const MarketingTab({super.key});
  @override
  State<MarketingTab> createState() => _MarketingTabState();
}

class _MarketingTabState extends State<MarketingTab> with AutomaticKeepAliveClientMixin {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bp = context.watch<BrandProvider>();
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    return SingleChildScrollView(padding: const EdgeInsets.all(48), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('마케팅 푸시 알림', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
      const SizedBox(height: 48),
      TextField(controller: _titleController, readOnly: isOffline, decoration: const InputDecoration(labelText: '알림 제목', border: OutlineInputBorder())),
      const SizedBox(height: 24),
      TextField(controller: _bodyController, readOnly: isOffline, maxLines: 4, decoration: const InputDecoration(labelText: '알림 내용', border: OutlineInputBorder())),
      const SizedBox(height: 36),
      ElevatedButton(onPressed: (isOffline || _busy) ? null : () async {
        if (_titleController.text.isEmpty) return;
        setState(() => _busy = true);
        await bp.savePushTemplate(_titleController.text, _bodyController.text);
        setState(() => _busy = false);
        _titleController.clear(); _bodyController.clear();
      }, child: const Text('전체 사용자에게 전송 및 템플릿 저장'))
    ]));
  }
}

class AuditTab extends StatefulWidget {
  const AuditTab({super.key});
  @override
  State<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<AuditTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final resp = await Supabase.instance.client.from('adminAuditLogs').select().order('timestamp', ascending: false).limit(50);
      _logs = List<Map<String, dynamic>>.from(resp);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(padding: const EdgeInsets.all(36), itemCount: _logs.length, itemBuilder: (c, i) {
      final l = _logs[i];
      final Map<String, dynamic> details = l['details'] is String ? jsonDecode(l['details']) : (l['details'] ?? {});
      final oldData = details['oldData'] as Map<String, dynamic>?;
      final newData = details['newData'] as Map<String, dynamic>?;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
        child: ExpansionTile(
          leading: Icon(l['action'].toString().contains('DELETE') ? Icons.delete_forever : Icons.security, color: l['action'].toString().contains('DELETE') ? Colors.red : Colors.blue),
          title: Text('[${l['action']}] ${l['adminName'] ?? "Admin"}'),
          subtitle: Text(l['timestamp']),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('상세 변경 내역 (Diff View)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 12),
                  // [Final 100.0%] 삭제 액션 전용 프리미엄 UI
                  if (l['action'].toString().contains('DELETE'))
                    _buildDeleteSummary(oldData)
                  else if (oldData != null || newData != null)
                    _buildDiffWidget(oldData, newData)
                  else
                    Text(const JsonEncoder.withIndent('  ').convert(details), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      );
    });
  }

  /// [Final 100.0%] 삭제 데이터 요약 뷰
  Widget _buildDeleteSummary(Map<String, dynamic>? old) {
    if (old == null) return const Text('삭제된 데이터 정보가 없습니다.');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18), SizedBox(width: 8), Text('데이터가 영구 삭제되었습니다.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
          const Divider(height: 24),
          ...old.entries.take(5).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${e.key}: ${e.value}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
          )),
          const Text('...외 모든 필드 삭제됨', style: TextStyle(color: Colors.black38, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildDiffWidget(Map<String, dynamic>? old, Map<String, dynamic>? @new) {
    final Set<String> keys = {...(old?.keys ?? {}), ...(@new?.keys ?? {})};
    List<Widget> rows = [];
    for (var k in keys) {
      if (k == 'requestId' || k == 'id' || k == 'createdAt') continue;
      final oldVal = old?[k], newVal = @new?[k];
      if (oldVal != newVal) {
        rows.add(Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 13), children: [TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: '${oldVal ?? "없음"}', style: TextStyle(color: Colors.red[300], decoration: TextDecoration.lineThrough)), const TextSpan(text: '  →  '), TextSpan(text: '${newVal ?? "삭제됨"}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold))]))));
      }
    }
    return rows.isEmpty ? const Text('변경된 주요 필드 없음') : Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}
