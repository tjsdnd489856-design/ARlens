import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'dart:async';
import '../providers/brand_provider.dart';
import '../providers/store_provider.dart';
import '../models/store_model.dart';
import '../services/geocoding_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isPermissionDenied = false; 
  StreamSubscription<Position>? _positionStream; // [Final v2] 실시간 위치 구독
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<Marker> _markers = {};
  bool _noResultsFound = false; 

  List<String> _autocompleteSuggestions = [];
  Timer? _debounceTimer;

  List<Store> _closestSuggestions = [];
  LatLng? _lastMapCenter;
  Store? _selectedStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _initMapData();
  }

  @override
  void dispose() {
    _positionStream?.cancel(); // [Final v2] 스트림 해제
    WidgetsBinding.instance.removeObserver(this); 
    _searchController.dispose();
    _mapController?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initMapData() async {
    await _checkLocationPermission();
    _loadStoreMarkers();
    _startLocationUpdates(); // [Final v2] 실시간 추적 시작
  }

  /// [Final Golden Master v2] 실시간 위치 스트림 및 디바운스 정렬
  void _startLocationUpdates() {
    const locationSettings = LocationSettings(accuracy: LocationAccuracy.balanced, distanceFilter: 100);
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (mounted && _selectedStore == null) {
        setState(() { _currentPosition = position; });
        _updateMarkers(); // 위치 변화에 따른 실시간 정렬
      }
    });
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isPermissionDenied = true);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isPermissionDenied = true);
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() { _currentPosition = pos; _isPermissionDenied = false; });
    } catch (e) { debugPrint('Location error: $e'); }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.length < 2) {
      if (mounted) setState(() { _autocompleteSuggestions = []; _noResultsFound = false; });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final suggestions = await GeocodingService.instance.getAutocompleteSuggestions(query);
        if (mounted) setState(() => _autocompleteSuggestions = suggestions);
      } catch (e) { debugPrint('Autocomplete Error: $e'); }
    });
  }

  Future<void> _selectSuggestion(String address) async {
    if (!mounted) return;
    _searchController.text = address;
    setState(() { _searchQuery = address; _autocompleteSuggestions = []; _selectedStore = null; });
    final LatLng? coords = await GeocodingService.instance.getLatLngFromAddress(address);
    if (coords != null && _mapController != null && mounted) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(coords, 15));
      _updateMarkers(centerOverride: coords);
    }
  }

  void _loadStoreMarkers() async {
    final brandId = context.read<BrandProvider>().currentBrand.id;
    await context.read<StoreProvider>().fetchStores(brandId: brandId);
    _updateMarkers();
  }

  void _updateMarkers({LatLng? centerOverride}) {
    final storeProvider = context.read<StoreProvider>();
    final brandColor = context.read<BrandProvider>().currentBrand.primaryColor;

    List<Store> filteredStores = storeProvider.stores.where((store) {
      if (_searchQuery.isEmpty) return true;
      return store.name.contains(_searchQuery) || store.address.contains(_searchQuery);
    }).toList();

    // 컨텍스트 가중치 정렬 (검색 중이면 검색 중심, 평소엔 GPS 우선)
    final double? refLat = centerOverride?.latitude ?? _currentPosition?.latitude ?? _lastMapCenter?.latitude;
    final double? refLng = centerOverride?.longitude ?? _currentPosition?.longitude ?? _lastMapCenter?.longitude;

    if (refLat != null && refLng != null) {
      filteredStores.sort((a, b) {
        if (_selectedStore?.id == a.id) return -1;
        if (_selectedStore?.id == b.id) return 1;
        double distA = Geolocator.distanceBetween(refLat, refLng, a.latitude, a.longitude);
        double distB = Geolocator.distanceBetween(refLat, refLng, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
    } else {
      filteredStores.sort((a, b) => a.name.compareTo(b.name));
    }

    if (mounted) {
      setState(() {
        _noResultsFound = filteredStores.isEmpty && _searchQuery.isNotEmpty;
        if (_noResultsFound && refLat != null && refLng != null) {
          final List<Store> allSorted = List<Store>.from(storeProvider.stores)
            ..sort((a, b) => Geolocator.distanceBetween(refLat, refLng, a.latitude, a.longitude).compareTo(Geolocator.distanceBetween(refLat, refLng, b.latitude, b.longitude)));
          _closestSuggestions = allSorted.take(3).toList();
        } else { _closestSuggestions = []; }
        _markers = filteredStores.map((store) => Marker(markerId: MarkerId(store.id), position: LatLng(store.latitude, store.longitude), infoWindow: InfoWindow(title: store.name), icon: BitmapDescriptor.defaultMarkerWithHue(HSVColor.fromColor(brandColor).hue), onTap: () => _showStoreDetail(store, refLat: refLat, refLng: refLng))).toSet();
      });
    }
  }

  void _showStoreDetail(Store store, {double? refLat, double? refLng}) {
    final brandColor = context.read<BrandProvider>().currentBrand.primaryColor;
    setState(() { _selectedStore = store; }); 

    String distanceText = '';
    final double? lat = refLat ?? _currentPosition?.latitude ?? _lastMapCenter?.latitude;
    final double? lng = refLng ?? _currentPosition?.longitude ?? _lastMapCenter?.longitude;
    if (lat != null && lng != null) {
      double distance = Geolocator.distanceBetween(lat, lng, store.latitude, store.longitude);
      distanceText = '${(distance / 1000).toStringAsFixed(1)}km';
    }
    
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)), if (distanceText.isNotEmpty) Text(_currentPosition != null && _searchQuery.isEmpty ? '내 위치 기준 $distanceText' : '지도 중심 기준 $distanceText', style: TextStyle(color: brandColor, fontSize: 14, fontWeight: FontWeight.w600))])), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]), const SizedBox(height: 16), Row(children: [const Icon(Icons.location_on, color: Colors.grey, size: 16), const SizedBox(width: 8), Expanded(child: Text(store.address, style: const TextStyle(color: Colors.black54)))]), const SizedBox(height: 32), Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () async { final url = Uri.parse('tel:${store.phone}'); if (await canLaunchUrl(url)) await launchUrl(url); }, icon: const Icon(Icons.phone), label: const Text('전화 걸기'), style: ElevatedButton.styleFrom(backgroundColor: brandColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: () async { final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${store.latitude},${store.longitude}'); if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.directions), label: const Text('길찾기'), style: OutlinedButton.styleFrom(foregroundColor: brandColor, side: BorderSide(color: brandColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))]), const SizedBox(height: 16)])));
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.watch<BrandProvider>().currentBrand;
    return Scaffold(
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c, 
            initialCameraPosition: const CameraPosition(target: LatLng(37.5665, 126.9780), zoom: 12), 
            markers: _markers, myLocationEnabled: true, myLocationButtonEnabled: false, zoomControlsEnabled: false, mapToolbarEnabled: false,
            onCameraIdle: () async {
              if (_mapController != null) {
                final LatLng center = await _mapController!.getLatLng(ScreenCoordinate(x: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio / 2).toInt(), y: (MediaQuery.of(context).size.height * MediaQuery.of(context).devicePixelRatio / 2).toInt()));
                if (_selectedStore != null) {
                  double moveDist = Geolocator.distanceBetween(center.latitude, center.longitude, _selectedStore!.latitude, _selectedStore!.longitude);
                  if (moveDist > 5000) {
                    setState(() { _selectedStore = null; });
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('검색 범위가 재설정되었습니다.'), duration: Duration(seconds: 2)));
                  }
                }
                _lastMapCenter = center;
                if (_selectedStore == null) _updateMarkers(centerOverride: center);
              }
            },
          ),
          Positioned(top: MediaQuery.of(context).padding.top + 16, left: 20, right: 20, child: Column(children: [
            Card(elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Row(children: [IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)), Expanded(child: TextField(controller: _searchController, decoration: const InputDecoration(hintText: '매장명 또는 주소 검색', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)), onChanged: _onSearchChanged, onSubmitted: (val) { if (!mounted) return; setState(() { _searchQuery = val; _autocompleteSuggestions = []; _selectedStore = null; }); _updateMarkers(); })), if (_searchQuery.isNotEmpty || _selectedStore != null) IconButton(icon: const Icon(Icons.clear), onPressed: () { if (!mounted) return; _searchController.clear(); setState(() { _searchQuery = ''; _noResultsFound = false; _autocompleteSuggestions = []; _selectedStore = null; }); _updateMarkers(); }), const Icon(Icons.search, color: Colors.grey), const SizedBox(width: 12)]))),
            
            // [Final v2] AnimatedSwitcher를 통한 묵직한 상태 전환
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedStore != null 
                ? Padding(key: const ValueKey('locked'), padding: const EdgeInsets.only(top: 8), child: ActionChip(avatar: const Icon(Icons.lock, size: 16, color: Colors.white), label: Text('${_selectedStore!.name} 고정 중'), backgroundColor: brand.primaryColor, onPressed: () => setState(() { _selectedStore = null; _updateMarkers(); })))
                : _searchQuery.isEmpty 
                  ? Padding(key: const ValueKey('unlocked'), padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.sort, color: brand.primaryColor, size: 16), const SizedBox(width: 8), Text(_currentPosition != null ? '현재 내 위치 기준 거리순' : '지도 중심점 기준 거리순', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)) text)])))
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
            
            if (_autocompleteSuggestions.isNotEmpty) Container(margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: ListView.separated(shrinkWrap: true, padding: EdgeInsets.zero, itemCount: _autocompleteSuggestions.length, separatorBuilder: (c, i) => const Divider(height: 1), itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.location_on_outlined, size: 20), title: Text(_autocompleteSuggestions[i], style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _selectSuggestion(_autocompleteSuggestions[i])))),
            if (_noResultsFound && _autocompleteSuggestions.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Card(color: Colors.white.withOpacity(0.95), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [const Text('이 지역에는 매장이 없습니다.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12), if (_closestSuggestions.isEmpty) const Text('매장 정보가 없습니다.', style: TextStyle(color: Colors.grey)) else Column(children: _closestSuggestions.map((s) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: brand.primaryColor.withOpacity(0.1), child: Icon(Icons.store, color: brand.primaryColor, size: 20)), title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), subtitle: Text(s.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)), onTap: () { _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(s.latitude, s.longitude), 15)); _showStoreDetail(s); })).toList())]))))
          ])),
          if (_isPermissionDenied) Positioned.fill(child: Container(color: Colors.black54, child: Center(child: Card(margin: const EdgeInsets.symmetric(horizontal: 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_off_rounded, size: 48, color: Colors.redAccent), const SizedBox(height: 16), const Text('위치 권한 필요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('가까운 매장을 찾기 위해 위치 권한을 허용해 주세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)), const SizedBox(height: 24), ElevatedButton(onPressed: () => openAppSettings(), style: ElevatedButton.styleFrom(backgroundColor: brand.primaryColor, foregroundColor: Colors.white, shape: const StadiumBorder()), child: const Text('설정으로 이동'))])))))),
          Positioned(bottom: 30, right: 20, child: FloatingActionButton(onPressed: _checkLocationPermission, backgroundColor: Colors.white, child: Icon(Icons.my_location, color: brand.primaryColor))),
        ],
      ),
    );
  }
}
