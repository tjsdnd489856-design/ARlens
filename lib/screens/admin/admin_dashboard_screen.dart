import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/lens_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/brand_provider.dart';
import '../../providers/store_provider.dart';
import '../../models/lens_model.dart';
import '../../models/store_model.dart';
import '../../services/report_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Set<String> _selectedTags = {};
  
  // 통계 데이터 상태
  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _activityLogs = [];
  Map<String, int> _ageDistribution = {};
  int _totalTryOns = 0;
  double _avgDurationSec = 0.0;
  int _activeUsers = 0;
  List<int> _weeklyTryOns = List.filled(7, 0);
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
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
      final sevenDaysAgo = now.subtract(const Duration(days: 6));

      var logsQuery = supabase
          .from('activity_logs')
          .select()
          .gte('created_at', sevenDaysAgo.toIso8601String());
          
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

      final tryOnLogs = _activityLogs.where((log) => 
        log['action_type'] == 'try_on' || log['action_type'] == 'select'
      ).toList();
      _totalTryOns = tryOnLogs.length;

      final durationLogs = _activityLogs.where((log) => 
        (log['duration_ms'] as num?) != null && (log['duration_ms'] as num) > 0
      ).toList();
      
      if (durationLogs.isNotEmpty) {
        final totalMs = durationLogs.fold<num>(0, (sum, log) => sum + (log['duration_ms'] as num));
        _avgDurationSec = (totalMs / durationLogs.length) / 1000.0;
      } else {
        _avgDurationSec = 0.0;
      }

      final uniqueUsers = <String>{};
      for (var log in _activityLogs) {
        final uid = log['user_id']?.toString() ?? log['anonymous_id']?.toString();
        if (uid != null) uniqueUsers.add(uid);
      }
      _activeUsers = uniqueUsers.length;

      _weeklyTryOns = List.filled(7, 0);
      for (var log in tryOnLogs) {
        final dateStr = log['created_at'] as String?;
        if (dateStr == null) continue;
        final date = DateTime.parse(dateStr).toLocal();
        final diff = now.difference(date).inDays;
        if (diff >= 0 && diff < 7) {
          _weeklyTryOns[6 - diff] += 1;
        }
      }

      _ageDistribution = {};
      for (var p in profiles) {
        final age = p['age_group'] as String?;
        if (age != null && age.isNotEmpty) {
          _ageDistribution[age] = (_ageDistribution[age] ?? 0) + 1;
        }
      }
      if (_ageDistribution.isEmpty) {
        _ageDistribution = {'10s': 15, '20s': 45, '30s': 25, '40s+': 10};
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _getKoreanAge(String age) {
    switch (age) {
      case '10s': return '10대';
      case '20s': return '20대';
      case '30s': return '30대';
      case '40s+': return '40대 이상';
      default: return age;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(context),
            Expanded(
              child: DefaultTabController(
                length: 3, 
                child: Column(
                  children: [
                    _buildSlimTopBarWithTabs(context),
                    Expanded(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildLensInventoryTab(context),
                          _buildAnalyticsTab(context),
                          _buildStoreManagementTab(context), 
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

  Widget _buildLensInventoryTab(BuildContext context) {
    return Column(
      children: [
        _buildInventoryInsights(context), 
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

  Widget _buildAnalyticsTab(BuildContext context) {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
    }

    final lensProvider = context.watch<LensProvider>();
    Lens? mostPopular;
    if (lensProvider.lenses.isNotEmpty) {
      mostPopular = lensProvider.lenses.reduce((a, b) => a.tryOnCount > b.tryOnCount ? a : b);
    }
    
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
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '데이터 새로고침',
                    onPressed: _initializeDashboard,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final brand = context.read<BrandProvider>().currentBrand;
                      final lenses = context.read<LensProvider>().lenses;
                      final stats = {
                        'totalTryOns': _totalTryOns,
                        'avgDuration': _avgDurationSec,
                        'activeUsers': _activeUsers,
                      };
                      await ReportService.instance.generateAndPrintBrandReport(
                        brand: brand,
                        lenses: lenses,
                        stats: stats,
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF 리포트 추출', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
              _buildMetricCard(title: '누적 체험 수', value: '$_totalTryOns', suffix: '회', icon: Icons.visibility, color: Colors.blueAccent),
              const SizedBox(width: 16),
              _buildMetricCard(title: '평균 착용 시간', value: _avgDurationSec.toStringAsFixed(1), suffix: 's', icon: Icons.timer, color: Colors.green),
              const SizedBox(width: 16),
              _buildMetricCard(title: '활성 유저', value: '$_activeUsers', suffix: '명', icon: Icons.people_alt, color: Colors.purpleAccent),
              const SizedBox(width: 16),
              _buildMetricCard(title: '가장 인기 있는 렌즈', value: mostPopular != null && mostPopular.tryOnCount > 0 ? mostPopular.name : '데이터 없음', suffix: '', icon: Icons.star, color: Colors.orangeAccent),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 350,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('최근 7일 착용 트렌드', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 32),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (value) => FlLine(color: Colors.black.withOpacity(0.05), strokeWidth: 1)),
                            titlesData: FlTitlesData(
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final now = DateTime.now();
                                    final date = now.subtract(Duration(days: 6 - value.toInt()));
                                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat('MM/dd').format(date), style: const TextStyle(color: Colors.black54, fontSize: 10)));
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(7, (index) => FlSpot(index.toDouble(), _weeklyTryOns[index].toDouble())),
                                isCurved: true,
                                color: primaryColor,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: primaryColor.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: Container(
                  height: 350,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('고객 연령대 분포', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 32),
                      Expanded(
                        child: _ageDistribution.isEmpty 
                        ? const Center(child: Text('데이터 없음', style: TextStyle(color: Colors.black38)))
                        : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: _getPieSections(primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _ageDistribution.keys.map((age) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: _getColorForAge(age, primaryColor), shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(_getKoreanAge(age), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            ],
                          );
                        }).toList(),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreManagementTab(BuildContext context) {
    final storeProvider = context.watch<StoreProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('오프라인 매장 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
              ElevatedButton.icon(
                onPressed: () => _showAddStoreDialog(context),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('신규 매장 등록'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: storeProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : storeProvider.stores.isEmpty
                    ? const Center(child: Text('등록된 매장이 없습니다.', style: TextStyle(color: Colors.black38)))
                    : ListView.builder(
                        itemCount: storeProvider.stores.length,
                        itemBuilder: (context, index) {
                          final store = storeProvider.stores[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            color: Colors.white,
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Icon(Icons.store, color: primaryColor)),
                              title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(store.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditStoreDialog(context, store)),
                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _showDeleteStoreDialog(context, store)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddStoreDialog(BuildContext context) {
    final userProfile = context.read<UserProvider>().currentProfile;
    final brandId = userProfile?.brandId ?? 'default';
    
    final nameController = TextEditingController();
    final addrController = TextEditingController();
    final phoneController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신규 매장 등록'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '매장명')),
              TextField(controller: addrController, decoration: const InputDecoration(labelText: '주소')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: '전화번호')),
              Row(
                children: [
                  Expanded(child: TextField(controller: latController, decoration: const InputDecoration(labelText: '위도(Lat)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: lngController, decoration: const InputDecoration(labelText: '경도(Lng)'), keyboardType: TextInputType.number)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              await context.read<StoreProvider>().addStore({
                'brand_id': brandId,
                'name': nameController.text,
                'address': addrController.text,
                'phone': phoneController.text,
                'latitude': double.parse(latController.text),
                'longitude': double.parse(lngController.text),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  void _showEditStoreDialog(BuildContext context, Store store) {
    final nameController = TextEditingController(text: store.name);
    final addrController = TextEditingController(text: store.address);
    final phoneController = TextEditingController(text: store.phone);
    final latController = TextEditingController(text: store.latitude.toString());
    final lngController = TextEditingController(text: store.longitude.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매장 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '매장명')),
              TextField(controller: addrController, decoration: const InputDecoration(labelText: '주소')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: '전화번호')),
              Row(
                children: [
                  Expanded(child: TextField(controller: latController, decoration: const InputDecoration(labelText: '위도(Lat)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: lngController, decoration: const InputDecoration(labelText: '경도(Lng)'), keyboardType: TextInputType.number)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              await context.read<StoreProvider>().updateStore(store.id, {
                'name': nameController.text,
                'address': addrController.text,
                'phone': phoneController.text,
                'latitude': double.parse(latController.text),
                'longitude': double.parse(lngController.text),
              }, brandId: store.brandId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDeleteStoreDialog(BuildContext context, Store store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매장 삭제'),
        content: Text('"${store.name}" 매장을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () async {
            await context.read<StoreProvider>().deleteStore(store.id, brandId: store.brandId);
            if (mounted) Navigator.pop(context);
          }, child: const Text('삭제', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Color _getColorForAge(String ageGroup, Color baseColor) {
    switch (ageGroup) {
      case '10s': return baseColor; 
      case '20s': return Colors.blueAccent;
      case '30s': return Colors.orangeAccent;
      case '40s+': return Colors.green;
      default: return Colors.grey;
    }
  }

  List<PieChartSectionData> _getPieSections(Color baseColor) {
    final total = _ageDistribution.values.fold(0, (sum, val) => sum + val);
    return _ageDistribution.entries.map((entry) {
      final value = entry.value;
      final percentage = (value / total * 100).toStringAsFixed(1);
      return PieChartSectionData(
        color: _getColorForAge(entry.key, baseColor),
        value: value.toDouble(),
        title: '$percentage%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildMetricCard({required String title, required String value, required String suffix, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold)),
                Icon(icon, color: color.withOpacity(0.7), size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(value, style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (suffix.isNotEmpty) Text(suffix, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryInsights(BuildContext context) {
    return Consumer<LensProvider>(
      builder: (context, lensProvider, child) {
        if (lensProvider.isLoading || lensProvider.lenses.isEmpty) {
          return const SizedBox.shrink();
        }

        final lenses = lensProvider.lenses;
        int totalTryOns = lenses.fold(0, (sum, lens) => sum + lens.tryOnCount);
        Lens? mostPopular = lenses.reduce((a, b) => a.tryOnCount > b.tryOnCount ? a : b);

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.05))),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.visibility, color: Colors.blueAccent, size: 20)),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("누적 체험 수", style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)), Text("$totalTryOns", style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900))]),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.05))),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.star, color: Colors.orangeAccent, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("가장 인기 있는 렌즈", style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)), Text(mostPopular.tryOnCount > 0 ? mostPopular.name : "데이터 없음", style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('필터', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (_selectedTags.isNotEmpty) TextButton(onPressed: () => setState(() => _selectedTags.clear()), child: const Text('모두 지우기', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<LensProvider>(
              builder: (context, lensProvider, child) {
                final allTags = lensProvider.lenses.expand((lens) => lens.tags).toSet().toList();
                allTags.sort();

                if (allTags.isEmpty) return const Center(child: Text('사용 가능한 태그 없음', style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: allTags.length,
                  itemBuilder: (context, index) {
                    final tag = allTags[index];
                    final isSelected = _selectedTags.contains(tag);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text('#$tag', style: TextStyle(fontSize: 14, color: isSelected ? Colors.black87 : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? value) { setState(() { if (value == true) _selectedTags.add(tag); else _selectedTags.remove(tag); }); },
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
              label: const Text('로그아웃', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 50), alignment: Alignment.centerLeft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlimTopBarWithTabs(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
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
                  const Text('B2B 데이터 플랫폼', style: TextStyle(color: Colors.black54, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Consumer<LensProvider>(
                    builder: (context, lp, child) => Text('${lp.lenses.length}개의 렌즈', style: const TextStyle(color: Color(0xFF2D2D2D), fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Pretendard')),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => context.go('/admin/add'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                child: const Row(children: [Icon(Icons.add, size: 20), SizedBox(width: 8), Text('새 렌즈 등록', style: TextStyle(fontWeight: FontWeight.bold))]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            labelColor: primaryColor, unselectedLabelColor: Colors.black38, indicatorColor: primaryColor, indicatorWeight: 3,
            tabs: const [Tab(text: '렌즈 관리'), Tab(text: '비즈니스 인사이트'), Tab(text: '매장 관리')],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16),
        itemCount: 8,
        itemBuilder: (context, index) => Shimmer.fromColors(baseColor: Colors.grey[200]!, highlightColor: Colors.grey[100]!, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear_outlined, size: 64, color: Colors.black12),
          SizedBox(height: 16),
          Text('선택한 필터와 일치하는 렌즈가 없습니다.', style: TextStyle(color: Colors.black38, fontSize: 16)),
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
          color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(child: CachedNetworkImage(imageUrl: widget.lens.thumbnailUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: const Color(0xFFF1F3F5)), errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.grey))),
              if (widget.lens.tryOnCount > 0)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.visibility, color: Colors.white, size: 12), const SizedBox(width: 4), Text('${widget.lens.tryOnCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]),
                  ),
                ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(0.7)])),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.lens.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: widget.lens.tags.map((tag) => Padding(padding: const EdgeInsets.only(right: 4), child: Text('#$tag', style: const TextStyle(color: Colors.white70, fontSize: 10)))).toList())),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8, right: 8,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200), opacity: _isHovered ? 1.0 : 0.0,
                  child: Row(children: [_buildRoundAction(icon: Icons.edit_outlined, color: const Color(0xFF2D2D2D), onTap: () => _showEditDialog(context, widget.lens)), const SizedBox(width: 4), _buildRoundAction(icon: Icons.delete_outline_rounded, color: Colors.redAccent, onTap: () => _showDeleteDialog(context, widget.lens))]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundAction({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]), child: Icon(icon, color: color, size: 14)),
    );
  }

  void _showDeleteDialog(BuildContext context, Lens lens) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, surfaceTintColor: Colors.white,
        title: const Text('렌즈 삭제', style: TextStyle(color: Color(0xFF2D2D2D))), content: Text('"${lens.name}" 렌즈를 삭제하시겠습니까?', style: const TextStyle(color: Colors.black54)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.black38))), TextButton(onPressed: () async { Navigator.pop(context); await context.read<LensProvider>().deleteLens(lens); }, child: const Text('삭제', style: TextStyle(color: Colors.redAccent)))],
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
        backgroundColor: Colors.white, surfaceTintColor: Colors.white, title: const Text('렌즈 수정', style: TextStyle(color: Color(0xFF2D2D2D))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, style: const TextStyle(color: Color(0xFF2D2D2D)), decoration: InputDecoration(labelText: '이름', labelStyle: const TextStyle(color: Colors.black38), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.1))))),
              const SizedBox(height: 16),
              TextField(controller: descController, maxLines: 3, style: const TextStyle(color: Color(0xFF2D2D2D)), decoration: InputDecoration(labelText: '설명', labelStyle: const TextStyle(color: Colors.black38), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.1))))),
              const SizedBox(height: 16),
              TextField(controller: tagsController, style: const TextStyle(color: Color(0xFF2D2D2D)), decoration: InputDecoration(labelText: '태그 (쉼표로 구분)', labelStyle: const TextStyle(color: Colors.black38), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.1))))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.black38))),
          ElevatedButton(
            onPressed: () async {
              final updatedTags = tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              await context.read<LensProvider>().updateLens(lens.id, {'name': nameController.text, 'description': descController.text, 'tags': updatedTags});
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2D2D), foregroundColor: Colors.white), child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
