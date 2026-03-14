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
import '../../providers/lens_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/brand_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../models/lens_model.dart';
import '../../models/brand_model.dart';
import '../../models/store_model.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    final up = context.read<UserProvider>();
    if (up.currentProfile?.brandId == 'admin') {
      final resp = await Supabase.instance.client.from('brands').select('id, name');
      setState(() {
        _allBrands = [{'id': null, 'name': '전체 브랜드'}, ...List<Map<String, dynamic>>.from(resp)];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final up = context.watch<UserProvider>();
    final isSuperAdmin = up.currentProfile?.brandId == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        title: const Text('Admin Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: [
            const Tab(text: '인벤토리'),
            const Tab(text: '인사이트'),
            const Tab(text: '매장 관리'),
            const Tab(text: '마케팅'),
            if (isSuperAdmin) const Tab(text: '감사 로그'),
          ],
        ),
        actions: [
          if (isSuperAdmin) 
            Container(
              width: 150,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DropdownButton<String?>(
                value: _simulatedBrandId,
                isExpanded: true,
                underline: const SizedBox(),
                hint: const Text('브랜드 선택', style: TextStyle(fontSize: 12)),
                items: _allBrands.map((b) => DropdownMenuItem<String?>(value: b['id'] as String?, child: Text(b['name'] as String, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) => setState(() => _simulatedBrandId = val),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () {
              Supabase.instance.client.auth.signOut();
              context.go('/');
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          LensInventoryTab(brandId: _simulatedBrandId),
          AnalyticsTab(brandId: _simulatedBrandId),
          StoreTab(brandId: _simulatedBrandId),
          const MarketingTab(),
          if (isSuperAdmin) const AuditTab(),
        ],
      ),
    );
  }
}

// --- Compact Inventory Tab ---
class LensInventoryTab extends StatefulWidget {
  final String? brandId;
  const LensInventoryTab({super.key, this.brandId});
  @override
  State<LensInventoryTab> createState() => _LensInventoryTabState();
}

class _LensInventoryTabState extends State<LensInventoryTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    final up = context.read<UserProvider>();
    context.read<LensProvider>().fetchLensesFromSupabase(brandId: widget.brandId ?? up.currentProfile?.brandId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lp = context.watch<LensProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: lp.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: lp.lenses.length,
            itemBuilder: (context, index) {
              final lens = lp.lenses[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
                child: Column(
                  children: [
                    Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: lens.thumbnailUrl.isNotEmpty ? CachedNetworkImage(imageUrl: lens.thumbnailUrl, fit: BoxFit.cover) : const Icon(Icons.image, size: 30))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(lens.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => context.push('/admin/add', extra: lens)),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => context.push('/admin/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Compact Analytics Tab ---
class AnalyticsTab extends StatefulWidget {
  final String? brandId;
  const AnalyticsTab({super.key, this.brandId});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  int _total = 0;
  List<int> _weekly = List.filled(7, 0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final up = context.read<UserProvider>();
    final targetId = widget.brandId ?? up.currentProfile?.brandId;
    final resp = await Supabase.instance.client.from('activityLogs').select().eq('brandId', targetId ?? '');
    final logs = List<Map<String, dynamic>>.from(resp);
    
    _total = logs.length;
    _weekly = List.generate(7, (index) => logs.where((l) => DateTime.parse(l['createdAt']).day == DateTime.now().subtract(Duration(days: 6 - index)).day).length);
    
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final primaryColor = Theme.of(context).primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetricCard('누적 체험', '$_total회', Colors.blue),
              const SizedBox(width: 12),
              _buildMetricCard('활성 유저', '12명', Colors.purple), // 예시
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 250, // 높이 축소
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
            child: LineChart(
              LineChartData(
                lineBarsData: [LineChartBarData(spots: List.generate(7, (i) => FlSpot(i.toDouble(), _weekly[i].toDouble())), isCurved: true, color: primaryColor, barWidth: 3, dotData: const FlDotData(show: false))],
                titlesData: const FlTitlesData(topTitles: AxisTitles(), rightTitles: AxisTitles(), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30))),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

// --- Compact Store Tab ---
class StoreTab extends StatefulWidget {
  final String? brandId;
  const StoreTab({super.key, this.brandId});
  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<StoreProvider>().fetchStores(brandId: widget.brandId ?? context.read<UserProvider>().currentProfile?.brandId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sp = context.watch<StoreProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sp.stores.length,
        itemBuilder: (context, index) {
          final s = sp.stores[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.black12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: Text(s.address, style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, size: 16),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}

// --- Compact Marketing Tab ---
class MarketingTab extends StatelessWidget {
  const MarketingTab({super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('푸시 알림 전송', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: '제목', isDense: true, contentPadding: EdgeInsets.all(12), border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const TextField(maxLines: 3, decoration: InputDecoration(labelText: '내용', isDense: true, contentPadding: EdgeInsets.all(12), border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: () {}, child: const Text('보내기', style: TextStyle(fontSize: 14)))),
        ],
      ),
    );
  }
}

// --- Compact Audit Tab ---
class AuditTab extends StatefulWidget {
  const AuditTab({super.key});
  @override
  State<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<AuditTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const Center(child: Text('감사 로그 (Compact 모드 준비 중)', style: TextStyle(fontSize: 12, color: Colors.grey)));
  }
}
