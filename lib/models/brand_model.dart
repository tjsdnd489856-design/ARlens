import 'package:flutter/material.dart';

class Brand {
  final String id;
  final String name;
  final String? logoUrl;
  final Color primaryColor;
  final String? tagline;

  const Brand({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.primaryColor,
    this.tagline,
  });

  // 기본 ARlens 브랜드 상태
  static const Brand defaultBrand = Brand(
    id: 'default',
    name: 'ARlens',
    primaryColor: Colors.pinkAccent,
    tagline: 'Make your moments magical',
  );

  // JSON 변환 (Supabase 연동을 위한 준비)
  factory Brand.fromJson(Map<String, dynamic> json) {
    // Hex Color 변환 로직 (# 제거 후 0xFF 추가)
    Color parseColor(String? hexString) {
      if (hexString == null || hexString.isEmpty) return Colors.pinkAccent;
      String hexColor = hexString.replaceAll("#", "");
      if (hexColor.length == 6) {
        hexColor = "FF$hexColor";
      }
      if (hexColor.length == 8) {
        return Color(int.parse("0x$hexColor"));
      }
      return Colors.pinkAccent;
    }

    return Brand(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Brand',
      logoUrl: json['logoUrl'] as String?,
      primaryColor: parseColor(json['primaryColor'] as String?),
      tagline: json['tagline'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'primaryColor': '#${primaryColor.value.toRadixString(16).substring(2).toUpperCase()}',
      'tagline': tagline,
    };
  }
}
