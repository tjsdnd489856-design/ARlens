class Lens {
  final String id;
  final String name;
  final String description;
  final List<String> tags;
  final String thumbnailUrl;
  final String arTextureUrl;
  final String? createdAt;
  final String? brandId; // [교정] 앱 내에서는 camelCase 사용
  final int tryOnCount;
  final double opacity;
  final String blendingMode;

  Lens({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    required this.thumbnailUrl,
    required this.arTextureUrl,
    this.createdAt,
    this.brandId,
    this.tryOnCount = 0,
    this.opacity = 0.8,
    this.blendingMode = 'modulate',
  });

  factory Lens.fromJson(Map<String, dynamic> json) {
    return Lens(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      tags: List<String>.from(json['tags'] ?? []),
      thumbnailUrl: json['thumbnailUrl'] as String? ?? json['thumbnail_url'] as String? ?? '', // [교정] 호환성
      arTextureUrl: json['arTextureUrl'] as String? ?? json['ar_texture_url'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      brandId: json['brandId'] as String? ?? json['brand_id'] as String?, // [교정] 스키마 불일치 방지
      tryOnCount: json['try_on_count'] as int? ?? 0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.8,
      blendingMode: json['blending_mode'] as String? ?? 'modulate',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'tags': tags,
      'thumbnail_url': thumbnailUrl, // [교정] DB 삽입 시 snake_case 강제
      'ar_texture_url': arTextureUrl,
      'created_at': createdAt,
      'brand_id': brandId,
      'try_on_count': tryOnCount,
      'opacity': opacity,
      'blending_mode': blendingMode,
    };
  }

  Lens copyWith({int? tryOnCount}) {
    return Lens(
      id: id,
      name: name,
      description: description,
      tags: tags,
      thumbnailUrl: thumbnailUrl,
      arTextureUrl: arTextureUrl,
      createdAt: createdAt,
      brandId: brandId,
      tryOnCount: tryOnCount ?? this.tryOnCount,
      opacity: opacity,
      blendingMode: blendingMode,
    );
  }
}
