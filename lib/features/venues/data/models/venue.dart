/// Venue model representing event locations
/// Now stored in separate MongoDB collection instead of embedded in Manager
class Venue {
  final String? id; // MongoDB _id from venues collection
  final String name;
  final String address;
  final String city;
  final String? state;
  final String? country;
  final String? placeId; // Google Place ID for future lookups
  final double? latitude;
  final double? longitude;
  final String source; // 'manual', 'ai', or 'places'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Venue({
    this.id,
    required this.name,
    required this.address,
    required this.city,
    this.state,
    this.country,
    this.placeId,
    this.latitude,
    this.longitude,
    required this.source,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a Venue from JSON (new API format)
  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String?,
      country: json['country'] as String?,
      placeId: json['placeId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      source: json['source'] as String? ?? 'manual',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Convert Venue to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (placeId != null) 'placeId': placeId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'source': source,
    };
  }

  /// Check if venue was manually added
  bool get isManual => source == 'manual';

  /// Check if venue was AI-discovered
  bool get isAI => source == 'ai';

  /// Check if venue was added via Google Places
  bool get isFromPlaces => source == 'places';

  /// Copy venue with updated fields
  Venue copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? state,
    String? country,
    String? placeId,
    double? latitude,
    double? longitude,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Venue(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Venue(id: $id, name: $name, address: $address, city: $city, state: $state, source: $source)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Venue &&
        other.id == id &&
        other.name == name &&
        other.address == address &&
        other.city == city &&
        other.state == state &&
        other.country == country &&
        other.placeId == placeId &&
        other.source == source;
  }

  @override
  int get hashCode => Object.hash(id, name, address, city, state, country, placeId, source);
}
