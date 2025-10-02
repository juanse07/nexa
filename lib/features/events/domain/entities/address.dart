import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'address.freezed.dart';

/// Represents a physical address with optional geolocation coordinates.
///
/// This entity is used throughout the application for representing
/// locations of events, clients, and venues.
@freezed
class Address with _$Address implements Entity {
  /// Creates an [Address] instance.
  ///
  /// All parameters are optional to handle partial address data.
  const factory Address({
    /// Street address (e.g., "123 Main St, Suite 100")
    String? street,

    /// City name
    String? city,

    /// State or province
    String? state,

    /// Postal or ZIP code
    String? zip,

    /// Country name
    String? country,

    /// Latitude coordinate for mapping
    double? latitude,

    /// Longitude coordinate for mapping
    double? longitude,

    /// Full formatted address string
    String? formattedAddress,
  }) = _Address;

  const Address._();

  /// Returns true if the address has valid geolocation coordinates.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Returns true if the address has any location data.
  bool get hasData =>
      street != null ||
      city != null ||
      state != null ||
      zip != null ||
      country != null ||
      formattedAddress != null;

  /// Returns a formatted single-line address string.
  String get displayAddress {
    if (formattedAddress != null && formattedAddress!.isNotEmpty) {
      return formattedAddress!;
    }

    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (zip != null && zip!.isNotEmpty) parts.add(zip!);
    if (country != null && country!.isNotEmpty) parts.add(country!);

    return parts.join(', ');
  }
}
