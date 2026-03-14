class Lens {
  final String id;
  final String name;
  final String description;
  final String thumbnailUrl;
  final String arTextureUrl;
  final List<String> tags;
  final int tryOnCount;
  final String brandId;
  final String createdAt;

  Lens({
    required this.id,
    required this.name,
    required this.description,
    required this.thumbnailUrl,
    required this.arTextureUrl,
    required this.tags,
    this.tryOnCount = 0,
    required this.brandId,
    required this.createdAt,
  });

  factory Lens.fromJson(Map<String, dynamic> json) {
    // [Ultimate Golden Master] snake_case / camelCase 하이브리드 방어 매핑 전면 적용
    return Lens(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: (json['thumbnailUrl'] ?? json['thumbnail_url']) as String? ?? '',
      arTextureUrl: (json['arTextureUrl'] ?? json['ar_texture_url']) as String? ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      tryOnCount: (json['tryOnCount'] ?? json['try_on_count']) as int? ?? 0,
      brandId: (json['brandId'] ?? json['brand_id']) as String? ?? 'admin',
      createdAt: (json['createdAt'] ?? json['created_at']) as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'arTextureUrl': arTextureUrl,
    'tags': tags,
    'tryOnCount': tryOnCount,
    'brandId': brandId,
  };

  Lens copyWith({int? tryOnCount}) {
    return Lens(
      id: id,
      name: name,
      description: description,
      thumbnailUrl: thumbnailUrl,
      arTextureUrl: arTextureUrl,
      tags: tags,
      tryOnCount: tryOnCount ?? this.tryOnCount,
      brandId: brandId,
      createdAt: createdAt,
    );
  }
}
