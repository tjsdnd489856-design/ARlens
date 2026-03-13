import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/brand_provider.dart';
import '../providers/store_provider.dart';
import '../models/store_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLocationServiceEnabled = false;
  
  Set<Marker> _markers = {};
  List<Store> _filteredStores = []; // 검색된 매장 리스트
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  Future<void> _initMapData() async {
    await _checkLocationPermission();
    _loadStoreMarkers();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = pos;
      _isLocationServiceEnabled = true;
    });

    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          14,
        ),
      );
    }
  }

  void _loadStoreMarkers() async {
    final brandId = context.read<BrandProvider>().currentBrand.id;
    final storeProvider = context.read<StoreProvider>();
    
    await storeProvider.fetchStores(brandId: brandId, userPosition: _currentPosition);
    
    setState(() {
      _filteredStores = storeProvider.stores;
      _updateMarkers();
    });
  }

  void _updateMarkers() {
    final brandColor = context.read<BrandProvider>().currentBrand.primaryColor;
    setState(() {
      _markers = _filteredStores.map((store) {
        return Marker(
          markerId: MarkerId(store.id),
          position: LatLng(store.latitude, store.longitude),
          infoWindow: InfoWindow(title: store.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getHueFromColor(brandColor),
          ),
          onTap: () => _showStoreDetail(store),
        );
      }).toSet();
    });
  }

  void _filterStores(String query) {
    final storeProvider = context.read<StoreProvider>();
    setState(() {
      if (query.isEmpty) {
        _filteredStores = storeProvider.stores;
      } else {
        _filteredStores = storeProvider.stores.where((store) {
          return store.name.contains(query) || store.address.contains(query);
        }).toList();
      }
      _updateMarkers();
      
      // 검색 결과가 있으면 첫 번째 결과로 카메라 이동
      if (_filteredStores.isNotEmpty && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_filteredStores[0].latitude, _filteredStores[0].longitude),
            15,
          ),
        );
      }
    });
  }

  double _getHueFromColor(Color color) {
    HSVColor hsv = HSVColor.fromColor(color);
    return hsv.hue;
  }

  void _showStoreDetail(Store store) {
    final brandColor = context.read<BrandProvider>().currentBrand.primaryColor;
    
    String distanceText = '';
    if (_currentPosition != null) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        store.latitude, store.longitude
      );
      distanceText = (distance / 1000).toStringAsFixed(1) + 'km';
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      if (distanceText.isNotEmpty)
                        Text(
                          '현재 위치에서 $distanceText',
                          style: TextStyle(color: brandColor, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(store.address, style: const TextStyle(color: Colors.black54))),
              ],
            ),
            if (store.phone != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(store.phone!, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (store.phone != null) {
                        launchUrl(Uri.parse('tel:${store.phone}'));
                      }
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('전화 걸기', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${store.latitude},${store.longitude}'));
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('길찾기', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: brandColor,
                      side: BorderSide(color: brandColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
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
      appBar: AppBar(
        title: Text('${brand.name} 매장 찾기', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. 구글 맵
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(37.5665, 126.9780), // 서울 기준
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. 상단 검색 바
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterStores,
                decoration: InputDecoration(
                  hintText: '매장명 또는 주소 검색',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filterStores('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // 3. 내 위치 버튼
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: _checkLocationPermission,
              backgroundColor: Colors.white,
              child: Icon(Icons.my_location, color: brand.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
