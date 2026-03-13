class Store {
  final String id;
  final String brandId;
  final String name;
  final String address;
  final String? phone;
  final double latitude;
  final double longitude;
  final String? createdAt;

  Store({
    required this.id,
    required this.brandId,
    required this.name,
    required this.address,
    this.phone,
    required this.latitude,
    required this.longitude,
    this.createdAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      brandId: json['brand_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand_id': brandId,
      'name': name,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
