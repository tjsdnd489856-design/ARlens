class Lens {
  final String id;
  final String name;
  final String description;
  final List<String> tags;
  final String thumbnailUrl;
  final String arTextureUrl;

  Lens({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    required this.thumbnailUrl,
    required this.arTextureUrl,
  });

  // 파이어베이스(Firestore) 등에서 가져온 JSON 데이터를 Lens 객체로 변환
  factory Lens.fromJson(Map<String, dynamic> json) {
    return Lens(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      arTextureUrl: json['arTextureUrl'] as String? ?? '',
    );
  }

  // Lens 객체를 다시 JSON 형태로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'tags': tags,
      'thumbnailUrl': thumbnailUrl,
      'arTextureUrl': arTextureUrl,
    };
  }
}
