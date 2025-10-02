// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AuthUser {
  /// Unique identifier for the user
  String get userId => throw _privateConstructorUsedError;

  /// User's email address
  String get email => throw _privateConstructorUsedError;

  /// User's full name
  String? get displayName => throw _privateConstructorUsedError;

  /// Profile photo URL
  String? get photoUrl => throw _privateConstructorUsedError;

  /// Authentication token (JWT or similar)
  String get token => throw _privateConstructorUsedError;

  /// Refresh token for obtaining new access tokens
  String? get refreshToken => throw _privateConstructorUsedError;

  /// Token expiration timestamp
  DateTime? get expiresAt => throw _privateConstructorUsedError;

  /// List of user roles (e.g., "admin", "manager", "staff")
  List<String> get roles => throw _privateConstructorUsedError;

  /// List of permissions
  List<String> get permissions => throw _privateConstructorUsedError;

  /// Provider used for authentication (e.g., "google", "email")
  String? get provider => throw _privateConstructorUsedError;

  /// Whether the user's email is verified
  bool get emailVerified => throw _privateConstructorUsedError;

  /// User's phone number
  String? get phoneNumber => throw _privateConstructorUsedError;

  /// When the user account was created
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// When the user last logged in
  DateTime? get lastLoginAt => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Create a copy of AuthUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthUserCopyWith<AuthUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthUserCopyWith<$Res> {
  factory $AuthUserCopyWith(AuthUser value, $Res Function(AuthUser) then) =
      _$AuthUserCopyWithImpl<$Res, AuthUser>;
  @useResult
  $Res call({
    String userId,
    String email,
    String? displayName,
    String? photoUrl,
    String token,
    String? refreshToken,
    DateTime? expiresAt,
    List<String> roles,
    List<String> permissions,
    String? provider,
    bool emailVerified,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class _$AuthUserCopyWithImpl<$Res, $Val extends AuthUser>
    implements $AuthUserCopyWith<$Res> {
  _$AuthUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? email = null,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? token = null,
    Object? refreshToken = freezed,
    Object? expiresAt = freezed,
    Object? roles = null,
    Object? permissions = null,
    Object? provider = freezed,
    Object? emailVerified = null,
    Object? phoneNumber = freezed,
    Object? createdAt = freezed,
    Object? lastLoginAt = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            photoUrl: freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            token: null == token
                ? _value.token
                : token // ignore: cast_nullable_to_non_nullable
                      as String,
            refreshToken: freezed == refreshToken
                ? _value.refreshToken
                : refreshToken // ignore: cast_nullable_to_non_nullable
                      as String?,
            expiresAt: freezed == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            roles: null == roles
                ? _value.roles
                : roles // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            permissions: null == permissions
                ? _value.permissions
                : permissions // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            provider: freezed == provider
                ? _value.provider
                : provider // ignore: cast_nullable_to_non_nullable
                      as String?,
            emailVerified: null == emailVerified
                ? _value.emailVerified
                : emailVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            phoneNumber: freezed == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastLoginAt: freezed == lastLoginAt
                ? _value.lastLoginAt
                : lastLoginAt // ignore: cast_nullable_to_non_nullable
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
abstract class _$$AuthUserImplCopyWith<$Res>
    implements $AuthUserCopyWith<$Res> {
  factory _$$AuthUserImplCopyWith(
    _$AuthUserImpl value,
    $Res Function(_$AuthUserImpl) then,
  ) = __$$AuthUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String userId,
    String email,
    String? displayName,
    String? photoUrl,
    String token,
    String? refreshToken,
    DateTime? expiresAt,
    List<String> roles,
    List<String> permissions,
    String? provider,
    bool emailVerified,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class __$$AuthUserImplCopyWithImpl<$Res>
    extends _$AuthUserCopyWithImpl<$Res, _$AuthUserImpl>
    implements _$$AuthUserImplCopyWith<$Res> {
  __$$AuthUserImplCopyWithImpl(
    _$AuthUserImpl _value,
    $Res Function(_$AuthUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? email = null,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? token = null,
    Object? refreshToken = freezed,
    Object? expiresAt = freezed,
    Object? roles = null,
    Object? permissions = null,
    Object? provider = freezed,
    Object? emailVerified = null,
    Object? phoneNumber = freezed,
    Object? createdAt = freezed,
    Object? lastLoginAt = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _$AuthUserImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        photoUrl: freezed == photoUrl
            ? _value.photoUrl
            : photoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        token: null == token
            ? _value.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String,
        refreshToken: freezed == refreshToken
            ? _value.refreshToken
            : refreshToken // ignore: cast_nullable_to_non_nullable
                  as String?,
        expiresAt: freezed == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        roles: null == roles
            ? _value._roles
            : roles // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        permissions: null == permissions
            ? _value._permissions
            : permissions // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        provider: freezed == provider
            ? _value.provider
            : provider // ignore: cast_nullable_to_non_nullable
                  as String?,
        emailVerified: null == emailVerified
            ? _value.emailVerified
            : emailVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        phoneNumber: freezed == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastLoginAt: freezed == lastLoginAt
            ? _value.lastLoginAt
            : lastLoginAt // ignore: cast_nullable_to_non_nullable
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

class _$AuthUserImpl extends _AuthUser {
  const _$AuthUserImpl({
    required this.userId,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.token,
    this.refreshToken,
    this.expiresAt,
    final List<String> roles = const [],
    final List<String> permissions = const [],
    this.provider,
    this.emailVerified = false,
    this.phoneNumber,
    this.createdAt,
    this.lastLoginAt,
    final Map<String, dynamic> metadata = const {},
  }) : _roles = roles,
       _permissions = permissions,
       _metadata = metadata,
       super._();

  /// Unique identifier for the user
  @override
  final String userId;

  /// User's email address
  @override
  final String email;

  /// User's full name
  @override
  final String? displayName;

  /// Profile photo URL
  @override
  final String? photoUrl;

  /// Authentication token (JWT or similar)
  @override
  final String token;

  /// Refresh token for obtaining new access tokens
  @override
  final String? refreshToken;

  /// Token expiration timestamp
  @override
  final DateTime? expiresAt;

  /// List of user roles (e.g., "admin", "manager", "staff")
  final List<String> _roles;

  /// List of user roles (e.g., "admin", "manager", "staff")
  @override
  @JsonKey()
  List<String> get roles {
    if (_roles is EqualUnmodifiableListView) return _roles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_roles);
  }

  /// List of permissions
  final List<String> _permissions;

  /// List of permissions
  @override
  @JsonKey()
  List<String> get permissions {
    if (_permissions is EqualUnmodifiableListView) return _permissions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_permissions);
  }

  /// Provider used for authentication (e.g., "google", "email")
  @override
  final String? provider;

  /// Whether the user's email is verified
  @override
  @JsonKey()
  final bool emailVerified;

  /// User's phone number
  @override
  final String? phoneNumber;

  /// When the user account was created
  @override
  final DateTime? createdAt;

  /// When the user last logged in
  @override
  final DateTime? lastLoginAt;

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
    return 'AuthUser(userId: $userId, email: $email, displayName: $displayName, photoUrl: $photoUrl, token: $token, refreshToken: $refreshToken, expiresAt: $expiresAt, roles: $roles, permissions: $permissions, provider: $provider, emailVerified: $emailVerified, phoneNumber: $phoneNumber, createdAt: $createdAt, lastLoginAt: $lastLoginAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthUserImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            const DeepCollectionEquality().equals(other._roles, _roles) &&
            const DeepCollectionEquality().equals(
              other._permissions,
              _permissions,
            ) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.emailVerified, emailVerified) ||
                other.emailVerified == emailVerified) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastLoginAt, lastLoginAt) ||
                other.lastLoginAt == lastLoginAt) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    email,
    displayName,
    photoUrl,
    token,
    refreshToken,
    expiresAt,
    const DeepCollectionEquality().hash(_roles),
    const DeepCollectionEquality().hash(_permissions),
    provider,
    emailVerified,
    phoneNumber,
    createdAt,
    lastLoginAt,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of AuthUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthUserImplCopyWith<_$AuthUserImpl> get copyWith =>
      __$$AuthUserImplCopyWithImpl<_$AuthUserImpl>(this, _$identity);
}

abstract class _AuthUser extends AuthUser {
  const factory _AuthUser({
    required final String userId,
    required final String email,
    final String? displayName,
    final String? photoUrl,
    required final String token,
    final String? refreshToken,
    final DateTime? expiresAt,
    final List<String> roles,
    final List<String> permissions,
    final String? provider,
    final bool emailVerified,
    final String? phoneNumber,
    final DateTime? createdAt,
    final DateTime? lastLoginAt,
    final Map<String, dynamic> metadata,
  }) = _$AuthUserImpl;
  const _AuthUser._() : super._();

  /// Unique identifier for the user
  @override
  String get userId;

  /// User's email address
  @override
  String get email;

  /// User's full name
  @override
  String? get displayName;

  /// Profile photo URL
  @override
  String? get photoUrl;

  /// Authentication token (JWT or similar)
  @override
  String get token;

  /// Refresh token for obtaining new access tokens
  @override
  String? get refreshToken;

  /// Token expiration timestamp
  @override
  DateTime? get expiresAt;

  /// List of user roles (e.g., "admin", "manager", "staff")
  @override
  List<String> get roles;

  /// List of permissions
  @override
  List<String> get permissions;

  /// Provider used for authentication (e.g., "google", "email")
  @override
  String? get provider;

  /// Whether the user's email is verified
  @override
  bool get emailVerified;

  /// User's phone number
  @override
  String? get phoneNumber;

  /// When the user account was created
  @override
  DateTime? get createdAt;

  /// When the user last logged in
  @override
  DateTime? get lastLoginAt;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of AuthUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthUserImplCopyWith<_$AuthUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
