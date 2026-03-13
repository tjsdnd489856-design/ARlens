import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  GeocodingService._privateConstructor();
  static final GeocodingService _instance = GeocodingService._privateConstructor();
  static GeocodingService get instance => _instance;

  final String _baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  /// 주소를 위도와 경도로 변환합니다.
  Future<LatLng?> getLatLngFromAddress(String address) async {
    if (address.isEmpty) return null;

    final String apiKey = dotenv.get('GOOGLE_MAPS_API_KEY_ANDROID');
    final Uri url = Uri.parse('$_baseUrl?address=${Uri.encodeComponent(address)}&key=$apiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          final double lat = location['lat'];
          final double lng = location['lng'];
          debugPrint('📍 [Geocoding] Success: $address -> ($lat, $lng)');
          return LatLng(lat, lng);
        } else {
          debugPrint('⚠️ [Geocoding] No results found for: $address (Status: ${data['status']})');
          return null;
        }
      } else {
        debugPrint('❌ [Geocoding] HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [Geocoding] Exception: $e');
      return null;
    }
  }
}
