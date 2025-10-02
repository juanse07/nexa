// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Client {
  /// Unique identifier for the client
  String get id => throw _privateConstructorUsedError;

  /// Client name or company name
  String get name => throw _privateConstructorUsedError;

  /// Primary contact person name
  String? get contactPerson => throw _privateConstructorUsedError;

  /// Contact email address
  String? get email => throw _privateConstructorUsedError;

  /// Contact phone number
  String? get phone => throw _privateConstructorUsedError;

  /// Client's physical address
  Address? get address => throw _privateConstructorUsedError;

  /// Company or organization type
  String? get companyType => throw _privateConstructorUsedError;

  /// Tax ID or business registration number
  String? get taxId => throw _privateConstructorUsedError;

  /// Website URL
  String? get website => throw _privateConstructorUsedError;

  /// Additional notes about the client
  String? get notes => throw _privateConstructorUsedError;

  /// Client status (active, inactive, etc.)
  bool get isActive => throw _privateConstructorUsedError;

  /// Preferred payment terms (e.g., "Net 30")
  String? get paymentTerms => throw _privateConstructorUsedError;

  /// Billing address (if different from main address)
  Address? get billingAddress => throw _privateConstructorUsedError;

  /// When the client was added
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// When the client was last updated
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClientCopyWith<Client> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClientCopyWith<$Res> {
  factory $ClientCopyWith(Client value, $Res Function(Client) then) =
      _$ClientCopyWithImpl<$Res, Client>;
  @useResult
  $Res call({
    String id,
    String name,
    String? contactPerson,
    String? email,
    String? phone,
    Address? address,
    String? companyType,
    String? taxId,
    String? website,
    String? notes,
    bool isActive,
    String? paymentTerms,
    Address? billingAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> metadata,
  });

  $AddressCopyWith<$Res>? get address;
  $AddressCopyWith<$Res>? get billingAddress;
}

