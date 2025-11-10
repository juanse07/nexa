/// Venue model representing event locations
class Venue {
  final String name;
  final String address;
  final String city;
  final String source; // 'ai' or 'manual'

  const Venue({
    required this.name,
    required this.address,
    required this.city,
    required this.source,
  });

  /// Create a Venue from JSON
  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      source: json['source'] as String? ?? 'ai',
    );
  }

  /// Convert Venue to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'source': source,
    };
  }

  /// Check if venue was manually added
  bool get isManual => source == 'manual';

  /// Check if venue was AI-discovered
  bool get isAI => source == 'ai';

  /// Copy venue with updated fields
  Venue copyWith({
    String? name,
    String? address,
    String? city,
    String? source,
  }) {
    return Venue(
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      source: source ?? this.source,
    );
  }

  @override
  String toString() => 'Venue(name: $name, address: $address, city: $city, source: $source)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Venue &&
        other.name == name &&
        other.address == address &&
        other.city == city &&
        other.source == source;
  }

  @override
  int get hashCode => Object.hash(name, address, city, source);
}
