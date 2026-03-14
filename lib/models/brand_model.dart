import 'package:flutter/material.dart';

class Brand {
  final String id;
  final String name;
  final Color primaryColor;
  final String? logoUrl;
  final String? tagline;
  final List<Map<String, String>> pushTemplates;

  Brand({
    required this.id,
    required this.name,
    required this.primaryColor,
    this.logoUrl,
    this.tagline,
    this.pushTemplates = const [],
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    // [Final Golden Master] snake_case와 camelCase를 완벽하게 수용하는 하이브리드 매핑
    final colorData = json['primaryColor'] ?? json['primary_color'];
    final logoData = json['logoUrl'] ?? json['logo_url'];
    final taglineData = json['tagline']; // tagline은 보통 단일어
    final templatesData = json['pushTemplates'] ?? json['push_templates'] ?? [];

    return Brand(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'ARlens',
      primaryColor: colorData != null ? _parseColor(colorData) : Colors.pinkAccent,
      logoUrl: logoData as String?,
      tagline: taglineData as String?,
      pushTemplates: (templatesData as List)
          .map<Map<String, String>>((item) => {
                'title': (item['title'] ?? '').toString(),
                'body': (item['body'] ?? '').toString(),
              })
          .toList(),
    );
  }

  static Color _parseColor(dynamic colorData) {
    if (colorData is int) return Color(colorData);
    if (colorData is String) {
      final hexCode = colorData.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    }
    return Colors.pinkAccent;
  }

  Brand copyWith({
    String? name,
    Color? primaryColor,
    String? logoUrl,
    String? tagline,
    List<Map<String, String>>? pushTemplates,
  }) {
    return Brand(
      id: id,
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      logoUrl: logoUrl ?? this.logoUrl,
      tagline: tagline ?? this.tagline,
      pushTemplates: pushTemplates ?? this.pushTemplates,
    );
  }
}
