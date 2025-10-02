// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'role.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Role {
  /// Unique identifier for the role
  String get id => throw _privateConstructorUsedError;

  /// Role name (e.g., "Server", "Bartender")
  String get name => throw _privateConstructorUsedError;

  /// Detailed description of the role
  String? get description => throw _privateConstructorUsedError;

  /// Category for grouping roles (e.g., "Front of House", "Back of House")
  String? get category => throw _privateConstructorUsedError;

  /// Required skills or qualifications
  List<String> get requiredSkills => throw _privateConstructorUsedError;

  /// Certifications needed for this role
  List<String> get requiredCertifications => throw _privateConstructorUsedError;

  /// Whether the role is currently active
  bool get isActive => throw _privateConstructorUsedError;

  /// Default hourly rate for this role (can be overridden by tariffs)
  double? get defaultRate => throw _privateConstructorUsedError;

  /// Currency code for the default rate
  String? get currency => throw _privateConstructorUsedError;

  /// Priority/ranking for display order
  int? get displayOrder => throw _privateConstructorUsedError;

  /// Color code for UI representation (hex format)
  String? get colorCode => throw _privateConstructorUsedError;

  /// Icon identifier for UI representation
  String? get iconName => throw _privateConstructorUsedError;

  /// When the role was created
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// When the role was last updated
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Create a copy of Role
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RoleCopyWith<Role> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoleCopyWith<$Res> {
  factory $RoleCopyWith(Role value, $Res Function(Role) then) =
      _$RoleCopyWithImpl<$Res, Role>;
  @useResult
  $Res call({
    String id,
    String name,
    String? description,
    String? category,
    List<String> requiredSkills,
    List<String> requiredCertifications,
    bool isActive,
    double? defaultRate,
    String? currency,
    int? displayOrder,
    String? colorCode,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class _$RoleCopyWithImpl<$Res, $Val extends Role>
    implements $RoleCopyWith<$Res> {
  _$RoleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Role
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? category = freezed,
    Object? requiredSkills = null,
    Object? requiredCertifications = null,
    Object? isActive = null,
    Object? defaultRate = freezed,
    Object? currency = freezed,
    Object? displayOrder = freezed,
    Object? colorCode = freezed,
    Object? iconName = freezed,
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
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            category: freezed == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String?,
            requiredSkills: null == requiredSkills
                ? _value.requiredSkills
                : requiredSkills // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            requiredCertifications: null == requiredCertifications
                ? _value.requiredCertifications
                : requiredCertifications // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            defaultRate: freezed == defaultRate
                ? _value.defaultRate
                : defaultRate // ignore: cast_nullable_to_non_nullable
                      as double?,
            currency: freezed == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                      as String?,
            displayOrder: freezed == displayOrder
                ? _value.displayOrder
                : displayOrder // ignore: cast_nullable_to_non_nullable
                      as int?,
            colorCode: freezed == colorCode
                ? _value.colorCode
                : colorCode // ignore: cast_nullable_to_non_nullable
                      as String?,
            iconName: freezed == iconName
                ? _value.iconName
                : iconName // ignore: cast_nullable_to_non_nullable
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
abstract class _$$RoleImplCopyWith<$Res> implements $RoleCopyWith<$Res> {
  factory _$$RoleImplCopyWith(
    _$RoleImpl value,
    $Res Function(_$RoleImpl) then,
  ) = __$$RoleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? description,
    String? category,
    List<String> requiredSkills,
    List<String> requiredCertifications,
    bool isActive,
    double? defaultRate,
    String? currency,
    int? displayOrder,
    String? colorCode,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class __$$RoleImplCopyWithImpl<$Res>
    extends _$RoleCopyWithImpl<$Res, _$RoleImpl>
    implements _$$RoleImplCopyWith<$Res> {
  __$$RoleImplCopyWithImpl(_$RoleImpl _value, $Res Function(_$RoleImpl) _then)
    : super(_value, _then);

  /// Create a copy of Role
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? category = freezed,
    Object? requiredSkills = null,
    Object? requiredCertifications = null,
    Object? isActive = null,
    Object? defaultRate = freezed,
    Object? currency = freezed,
    Object? displayOrder = freezed,
    Object? colorCode = freezed,
    Object? iconName = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _$RoleImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        category: freezed == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String?,
        requiredSkills: null == requiredSkills
            ? _value._requiredSkills
            : requiredSkills // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        requiredCertifications: null == requiredCertifications
            ? _value._requiredCertifications
            : requiredCertifications // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        defaultRate: freezed == defaultRate
            ? _value.defaultRate
            : defaultRate // ignore: cast_nullable_to_non_nullable
                  as double?,
        currency: freezed == currency
            ? _value.currency
            : currency // ignore: cast_nullable_to_non_nullable
                  as String?,
        displayOrder: freezed == displayOrder
            ? _value.displayOrder
            : displayOrder // ignore: cast_nullable_to_non_nullable
                  as int?,
        colorCode: freezed == colorCode
            ? _value.colorCode
            : colorCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        iconName: freezed == iconName
            ? _value.iconName
            : iconName // ignore: cast_nullable_to_non_nullable
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

class _$RoleImpl extends _Role {
  const _$RoleImpl({
    required this.id,
    required this.name,
    this.description,
    this.category,
    final List<String> requiredSkills = const [],
    final List<String> requiredCertifications = const [],
    this.isActive = true,
    this.defaultRate,
    this.currency,
    this.displayOrder,
    this.colorCode,
    this.iconName,
    this.createdAt,
    this.updatedAt,
    final Map<String, dynamic> metadata = const {},
  }) : _requiredSkills = requiredSkills,
       _requiredCertifications = requiredCertifications,
       _metadata = metadata,
       super._();

  /// Unique identifier for the role
  @override
  final String id;

  /// Role name (e.g., "Server", "Bartender")
  @override
  final String name;

  /// Detailed description of the role
  @override
  final String? description;

  /// Category for grouping roles (e.g., "Front of House", "Back of House")
  @override
  final String? category;

  /// Required skills or qualifications
  final List<String> _requiredSkills;

  /// Required skills or qualifications
  @override
  @JsonKey()
  List<String> get requiredSkills {
    if (_requiredSkills is EqualUnmodifiableListView) return _requiredSkills;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requiredSkills);
  }

  /// Certifications needed for this role
  final List<String> _requiredCertifications;

  /// Certifications needed for this role
  @override
  @JsonKey()
  List<String> get requiredCertifications {
    if (_requiredCertifications is EqualUnmodifiableListView)
      return _requiredCertifications;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requiredCertifications);
  }

  /// Whether the role is currently active
  @override
  @JsonKey()
  final bool isActive;

  /// Default hourly rate for this role (can be overridden by tariffs)
  @override
  final double? defaultRate;

  /// Currency code for the default rate
  @override
  final String? currency;

  /// Priority/ranking for display order
  @override
  final int? displayOrder;

  /// Color code for UI representation (hex format)
  @override
  final String? colorCode;

  /// Icon identifier for UI representation
  @override
  final String? iconName;

  /// When the role was created
  @override
  final DateTime? createdAt;

  /// When the role was last updated
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
    return 'Role(id: $id, name: $name, description: $description, category: $category, requiredSkills: $requiredSkills, requiredCertifications: $requiredCertifications, isActive: $isActive, defaultRate: $defaultRate, currency: $currency, displayOrder: $displayOrder, colorCode: $colorCode, iconName: $iconName, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(
              other._requiredSkills,
              _requiredSkills,
            ) &&
            const DeepCollectionEquality().equals(
              other._requiredCertifications,
              _requiredCertifications,
            ) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.defaultRate, defaultRate) ||
                other.defaultRate == defaultRate) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.displayOrder, displayOrder) ||
                other.displayOrder == displayOrder) &&
            (identical(other.colorCode, colorCode) ||
                other.colorCode == colorCode) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName) &&
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
    description,
    category,
    const DeepCollectionEquality().hash(_requiredSkills),
    const DeepCollectionEquality().hash(_requiredCertifications),
    isActive,
    defaultRate,
    currency,
    displayOrder,
    colorCode,
    iconName,
    createdAt,
    updatedAt,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of Role
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RoleImplCopyWith<_$RoleImpl> get copyWith =>
      __$$RoleImplCopyWithImpl<_$RoleImpl>(this, _$identity);
}

