import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  GeocodingService._privateConstructor();
  static final GeocodingService _instance = GeocodingService._privateConstructor();
  static GeocodingService get instance => _instance;

  final String _geocodeBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  final String _placesBaseUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  /// [신규] Google Places API를 사용한 주소 자동완성 제안
  Future<List<String>> getAutocompleteSuggestions(String input) async {
    if (input.isEmpty || input.length < 2) return [];

    final String apiKey = dotenv.get('GOOGLE_MAPS_SERVER_API_KEY');
    // 한국 매장 위주이므로 components=country:kr 옵션 추가 권장
    final Uri url = Uri.parse(
      '$_placesBaseUrl?input=${Uri.encodeComponent(input)}&key=$apiKey&language=ko&components=country:kr'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final List predictions = data['predictions'];
          return predictions.map((p) => p['description'] as String).toList();
        } else if (data['status'] == 'ZERO_RESULTS') {
          return [];
        } else {
          debugPrint('⚠️ [Places API] Error Status: ${data['status']}');
          return [];
        }
      } else {
        debugPrint('❌ [Places API] HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ [Places API] Exception: $e');
      return [];
    }
  }

  /// 주소를 위도와 경도로 변환합니다. (통합 서버 키 사용)
  Future<LatLng?> getLatLngFromAddress(String address) async {
    if (address.isEmpty) return null;

    final String apiKey = dotenv.get('GOOGLE_MAPS_SERVER_API_KEY');
    final Uri url = Uri.parse('$_geocodeBaseUrl?address=${Uri.encodeComponent(address)}&key=$apiKey&language=ko');

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
          debugPrint('⚠️ [Geocoding] No results: $address (Status: ${data['status']})');
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
