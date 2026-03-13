import 'package:flutter/material.dart';

class Brand {
  final String id;
  final String name;
  final String? logoUrl;
  final Color primaryColor;
  final String? tagline;
  final List<Map<String, String>> pushTemplates; // [V1.1] 푸시 템플릿 저장

  const Brand({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.primaryColor,
    this.tagline,
    this.pushTemplates = const [],
  });

  static const Brand defaultBrand = Brand(
    id: 'default',
    name: 'ARlens',
    primaryColor: Colors.pinkAccent,
    tagline: 'Make your moments magical',
    pushTemplates: [],
  );

  factory Brand.fromJson(Map<String, dynamic> json) {
    Color parseColor(String? hexString) {
      if (hexString == null || hexString.isEmpty) return Colors.pinkAccent;
      String hexColor = hexString.replaceAll("#", "");
      if (hexColor.length == 6) hexColor = "FF$hexColor";
      if (hexColor.length == 8) return Color(int.parse("0x$hexColor"));
      return Colors.pinkAccent;
    }

    return Brand(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Brand',
      logoUrl: json['logoUrl'] as String?,
      primaryColor: parseColor(json['primaryColor'] as String?),
      tagline: json['tagline'] as String?,
      pushTemplates: (json['push_templates'] as List?)
          ?.map((e) => Map<String, String>.from(e as Map))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'primaryColor': '#${primaryColor.value.toRadixString(16).substring(2).toUpperCase()}',
      'tagline': tagline,
      'push_templates': pushTemplates,
    };
  }

  Brand copyWith({
    String? name,
    String? logoUrl,
    Color? primaryColor,
    String? tagline,
    List<Map<String, String>>? pushTemplates,
  }) {
    return Brand(
      id: id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      tagline: tagline ?? this.tagline,
      pushTemplates: pushTemplates ?? this.pushTemplates,
    );
  }
}
