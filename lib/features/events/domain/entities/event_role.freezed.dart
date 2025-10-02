// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_role.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$EventRole {
  /// Unique identifier for this event role assignment
  String? get id => throw _privateConstructorUsedError;

  /// Reference to the role type (e.g., "server", "bartender")
  String get roleId => throw _privateConstructorUsedError;

  /// Name of the role for display purposes
  String? get roleName => throw _privateConstructorUsedError;

  /// Reference to the applicable tariff/rate
  String? get tariffId => throw _privateConstructorUsedError;

  /// Number of staff needed for this role
  int get quantity => throw _privateConstructorUsedError;

  /// List of user IDs who are confirmed for this role
  List<String> get confirmedUserIds => throw _privateConstructorUsedError;

  /// Call time for this specific role (may differ from event start time)
  DateTime? get callTime => throw _privateConstructorUsedError;

  /// Notes specific to this role assignment
  String? get notes => throw _privateConstructorUsedError;

  /// Pay rate for this role (may override tariff)
  double? get rate => throw _privateConstructorUsedError;

  /// Currency code (e.g., "USD", "EUR")
  String? get currency => throw _privateConstructorUsedError;

  /// Create a copy of EventRole
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EventRoleCopyWith<EventRole> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EventRoleCopyWith<$Res> {
  factory $EventRoleCopyWith(EventRole value, $Res Function(EventRole) then) =
      _$EventRoleCopyWithImpl<$Res, EventRole>;
  @useResult
  $Res call({
    String? id,
    String roleId,
    String? roleName,
    String? tariffId,
    int quantity,
    List<String> confirmedUserIds,
    DateTime? callTime,
    String? notes,
    double? rate,
    String? currency,
  });
}

/// @nodoc
class _$EventRoleCopyWithImpl<$Res, $Val extends EventRole>
    implements $EventRoleCopyWith<$Res> {
  _$EventRoleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EventRole
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? roleId = null,
    Object? roleName = freezed,
    Object? tariffId = freezed,
    Object? quantity = null,
    Object? confirmedUserIds = null,
    Object? callTime = freezed,
    Object? notes = freezed,
    Object? rate = freezed,
    Object? currency = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String?,
            roleId: null == roleId
                ? _value.roleId
                : roleId // ignore: cast_nullable_to_non_nullable
                      as String,
            roleName: freezed == roleName
                ? _value.roleName
                : roleName // ignore: cast_nullable_to_non_nullable
                      as String?,
            tariffId: freezed == tariffId
                ? _value.tariffId
                : tariffId // ignore: cast_nullable_to_non_nullable
                      as String?,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            confirmedUserIds: null == confirmedUserIds
                ? _value.confirmedUserIds
                : confirmedUserIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            callTime: freezed == callTime
                ? _value.callTime
                : callTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            rate: freezed == rate
                ? _value.rate
                : rate // ignore: cast_nullable_to_non_nullable
                      as double?,
            currency: freezed == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EventRoleImplCopyWith<$Res>
    implements $EventRoleCopyWith<$Res> {
  factory _$$EventRoleImplCopyWith(
    _$EventRoleImpl value,
    $Res Function(_$EventRoleImpl) then,
  ) = __$$EventRoleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? id,
    String roleId,
    String? roleName,
    String? tariffId,
    int quantity,
    List<String> confirmedUserIds,
    DateTime? callTime,
    String? notes,
    double? rate,
    String? currency,
  });
}

