class Store {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String brandId;

  Store({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    required this.brandId,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    // [The Masterpiece] DB 필드명 혼용 완벽 방어 매핑
    return Store(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      phone: json['phone'] as String?,
      brandId: (json['brandId'] ?? json['brand_id']) as String? ?? 'admin',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'phone': phone,
    'brandId': brandId,
  };
}
