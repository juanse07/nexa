import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';
import 'package:nexa/features/events/domain/entities/address.dart';

part 'client.freezed.dart';

/// Represents a client who hosts events.
///
/// A client is typically a company, organization, or individual that
/// books staffing services for their events.
@freezed
class Client with _$Client implements Entity {
  /// Creates a [Client] instance.
  const factory Client({
    /// Unique identifier for the client
    required String id,

    /// Client name or company name
    required String name,

    /// Primary contact person name
    String? contactPerson,

    /// Contact email address
    String? email,

    /// Contact phone number
    String? phone,

    /// Client's physical address
    Address? address,

    /// Company or organization type
    String? companyType,

    /// Tax ID or business registration number
    String? taxId,

    /// Website URL
    String? website,

    /// Additional notes about the client
    String? notes,

    /// Client status (active, inactive, etc.)
    @Default(true) bool isActive,

    /// Preferred payment terms (e.g., "Net 30")
    String? paymentTerms,

    /// Billing address (if different from main address)
    Address? billingAddress,

    /// When the client was added
    DateTime? createdAt,

    /// When the client was last updated
    DateTime? updatedAt,

    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _Client;

  const Client._();

  /// Returns true if the client has contact information.
  bool get hasContactInfo => email != null || phone != null;

  /// Returns true if the client has address information.
  bool get hasAddress => address != null && address!.hasData;

  /// Returns the display name for the client.
  String get displayName {
    if (contactPerson != null && contactPerson!.isNotEmpty) {
      return '$name ($contactPerson)';
    }
    return name;
  }

  /// Returns true if the client has complete information.
  bool get isComplete =>
      name.isNotEmpty && hasContactInfo && hasAddress;
}
