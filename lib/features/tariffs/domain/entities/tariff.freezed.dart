// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tariff.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Tariff {
  /// Unique identifier for the tariff
  String get id => throw _privateConstructorUsedError;

  /// Reference to the client this tariff applies to
  String get clientId => throw _privateConstructorUsedError;

  /// Client name for display purposes
  String? get clientName => throw _privateConstructorUsedError;

  /// Reference to the role this tariff applies to
  String get roleId => throw _privateConstructorUsedError;

  /// Role name for display purposes
  String? get roleName => throw _privateConstructorUsedError;

  /// Hourly rate for this tariff
  double get rate => throw _privateConstructorUsedError;

  /// Currency code (e.g., "USD", "EUR")
  String get currency => throw _privateConstructorUsedError;

  /// Billing type (hourly, daily, fixed)
  BillingType get billingType => throw _privateConstructorUsedError;

  /// Minimum billable hours (if applicable)
  double? get minimumHours => throw _privateConstructorUsedError;

  /// Overtime rate multiplier (e.g., 1.5 for time-and-a-half)
  double? get overtimeMultiplier => throw _privateConstructorUsedError;

  /// Hours after which overtime applies
  double? get overtimeThreshold => throw _privateConstructorUsedError;

  /// Whether this tariff is currently active
  bool get isActive => throw _privateConstructorUsedError;

  /// Effective start date for this tariff
  DateTime? get effectiveFrom => throw _privateConstructorUsedError;

  /// Effective end date for this tariff
  DateTime? get effectiveTo => throw _privateConstructorUsedError;

  /// Additional notes about the tariff
  String? get notes => throw _privateConstructorUsedError;

  /// When the tariff was created
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// When the tariff was last updated
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Create a copy of Tariff
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TariffCopyWith<Tariff> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TariffCopyWith<$Res> {
  factory $TariffCopyWith(Tariff value, $Res Function(Tariff) then) =
      _$TariffCopyWithImpl<$Res, Tariff>;
  @useResult
  $Res call({
    String id,
    String clientId,
    String? clientName,
    String roleId,
    String? roleName,
    double rate,
    String currency,
    BillingType billingType,
    double? minimumHours,
    double? overtimeMultiplier,
    double? overtimeThreshold,
    bool isActive,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class _$TariffCopyWithImpl<$Res, $Val extends Tariff>
    implements $TariffCopyWith<$Res> {
  _$TariffCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Tariff
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? clientName = freezed,
    Object? roleId = null,
    Object? roleName = freezed,
    Object? rate = null,
    Object? currency = null,
    Object? billingType = null,
    Object? minimumHours = freezed,
    Object? overtimeMultiplier = freezed,
    Object? overtimeThreshold = freezed,
    Object? isActive = null,
    Object? effectiveFrom = freezed,
    Object? effectiveTo = freezed,
    Object? notes = freezed,
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
            clientId: null == clientId
                ? _value.clientId
                : clientId // ignore: cast_nullable_to_non_nullable
                      as String,
            clientName: freezed == clientName
                ? _value.clientName
                : clientName // ignore: cast_nullable_to_non_nullable
                      as String?,
            roleId: null == roleId
                ? _value.roleId
                : roleId // ignore: cast_nullable_to_non_nullable
                      as String,
            roleName: freezed == roleName
                ? _value.roleName
                : roleName // ignore: cast_nullable_to_non_nullable
                      as String?,
            rate: null == rate
                ? _value.rate
                : rate // ignore: cast_nullable_to_non_nullable
                      as double,
            currency: null == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                      as String,
            billingType: null == billingType
                ? _value.billingType
                : billingType // ignore: cast_nullable_to_non_nullable
                      as BillingType,
            minimumHours: freezed == minimumHours
                ? _value.minimumHours
                : minimumHours // ignore: cast_nullable_to_non_nullable
                      as double?,
            overtimeMultiplier: freezed == overtimeMultiplier
                ? _value.overtimeMultiplier
                : overtimeMultiplier // ignore: cast_nullable_to_non_nullable
                      as double?,
            overtimeThreshold: freezed == overtimeThreshold
                ? _value.overtimeThreshold
                : overtimeThreshold // ignore: cast_nullable_to_non_nullable
                      as double?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            effectiveFrom: freezed == effectiveFrom
                ? _value.effectiveFrom
                : effectiveFrom // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            effectiveTo: freezed == effectiveTo
                ? _value.effectiveTo
                : effectiveTo // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
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
}

/// @nodoc
abstract class _$$TariffImplCopyWith<$Res> implements $TariffCopyWith<$Res> {
  factory _$$TariffImplCopyWith(
    _$TariffImpl value,
    $Res Function(_$TariffImpl) then,
  ) = __$$TariffImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String clientId,
    String? clientName,
    String roleId,
    String? roleName,
    double rate,
    String currency,
    BillingType billingType,
    double? minimumHours,
    double? overtimeMultiplier,
    double? overtimeThreshold,
    bool isActive,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class __$$TariffImplCopyWithImpl<$Res>
    extends _$TariffCopyWithImpl<$Res, _$TariffImpl>
    implements _$$TariffImplCopyWith<$Res> {
  __$$TariffImplCopyWithImpl(
    _$TariffImpl _value,
    $Res Function(_$TariffImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Tariff
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? clientName = freezed,
    Object? roleId = null,
    Object? roleName = freezed,
    Object? rate = null,
    Object? currency = null,
    Object? billingType = null,
    Object? minimumHours = freezed,
    Object? overtimeMultiplier = freezed,
    Object? overtimeThreshold = freezed,
    Object? isActive = null,
    Object? effectiveFrom = freezed,
    Object? effectiveTo = freezed,
    Object? notes = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _$TariffImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        clientId: null == clientId
            ? _value.clientId
            : clientId // ignore: cast_nullable_to_non_nullable
                  as String,
        clientName: freezed == clientName
            ? _value.clientName
            : clientName // ignore: cast_nullable_to_non_nullable
                  as String?,
        roleId: null == roleId
            ? _value.roleId
            : roleId // ignore: cast_nullable_to_non_nullable
                  as String,
        roleName: freezed == roleName
            ? _value.roleName
            : roleName // ignore: cast_nullable_to_non_nullable
                  as String?,
        rate: null == rate
            ? _value.rate
            : rate // ignore: cast_nullable_to_non_nullable
                  as double,
        currency: null == currency
            ? _value.currency
            : currency // ignore: cast_nullable_to_non_nullable
                  as String,
        billingType: null == billingType
            ? _value.billingType
            : billingType // ignore: cast_nullable_to_non_nullable
                  as BillingType,
        minimumHours: freezed == minimumHours
            ? _value.minimumHours
            : minimumHours // ignore: cast_nullable_to_non_nullable
                  as double?,
        overtimeMultiplier: freezed == overtimeMultiplier
            ? _value.overtimeMultiplier
            : overtimeMultiplier // ignore: cast_nullable_to_non_nullable
                  as double?,
        overtimeThreshold: freezed == overtimeThreshold
            ? _value.overtimeThreshold
            : overtimeThreshold // ignore: cast_nullable_to_non_nullable
                  as double?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        effectiveFrom: freezed == effectiveFrom
            ? _value.effectiveFrom
            : effectiveFrom // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        effectiveTo: freezed == effectiveTo
            ? _value.effectiveTo
            : effectiveTo // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
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

class _$TariffImpl extends _Tariff {
  const _$TariffImpl({
    required this.id,
    required this.clientId,
    this.clientName,
    required this.roleId,
    this.roleName,
    required this.rate,
    this.currency = 'USD',
    this.billingType = BillingType.hourly,
    this.minimumHours,
    this.overtimeMultiplier,
    this.overtimeThreshold,
    this.isActive = true,
    this.effectiveFrom,
    this.effectiveTo,
    this.notes,
    this.createdAt,
    this.updatedAt,
    final Map<String, dynamic> metadata = const {},
  }) : _metadata = metadata,
       super._();

  /// Unique identifier for the tariff
  @override
  final String id;

  /// Reference to the client this tariff applies to
  @override
  final String clientId;

  /// Client name for display purposes
  @override
  final String? clientName;

  /// Reference to the role this tariff applies to
  @override
  final String roleId;

  /// Role name for display purposes
  @override
  final String? roleName;

  /// Hourly rate for this tariff
  @override
  final double rate;

  /// Currency code (e.g., "USD", "EUR")
  @override
  @JsonKey()
  final String currency;

  /// Billing type (hourly, daily, fixed)
  @override
  @JsonKey()
  final BillingType billingType;

  /// Minimum billable hours (if applicable)
  @override
  final double? minimumHours;

  /// Overtime rate multiplier (e.g., 1.5 for time-and-a-half)
  @override
  final double? overtimeMultiplier;

  /// Hours after which overtime applies
  @override
  final double? overtimeThreshold;

  /// Whether this tariff is currently active
  @override
  @JsonKey()
  final bool isActive;

  /// Effective start date for this tariff
  @override
  final DateTime? effectiveFrom;

  /// Effective end date for this tariff
  @override
  final DateTime? effectiveTo;

  /// Additional notes about the tariff
  @override
  final String? notes;

  /// When the tariff was created
  @override
  final DateTime? createdAt;

  /// When the tariff was last updated
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
    return 'Tariff(id: $id, clientId: $clientId, clientName: $clientName, roleId: $roleId, roleName: $roleName, rate: $rate, currency: $currency, billingType: $billingType, minimumHours: $minimumHours, overtimeMultiplier: $overtimeMultiplier, overtimeThreshold: $overtimeThreshold, isActive: $isActive, effectiveFrom: $effectiveFrom, effectiveTo: $effectiveTo, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TariffImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientId, clientId) ||
                other.clientId == clientId) &&
            (identical(other.clientName, clientName) ||
                other.clientName == clientName) &&
            (identical(other.roleId, roleId) || other.roleId == roleId) &&
            (identical(other.roleName, roleName) ||
                other.roleName == roleName) &&
            (identical(other.rate, rate) || other.rate == rate) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.billingType, billingType) ||
                other.billingType == billingType) &&
            (identical(other.minimumHours, minimumHours) ||
                other.minimumHours == minimumHours) &&
            (identical(other.overtimeMultiplier, overtimeMultiplier) ||
                other.overtimeMultiplier == overtimeMultiplier) &&
            (identical(other.overtimeThreshold, overtimeThreshold) ||
                other.overtimeThreshold == overtimeThreshold) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.effectiveFrom, effectiveFrom) ||
                other.effectiveFrom == effectiveFrom) &&
            (identical(other.effectiveTo, effectiveTo) ||
                other.effectiveTo == effectiveTo) &&
            (identical(other.notes, notes) || other.notes == notes) &&
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
    clientId,
    clientName,
    roleId,
    roleName,
    rate,
    currency,
    billingType,
    minimumHours,
    overtimeMultiplier,
    overtimeThreshold,
    isActive,
    effectiveFrom,
    effectiveTo,
    notes,
    createdAt,
    updatedAt,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of Tariff
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TariffImplCopyWith<_$TariffImpl> get copyWith =>
      __$$TariffImplCopyWithImpl<_$TariffImpl>(this, _$identity);
}

abstract class _Tariff extends Tariff {
  const factory _Tariff({
    required final String id,
    required final String clientId,
    final String? clientName,
    required final String roleId,
    final String? roleName,
    required final double rate,
    final String currency,
    final BillingType billingType,
    final double? minimumHours,
    final double? overtimeMultiplier,
    final double? overtimeThreshold,
    final bool isActive,
    final DateTime? effectiveFrom,
    final DateTime? effectiveTo,
    final String? notes,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final Map<String, dynamic> metadata,
  }) = _$TariffImpl;
  const _Tariff._() : super._();

  /// Unique identifier for the tariff
  @override
  String get id;

  /// Reference to the client this tariff applies to
  @override
  String get clientId;

  /// Client name for display purposes
  @override
  String? get clientName;

  /// Reference to the role this tariff applies to
  @override
  String get roleId;

  /// Role name for display purposes
  @override
  String? get roleName;

  /// Hourly rate for this tariff
  @override
  double get rate;

  /// Currency code (e.g., "USD", "EUR")
  @override
  String get currency;

  /// Billing type (hourly, daily, fixed)
  @override
  BillingType get billingType;

  /// Minimum billable hours (if applicable)
  @override
  double? get minimumHours;

  /// Overtime rate multiplier (e.g., 1.5 for time-and-a-half)
  @override
  double? get overtimeMultiplier;

  /// Hours after which overtime applies
  @override
  double? get overtimeThreshold;

  /// Whether this tariff is currently active
  @override
  bool get isActive;

  /// Effective start date for this tariff
  @override
  DateTime? get effectiveFrom;

  /// Effective end date for this tariff
  @override
  DateTime? get effectiveTo;

  /// Additional notes about the tariff
  @override
  String? get notes;

  /// When the tariff was created
  @override
  DateTime? get createdAt;

  /// When the tariff was last updated
  @override
  DateTime? get updatedAt;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of Tariff
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TariffImplCopyWith<_$TariffImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
