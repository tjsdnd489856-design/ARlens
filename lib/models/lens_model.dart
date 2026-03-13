class Lens {
  final String id;
  final String name;
  final String description;
  final List<String> tags;
  final String thumbnailUrl;
  final String arTextureUrl;
  final String? createdAt;
  final String? brandId;
  final int tryOnCount; // 착용 횟수 필드 추가

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
  });

  // 깊은 복사를 위한 copyWith 메서드 추가
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
    };
  }
}