/// @nodoc
class __$$EventRoleImplCopyWithImpl<$Res>
    extends _$EventRoleCopyWithImpl<$Res, _$EventRoleImpl>
    implements _$$EventRoleImplCopyWith<$Res> {
  __$$EventRoleImplCopyWithImpl(
    _$EventRoleImpl _value,
    $Res Function(_$EventRoleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EventRole
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? roleId = null,
    Object? roleName = freezed,
    Object? tariffId = freezed,
    Object? quantity = null,
    Object? confirmedUserIds = null,
    Object? callTime = freezed,
    Object? notes = freezed,
    Object? rate = freezed,
    Object? currency = freezed,
  }) {
    return _then(
      _$EventRoleImpl(
        id: freezed == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String?,
        roleId: null == roleId
            ? _value.roleId
            : roleId // ignore: cast_nullable_to_non_nullable
                  as String,
        roleName: freezed == roleName
            ? _value.roleName
            : roleName // ignore: cast_nullable_to_non_nullable
                  as String?,
        tariffId: freezed == tariffId
            ? _value.tariffId
            : tariffId // ignore: cast_nullable_to_non_nullable
                  as String?,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        confirmedUserIds: null == confirmedUserIds
            ? _value._confirmedUserIds
            : confirmedUserIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        callTime: freezed == callTime
            ? _value.callTime
            : callTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        rate: freezed == rate
            ? _value.rate
            : rate // ignore: cast_nullable_to_non_nullable
                  as double?,
        currency: freezed == currency
            ? _value.currency
            : currency // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$EventRoleImpl extends _EventRole {
  const _$EventRoleImpl({
    this.id,
    required this.roleId,
    this.roleName,
    this.tariffId,
    required this.quantity,
    final List<String> confirmedUserIds = const [],
    this.callTime,
    this.notes,
    this.rate,
    this.currency,
  }) : _confirmedUserIds = confirmedUserIds,
       super._();

  /// Unique identifier for this event role assignment
  @override
  final String? id;

  /// Reference to the role type (e.g., "server", "bartender")
  @override
  final String roleId;

  /// Name of the role for display purposes
  @override
  final String? roleName;

  /// Reference to the applicable tariff/rate
  @override
  final String? tariffId;

  /// Number of staff needed for this role
  @override
  final int quantity;

  /// List of user IDs who are confirmed for this role
  final List<String> _confirmedUserIds;

  /// List of user IDs who are confirmed for this role
  @override
  @JsonKey()
  List<String> get confirmedUserIds {
    if (_confirmedUserIds is EqualUnmodifiableListView)
      return _confirmedUserIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_confirmedUserIds);
  }

  /// Call time for this specific role (may differ from event start time)
  @override
  final DateTime? callTime;

  /// Notes specific to this role assignment
  @override
  final String? notes;

  /// Pay rate for this role (may override tariff)
  @override
  final double? rate;

  /// Currency code (e.g., "USD", "EUR")
  @override
  final String? currency;

  @override
  String toString() {
    return 'EventRole(id: $id, roleId: $roleId, roleName: $roleName, tariffId: $tariffId, quantity: $quantity, confirmedUserIds: $confirmedUserIds, callTime: $callTime, notes: $notes, rate: $rate, currency: $currency)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EventRoleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roleId, roleId) || other.roleId == roleId) &&
            (identical(other.roleName, roleName) ||
                other.roleName == roleName) &&
            (identical(other.tariffId, tariffId) ||
                other.tariffId == tariffId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            const DeepCollectionEquality().equals(
              other._confirmedUserIds,
              _confirmedUserIds,
            ) &&
            (identical(other.callTime, callTime) ||
                other.callTime == callTime) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.rate, rate) || other.rate == rate) &&
            (identical(other.currency, currency) ||
                other.currency == currency));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    roleId,
    roleName,
    tariffId,
    quantity,
    const DeepCollectionEquality().hash(_confirmedUserIds),
    callTime,
    notes,
    rate,
    currency,
  );

  /// Create a copy of EventRole
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EventRoleImplCopyWith<_$EventRoleImpl> get copyWith =>
      __$$EventRoleImplCopyWithImpl<_$EventRoleImpl>(this, _$identity);
}

abstract class _EventRole extends EventRole {
  const factory _EventRole({
    final String? id,
    required final String roleId,
    final String? roleName,
    final String? tariffId,
    required final int quantity,
    final List<String> confirmedUserIds,
    final DateTime? callTime,
    final String? notes,
    final double? rate,
    final String? currency,
  }) = _$EventRoleImpl;
  const _EventRole._() : super._();

  /// Unique identifier for this event role assignment
  @override
  String? get id;

  /// Reference to the role type (e.g., "server", "bartender")
  @override
  String get roleId;

  /// Name of the role for display purposes
  @override
  String? get roleName;

  /// Reference to the applicable tariff/rate
  @override
  String? get tariffId;

  /// Number of staff needed for this role
  @override
  int get quantity;

  /// List of user IDs who are confirmed for this role
  @override
  List<String> get confirmedUserIds;

  /// Call time for this specific role (may differ from event start time)
  @override
  DateTime? get callTime;

  /// Notes specific to this role assignment
  @override
  String? get notes;

  /// Pay rate for this role (may override tariff)
  @override
  double? get rate;

  /// Currency code (e.g., "USD", "EUR")
  @override
  String? get currency;

  /// Create a copy of EventRole
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EventRoleImplCopyWith<_$EventRoleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
