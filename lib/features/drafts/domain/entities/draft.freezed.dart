// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Draft {
  /// Unique identifier for the draft
  String get id => throw _privateConstructorUsedError;

  /// Type of draft (e.g., "event", "client", "user")
  String get type => throw _privateConstructorUsedError;

  /// The draft data as a JSON object
  Map<String, dynamic> get data => throw _privateConstructorUsedError;

  /// Human-readable title for the draft
  String? get title => throw _privateConstructorUsedError;

  /// Description or notes about the draft
  String? get description => throw _privateConstructorUsedError;

  /// When the draft was created
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// When the draft was last updated
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Whether the draft has been synchronized with the server
  bool get isSynced => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Create a copy of Draft
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DraftCopyWith<Draft> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DraftCopyWith<$Res> {
  factory $DraftCopyWith(Draft value, $Res Function(Draft) then) =
      _$DraftCopyWithImpl<$Res, Draft>;
  @useResult
  $Res call({
    String id,
    String type,
    Map<String, dynamic> data,
    String? title,
    String? description,
    DateTime createdAt,
    DateTime updatedAt,
    bool isSynced,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class _$DraftCopyWithImpl<$Res, $Val extends Draft>
    implements $DraftCopyWith<$Res> {
  _$DraftCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Draft
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? data = null,
    Object? title = freezed,
    Object? description = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? isSynced = null,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            data: null == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            isSynced: null == isSynced
                ? _value.isSynced
                : isSynced // ignore: cast_nullable_to_non_nullable
                      as bool,
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
abstract class _$$DraftImplCopyWith<$Res> implements $DraftCopyWith<$Res> {
  factory _$$DraftImplCopyWith(
    _$DraftImpl value,
    $Res Function(_$DraftImpl) then,
  ) = __$$DraftImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String type,
    Map<String, dynamic> data,
    String? title,
    String? description,
    DateTime createdAt,
    DateTime updatedAt,
    bool isSynced,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class __$$DraftImplCopyWithImpl<$Res>
    extends _$DraftCopyWithImpl<$Res, _$DraftImpl>
    implements _$$DraftImplCopyWith<$Res> {
  __$$DraftImplCopyWithImpl(
    _$DraftImpl _value,
    $Res Function(_$DraftImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Draft
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? data = null,
    Object? title = freezed,
    Object? description = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? isSynced = null,
    Object? metadata = null,
  }) {
    return _then(
      _$DraftImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        data: null == data
            ? _value._data
            : data // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        isSynced: null == isSynced
            ? _value.isSynced
            : isSynced // ignore: cast_nullable_to_non_nullable
                  as bool,
        metadata: null == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc

class _$DraftImpl extends _Draft {
  const _$DraftImpl({
    required this.id,
    required this.type,
    required final Map<String, dynamic> data,
    this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    final Map<String, dynamic> metadata = const {},
  }) : _data = data,
       _metadata = metadata,
       super._();

  /// Unique identifier for the draft
  @override
  final String id;

  /// Type of draft (e.g., "event", "client", "user")
  @override
  final String type;

  /// The draft data as a JSON object
  final Map<String, dynamic> _data;

  /// The draft data as a JSON object
  @override
  Map<String, dynamic> get data {
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_data);
  }

  /// Human-readable title for the draft
  @override
  final String? title;

  /// Description or notes about the draft
  @override
  final String? description;

  /// When the draft was created
  @override
  final DateTime createdAt;

  /// When the draft was last updated
  @override
  final DateTime updatedAt;

  /// Whether the draft has been synchronized with the server
  @override
  @JsonKey()
  final bool isSynced;

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
    return 'Draft(id: $id, type: $type, data: $data, title: $title, description: $description, createdAt: $createdAt, updatedAt: $updatedAt, isSynced: $isSynced, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DraftImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.isSynced, isSynced) ||
                other.isSynced == isSynced) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    const DeepCollectionEquality().hash(_data),
    title,
    description,
    createdAt,
    updatedAt,
    isSynced,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of Draft
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DraftImplCopyWith<_$DraftImpl> get copyWith =>
      __$$DraftImplCopyWithImpl<_$DraftImpl>(this, _$identity);
}

abstract class _Draft extends Draft {
  const factory _Draft({
    required final String id,
    required final String type,
    required final Map<String, dynamic> data,
    final String? title,
    final String? description,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final bool isSynced,
    final Map<String, dynamic> metadata,
  }) = _$DraftImpl;
  const _Draft._() : super._();

  /// Unique identifier for the draft
  @override
  String get id;

  /// Type of draft (e.g., "event", "client", "user")
  @override
  String get type;

  /// The draft data as a JSON object
  @override
  Map<String, dynamic> get data;

  /// Human-readable title for the draft
  @override
  String? get title;

  /// Description or notes about the draft
  @override
  String? get description;

  /// When the draft was created
  @override
  DateTime get createdAt;

  /// When the draft was last updated
  @override
  DateTime get updatedAt;

  /// Whether the draft has been synchronized with the server
  @override
  bool get isSynced;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of Draft
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DraftImplCopyWith<_$DraftImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
