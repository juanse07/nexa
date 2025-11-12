import 'package:json_annotation/json_annotation.dart';

part 'city.g.dart';

/// Represents a city with tourist designation for venue search
@JsonSerializable()
class City {
  /// City name in "City, State, Country" format (e.g., "Denver, CO, USA")
  final String name;

  /// Whether this is a tourist destination (affects venue search strategy)
  /// - true: Tourist city (strict city limits, ~30 venues)
  /// - false: Metro area (entire metropolitan region, ~80 venues)
  @JsonKey(name: 'isTourist')
  final bool isTourist;

  const City({
    required this.name,
    required this.isTourist,
  });

  /// Creates a City from JSON
  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);

  /// Converts City to JSON
  Map<String, dynamic> toJson() => _$CityToJson(this);

  /// Returns the city name without state/country (e.g., "Denver" from "Denver, CO, USA")
  String get displayName {
    return name.split(',').first.trim();
  }

  /// Creates a copy with optional field updates
  City copyWith({
    String? name,
    bool? isTourist,
  }) {
    return City(
      name: name ?? this.name,
      isTourist: isTourist ?? this.isTourist,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is City &&
        other.name == name &&
        other.isTourist == isTourist;
  }

  @override
  int get hashCode => Object.hash(name, isTourist);

  @override
  String toString() => 'City(name: $name, isTourist: $isTourist)';
}