abstract class _Role extends Role {
  const factory _Role({
    required final String id,
    required final String name,
    final String? description,
    final String? category,
    final List<String> requiredSkills,
    final List<String> requiredCertifications,
    final bool isActive,
    final double? defaultRate,
    final String? currency,
    final int? displayOrder,
    final String? colorCode,
    final String? iconName,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final Map<String, dynamic> metadata,
  }) = _$RoleImpl;
  const _Role._() : super._();

  /// Unique identifier for the role
  @override
  String get id;

  /// Role name (e.g., "Server", "Bartender")
  @override
  String get name;

  /// Detailed description of the role
  @override
  String? get description;

  /// Category for grouping roles (e.g., "Front of House", "Back of House")
  @override
  String? get category;

  /// Required skills or qualifications
  @override
  List<String> get requiredSkills;

  /// Certifications needed for this role
  @override
  List<String> get requiredCertifications;

  /// Whether the role is currently active
  @override
  bool get isActive;

  /// Default hourly rate for this role (can be overridden by tariffs)
  @override
  double? get defaultRate;

  /// Currency code for the default rate
  @override
  String? get currency;

  /// Priority/ranking for display order
  @override
  int? get displayOrder;

  /// Color code for UI representation (hex format)
  @override
  String? get colorCode;

  /// Icon identifier for UI representation
  @override
  String? get iconName;

  /// When the role was created
  @override
  DateTime? get createdAt;

  /// When the role was last updated
  @override
  DateTime? get updatedAt;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of Role
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RoleImplCopyWith<_$RoleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
