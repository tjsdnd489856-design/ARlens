class Lens {
  final String id;
  final String name;
  final String description;
  final List<String> tags;
  final String thumbnailUrl;
  final String arTextureUrl;
  final String? createdAt;
  final String? brandId;
  final int tryOnCount;
  
  // [신규] 하이퍼 리얼리즘 렌더링 설정
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

  Lens copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? tags,
    String? thumbnailUrl,
    String? arTextureUrl,
    String? createdAt,
    String? brandId,
    int? tryOnCount,
    double? opacity,
    String? blendingMode,
  }) {
    return Lens(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      arTextureUrl: arTextureUrl ?? this.arTextureUrl,
      createdAt: createdAt ?? this.createdAt,
      brandId: brandId ?? this.brandId,
      tryOnCount: tryOnCount ?? this.tryOnCount,
      opacity: opacity ?? this.opacity,
      blendingMode: blendingMode ?? this.blendingMode,
    );
  }

  factory Lens.fromJson(Map<String, dynamic> json) {
    return Lens(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      arTextureUrl: json['arTextureUrl'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      brandId: json['brandId'] as String?,
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
      'thumbnailUrl': thumbnailUrl,
      'arTextureUrl': arTextureUrl,
      'createdAt': createdAt,
      'brandId': brandId,
      'try_on_count': tryOnCount,
      'opacity': opacity,
      'blending_mode': blendingMode,
    };
  }
}