/// @nodoc
class _$ClientCopyWithImpl<$Res, $Val extends Client>
    implements $ClientCopyWith<$Res> {
  _$ClientCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? contactPerson = freezed,
    Object? email = freezed,
    Object? phone = freezed,
    Object? address = freezed,
    Object? companyType = freezed,
    Object? taxId = freezed,
    Object? website = freezed,
    Object? notes = freezed,
    Object? isActive = null,
    Object? paymentTerms = freezed,
    Object? billingAddress = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            contactPerson: freezed == contactPerson
                ? _value.contactPerson
                : contactPerson // ignore: cast_nullable_to_non_nullable
                      as String?,
            email: freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String?,
            phone: freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String?,
            address: freezed == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as Address?,
            companyType: freezed == companyType
                ? _value.companyType
                : companyType // ignore: cast_nullable_to_non_nullable
                      as String?,
            taxId: freezed == taxId
                ? _value.taxId
                : taxId // ignore: cast_nullable_to_non_nullable
                      as String?,
            website: freezed == website
                ? _value.website
                : website // ignore: cast_nullable_to_non_nullable
                      as String?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            paymentTerms: freezed == paymentTerms
                ? _value.paymentTerms
                : paymentTerms // ignore: cast_nullable_to_non_nullable
                      as String?,
            billingAddress: freezed == billingAddress
                ? _value.billingAddress
                : billingAddress // ignore: cast_nullable_to_non_nullable
                      as Address?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            metadata: null == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AddressCopyWith<$Res>? get address {
    if (_value.address == null) {
      return null;
    }

    return $AddressCopyWith<$Res>(_value.address!, (value) {
      return _then(_value.copyWith(address: value) as $Val);
    });
  }

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AddressCopyWith<$Res>? get billingAddress {
    if (_value.billingAddress == null) {
      return null;
    }

    return $AddressCopyWith<$Res>(_value.billingAddress!, (value) {
      return _then(_value.copyWith(billingAddress: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ClientImplCopyWith<$Res> implements $ClientCopyWith<$Res> {
  factory _$$ClientImplCopyWith(
    _$ClientImpl value,
    $Res Function(_$ClientImpl) then,
  ) = __$$ClientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? contactPerson,
    String? email,
    String? phone,
    Address? address,
    String? companyType,
    String? taxId,
    String? website,
    String? notes,
    bool isActive,
    String? paymentTerms,
    Address? billingAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> metadata,
  });

  @override
  $AddressCopyWith<$Res>? get address;
  @override
  $AddressCopyWith<$Res>? get billingAddress;
}

/// @nodoc
class __$$ClientImplCopyWithImpl<$Res>
    extends _$ClientCopyWithImpl<$Res, _$ClientImpl>
    implements _$$ClientImplCopyWith<$Res> {
  __$$ClientImplCopyWithImpl(
    _$ClientImpl _value,
    $Res Function(_$ClientImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? contactPerson = freezed,
    Object? email = freezed,
    Object? phone = freezed,
    Object? address = freezed,
    Object? companyType = freezed,
    Object? taxId = freezed,
    Object? website = freezed,
    Object? notes = freezed,
    Object? isActive = null,
    Object? paymentTerms = freezed,
    Object? billingAddress = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _$ClientImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        contactPerson: freezed == contactPerson
            ? _value.contactPerson
            : contactPerson // ignore: cast_nullable_to_non_nullable
                  as String?,
        email: freezed == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String?,
        phone: freezed == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String?,
        address: freezed == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as Address?,
        companyType: freezed == companyType
            ? _value.companyType
            : companyType // ignore: cast_nullable_to_non_nullable
                  as String?,
        taxId: freezed == taxId
            ? _value.taxId
            : taxId // ignore: cast_nullable_to_non_nullable
                  as String?,
        website: freezed == website
            ? _value.website
            : website // ignore: cast_nullable_to_non_nullable
                  as String?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        paymentTerms: freezed == paymentTerms
            ? _value.paymentTerms
            : paymentTerms // ignore: cast_nullable_to_non_nullable
                  as String?,
        billingAddress: freezed == billingAddress
            ? _value.billingAddress
            : billingAddress // ignore: cast_nullable_to_non_nullable
                  as Address?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        metadata: null == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc

class _$ClientImpl extends _Client {
  const _$ClientImpl({
    required this.id,
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.companyType,
    this.taxId,
    this.website,
    this.notes,
    this.isActive = true,
    this.paymentTerms,
    this.billingAddress,
    this.createdAt,
    this.updatedAt,
    final Map<String, dynamic> metadata = const {},
  }) : _metadata = metadata,
       super._();

  /// Unique identifier for the client
  @override
  final String id;

  /// Client name or company name
  @override
  final String name;

  /// Primary contact person name
  @override
  final String? contactPerson;

  /// Contact email address
  @override
  final String? email;

  /// Contact phone number
  @override
  final String? phone;

  /// Client's physical address
  @override
  final Address? address;

  /// Company or organization type
  @override
  final String? companyType;

  /// Tax ID or business registration number
  @override
  final String? taxId;

  /// Website URL
  @override
  final String? website;

  /// Additional notes about the client
  @override
  final String? notes;

  /// Client status (active, inactive, etc.)
  @override
  @JsonKey()
  final bool isActive;

  /// Preferred payment terms (e.g., "Net 30")
  @override
  final String? paymentTerms;

  /// Billing address (if different from main address)
  @override
  final Address? billingAddress;

  /// When the client was added
  @override
  final DateTime? createdAt;

  /// When the client was last updated
  @override
  final DateTime? updatedAt;

  /// Additional metadata
  final Map<String, dynamic> _metadata;

  /// Additional metadata
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  String toString() {
    return 'Client(id: $id, name: $name, contactPerson: $contactPerson, email: $email, phone: $phone, address: $address, companyType: $companyType, taxId: $taxId, website: $website, notes: $notes, isActive: $isActive, paymentTerms: $paymentTerms, billingAddress: $billingAddress, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClientImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.contactPerson, contactPerson) ||
                other.contactPerson == contactPerson) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.companyType, companyType) ||
                other.companyType == companyType) &&
            (identical(other.taxId, taxId) || other.taxId == taxId) &&
            (identical(other.website, website) || other.website == website) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.paymentTerms, paymentTerms) ||
                other.paymentTerms == paymentTerms) &&
            (identical(other.billingAddress, billingAddress) ||
                other.billingAddress == billingAddress) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    contactPerson,
    email,
    phone,
    address,
    companyType,
    taxId,
    website,
    notes,
    isActive,
    paymentTerms,
    billingAddress,
    createdAt,
    updatedAt,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClientImplCopyWith<_$ClientImpl> get copyWith =>
      __$$ClientImplCopyWithImpl<_$ClientImpl>(this, _$identity);
}

abstract class _Client extends Client {
  const factory _Client({
    required final String id,
    required final String name,
    final String? contactPerson,
    final String? email,
    final String? phone,
    final Address? address,
    final String? companyType,
    final String? taxId,
    final String? website,
    final String? notes,
    final bool isActive,
    final String? paymentTerms,
    final Address? billingAddress,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final Map<String, dynamic> metadata,
  }) = _$ClientImpl;
  const _Client._() : super._();

  /// Unique identifier for the client
  @override
  String get id;

  /// Client name or company name
  @override
  String get name;

  /// Primary contact person name
  @override
  String? get contactPerson;

  /// Contact email address
  @override
  String? get email;

  /// Contact phone number
  @override
  String? get phone;

  /// Client's physical address
  @override
  Address? get address;

  /// Company or organization type
  @override
  String? get companyType;

  /// Tax ID or business registration number
  @override
  String? get taxId;

  /// Website URL
  @override
  String? get website;

  /// Additional notes about the client
  @override
  String? get notes;

  /// Client status (active, inactive, etc.)
  @override
  bool get isActive;

  /// Preferred payment terms (e.g., "Net 30")
  @override
  String? get paymentTerms;

  /// Billing address (if different from main address)
  @override
  Address? get billingAddress;

  /// When the client was added
  @override
  DateTime? get createdAt;

  /// When the client was last updated
  @override
  DateTime? get updatedAt;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of Client
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClientImplCopyWith<_$ClientImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
