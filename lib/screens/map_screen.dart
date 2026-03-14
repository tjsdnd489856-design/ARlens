import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart'; 
import '../providers/brand_provider.dart';
import '../providers/store_provider.dart';
import '../models/store_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// [Grand Master] WidgetsBindingObserver 추가
class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLocationServiceEnabled = false;
  bool _isPermissionDenied = false; 
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // [Grand Master] 옵저버 등록
    _initMapData();
  }

  // [Grand Master] 앱 상태가 Resumed 될 때 권한 재체크
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isPermissionDenied) {
        _checkLocationPermission(); // 설정에서 돌아왔을 때 자동 갱신
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // [Grand Master] 옵저버 해제
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initMapData() async {
    await _checkLocationPermission();
    _loadStoreMarkers();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLocationServiceEnabled = false);
      return;
    }

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

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isLocationServiceEnabled = true;
        _isPermissionDenied = false;
      });
    }

    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(_currentPosition!.latitude, _currentPosition!.longitude)),
      );
    }
  }

  void _loadStoreMarkers() async {
    final brandId = context.read<BrandProvider>().currentBrand.id;
    await context.read<StoreProvider>().fetchStores(brandId: brandId, userPosition: _currentPosition);
    _updateMarkers();
  }

  void _updateMarkers() {
    final storeProvider = context.read<StoreProvider>();
    final brandColor = context.read<BrandProvider>().currentBrand.primaryColor;

    final filteredStores = storeProvider.stores.where((store) {
      if (_searchQuery.isEmpty) return true;
      return store.name.contains(_searchQuery) || store.address.contains(_searchQuery);
    }).toList();

    setState(() {
      _markers = filteredStores.map((store) {
        return Marker(
          markerId: MarkerId(store.id),
          position: LatLng(store.latitude, store.longitude),
          infoWindow: InfoWindow(title: store.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getHueFromColor(brandColor)),
          onTap: () => _showStoreDetail(store),
        );
      }).toSet();
    });

    if (filteredStores.isNotEmpty && _mapController != null) {
      if (filteredStores.length == 1) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(filteredStores.first.latitude, filteredStores.first.longitude), 15),
        );
      } else {
        LatLngBounds bounds = _getBounds(filteredStores);
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    }
  }

  LatLngBounds _getBounds(List<Store> stores) {
    double minLat = stores.first.latitude;
    double maxLat = stores.first.latitude;
    double minLng = stores.first.longitude;
    double maxLng = stores.first.longitude;
    for (var store in stores) {
      if (store.latitude < minLat) minLat = store.latitude;
      if (store.latitude > maxLat) maxLat = store.latitude;
      if (store.longitude < minLng) minLng = store.longitude;
      if (store.longitude > maxLng) maxLng = store.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  double _getHueFromColor(Color color) {
    HSVColor hsv = HSVColor.fromColor(color);
    return hsv.hue;
  }

  void _showStoreDetail(Store store) {
    final brandColor = context.read<BrandProvider>().currentBrand.primaryColor;
    String distanceText = '';
    if (_currentPosition != null) {
      double distance = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, store.latitude, store.longitude);
      distanceText = '${(distance / 1000).toStringAsFixed(1)}km';
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)), if (distanceText.isNotEmpty) Text('현재 위치에서 $distanceText', style: TextStyle(color: brandColor, fontSize: 14, fontWeight: FontWeight.w600))])),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [const Icon(Icons.location_on, color: Colors.grey, size: 16), const SizedBox(width: 8), Expanded(child: Text(store.address, style: const TextStyle(color: Colors.black54)))]),
            if (store.phone != null) ...[const SizedBox(height: 8), Row(children: [const Icon(Icons.phone, color: Colors.grey, size: 16), const SizedBox(width: 8), Text(store.phone!, style: const TextStyle(color: Colors.black54))])],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: () { if (store.phone != null) launchUrl(Uri.parse('tel:${store.phone}')); }, icon: const Icon(Icons.phone), label: const Text('전화 걸기', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: brandColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: () { launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${store.latitude},${store.longitude}')); }, icon: const Icon(Icons.directions), label: const Text('길찾기', style: TextStyle(fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(foregroundColor: brandColor, side: BorderSide(color: brandColor), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.watch<BrandProvider>().currentBrand;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: const CameraPosition(target: LatLng(37.5665, 126.9780), zoom: 12),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20, right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    Expanded(child: TextField(controller: _searchController, decoration: const InputDecoration(hintText: '매장명 또는 주소 검색', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)), onChanged: (value) { setState(() { _searchQuery = value; }); _updateMarkers(); })),
                    if (_searchQuery.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() { _searchQuery = ''; }); _updateMarkers(); }),
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),

          if (_isPermissionDenied)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off_rounded, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          const Text('위치 권한이 필요합니다', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('내 주변 매장을 찾기 위해 기기의 위치 권한을 허용해 주세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => openAppSettings(),
                            style: ElevatedButton.styleFrom(backgroundColor: brand.primaryColor, foregroundColor: Colors.white, shape: const StadiumBorder()),
                            child: const Text('설정으로 이동'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 30, right: 20,
            child: FloatingActionButton(onPressed: _checkLocationPermission, backgroundColor: Colors.white, child: Icon(Icons.my_location, color: brand.primaryColor)),
          ),
        ],
      ),
    );
  }
}
