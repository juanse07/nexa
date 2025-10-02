// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_credentials.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AuthCredentials {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String email, String password) emailPassword,
    required TResult Function(
      String provider,
      String accessToken,
      String? idToken,
    )
    oauth,
    required TResult Function(String phoneNumber, String verificationCode)
    phone,
    required TResult Function(String refreshToken) refreshToken,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String email, String password)? emailPassword,
    TResult? Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult? Function(String phoneNumber, String verificationCode)? phone,
    TResult? Function(String refreshToken)? refreshToken,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String email, String password)? emailPassword,
    TResult Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult Function(String phoneNumber, String verificationCode)? phone,
    TResult Function(String refreshToken)? refreshToken,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EmailPasswordCredentials value) emailPassword,
    required TResult Function(OAuthCredentials value) oauth,
    required TResult Function(PhoneCredentials value) phone,
    required TResult Function(RefreshTokenCredentials value) refreshToken,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EmailPasswordCredentials value)? emailPassword,
    TResult? Function(OAuthCredentials value)? oauth,
    TResult? Function(PhoneCredentials value)? phone,
    TResult? Function(RefreshTokenCredentials value)? refreshToken,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EmailPasswordCredentials value)? emailPassword,
    TResult Function(OAuthCredentials value)? oauth,
    TResult Function(PhoneCredentials value)? phone,
    TResult Function(RefreshTokenCredentials value)? refreshToken,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthCredentialsCopyWith<$Res> {
  factory $AuthCredentialsCopyWith(
    AuthCredentials value,
    $Res Function(AuthCredentials) then,
  ) = _$AuthCredentialsCopyWithImpl<$Res, AuthCredentials>;
}

/// @nodoc
class _$AuthCredentialsCopyWithImpl<$Res, $Val extends AuthCredentials>
    implements $AuthCredentialsCopyWith<$Res> {
  _$AuthCredentialsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$EmailPasswordCredentialsImplCopyWith<$Res> {
  factory _$$EmailPasswordCredentialsImplCopyWith(
    _$EmailPasswordCredentialsImpl value,
    $Res Function(_$EmailPasswordCredentialsImpl) then,
  ) = __$$EmailPasswordCredentialsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String email, String password});
}

/// @nodoc
class __$$EmailPasswordCredentialsImplCopyWithImpl<$Res>
    extends _$AuthCredentialsCopyWithImpl<$Res, _$EmailPasswordCredentialsImpl>
    implements _$$EmailPasswordCredentialsImplCopyWith<$Res> {
  __$$EmailPasswordCredentialsImplCopyWithImpl(
    _$EmailPasswordCredentialsImpl _value,
    $Res Function(_$EmailPasswordCredentialsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? email = null, Object? password = null}) {
    return _then(
      _$EmailPasswordCredentialsImpl(
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        password: null == password
            ? _value.password
            : password // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$EmailPasswordCredentialsImpl implements EmailPasswordCredentials {
  const _$EmailPasswordCredentialsImpl({
    required this.email,
    required this.password,
  });

  @override
  final String email;
  @override
  final String password;

  @override
  String toString() {
    return 'AuthCredentials.emailPassword(email: $email, password: $password)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmailPasswordCredentialsImpl &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.password, password) ||
                other.password == password));
  }

  @override
  int get hashCode => Object.hash(runtimeType, email, password);

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmailPasswordCredentialsImplCopyWith<_$EmailPasswordCredentialsImpl>
  get copyWith =>
      __$$EmailPasswordCredentialsImplCopyWithImpl<
        _$EmailPasswordCredentialsImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String email, String password) emailPassword,
    required TResult Function(
      String provider,
      String accessToken,
      String? idToken,
    )
    oauth,
    required TResult Function(String phoneNumber, String verificationCode)
    phone,
    required TResult Function(String refreshToken) refreshToken,
  }) {
    return emailPassword(email, password);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String email, String password)? emailPassword,
    TResult? Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult? Function(String phoneNumber, String verificationCode)? phone,
    TResult? Function(String refreshToken)? refreshToken,
  }) {
    return emailPassword?.call(email, password);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String email, String password)? emailPassword,
    TResult Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult Function(String phoneNumber, String verificationCode)? phone,
    TResult Function(String refreshToken)? refreshToken,
    required TResult orElse(),
  }) {
    if (emailPassword != null) {
      return emailPassword(email, password);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EmailPasswordCredentials value) emailPassword,
    required TResult Function(OAuthCredentials value) oauth,
    required TResult Function(PhoneCredentials value) phone,
    required TResult Function(RefreshTokenCredentials value) refreshToken,
  }) {
    return emailPassword(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EmailPasswordCredentials value)? emailPassword,
    TResult? Function(OAuthCredentials value)? oauth,
    TResult? Function(PhoneCredentials value)? phone,
    TResult? Function(RefreshTokenCredentials value)? refreshToken,
  }) {
    return emailPassword?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EmailPasswordCredentials value)? emailPassword,
    TResult Function(OAuthCredentials value)? oauth,
    TResult Function(PhoneCredentials value)? phone,
    TResult Function(RefreshTokenCredentials value)? refreshToken,
    required TResult orElse(),
  }) {
    if (emailPassword != null) {
      return emailPassword(this);
    }
    return orElse();
  }
}

abstract class EmailPasswordCredentials implements AuthCredentials {
  const factory EmailPasswordCredentials({
    required final String email,
    required final String password,
  }) = _$EmailPasswordCredentialsImpl;

  String get email;
  String get password;

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmailPasswordCredentialsImplCopyWith<_$EmailPasswordCredentialsImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$OAuthCredentialsImplCopyWith<$Res> {
  factory _$$OAuthCredentialsImplCopyWith(
    _$OAuthCredentialsImpl value,
    $Res Function(_$OAuthCredentialsImpl) then,
  ) = __$$OAuthCredentialsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String provider, String accessToken, String? idToken});
}

/// @nodoc
class __$$OAuthCredentialsImplCopyWithImpl<$Res>
    extends _$AuthCredentialsCopyWithImpl<$Res, _$OAuthCredentialsImpl>
    implements _$$OAuthCredentialsImplCopyWith<$Res> {
  __$$OAuthCredentialsImplCopyWithImpl(
    _$OAuthCredentialsImpl _value,
    $Res Function(_$OAuthCredentialsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? provider = null,
    Object? accessToken = null,
    Object? idToken = freezed,
  }) {
    return _then(
      _$OAuthCredentialsImpl(
        provider: null == provider
            ? _value.provider
            : provider // ignore: cast_nullable_to_non_nullable
                  as String,
        accessToken: null == accessToken
            ? _value.accessToken
            : accessToken // ignore: cast_nullable_to_non_nullable
                  as String,
        idToken: freezed == idToken
            ? _value.idToken
            : idToken // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$OAuthCredentialsImpl implements OAuthCredentials {
  const _$OAuthCredentialsImpl({
    required this.provider,
    required this.accessToken,
    this.idToken,
  });

  @override
  final String provider;
  @override
  final String accessToken;
  @override
  final String? idToken;

  @override
  String toString() {
    return 'AuthCredentials.oauth(provider: $provider, accessToken: $accessToken, idToken: $idToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OAuthCredentialsImpl &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.accessToken, accessToken) ||
                other.accessToken == accessToken) &&
            (identical(other.idToken, idToken) || other.idToken == idToken));
  }

  @override
  int get hashCode => Object.hash(runtimeType, provider, accessToken, idToken);

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OAuthCredentialsImplCopyWith<_$OAuthCredentialsImpl> get copyWith =>
      __$$OAuthCredentialsImplCopyWithImpl<_$OAuthCredentialsImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String email, String password) emailPassword,
    required TResult Function(
      String provider,
      String accessToken,
      String? idToken,
    )
    oauth,
    required TResult Function(String phoneNumber, String verificationCode)
    phone,
    required TResult Function(String refreshToken) refreshToken,
  }) {
    return oauth(provider, accessToken, idToken);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String email, String password)? emailPassword,
    TResult? Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult? Function(String phoneNumber, String verificationCode)? phone,
    TResult? Function(String refreshToken)? refreshToken,
  }) {
    return oauth?.call(provider, accessToken, idToken);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String email, String password)? emailPassword,
    TResult Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult Function(String phoneNumber, String verificationCode)? phone,
    TResult Function(String refreshToken)? refreshToken,
    required TResult orElse(),
  }) {
    if (oauth != null) {
      return oauth(provider, accessToken, idToken);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EmailPasswordCredentials value) emailPassword,
    required TResult Function(OAuthCredentials value) oauth,
    required TResult Function(PhoneCredentials value) phone,
    required TResult Function(RefreshTokenCredentials value) refreshToken,
  }) {
    return oauth(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EmailPasswordCredentials value)? emailPassword,
    TResult? Function(OAuthCredentials value)? oauth,
    TResult? Function(PhoneCredentials value)? phone,
    TResult? Function(RefreshTokenCredentials value)? refreshToken,
  }) {
    return oauth?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EmailPasswordCredentials value)? emailPassword,
    TResult Function(OAuthCredentials value)? oauth,
    TResult Function(PhoneCredentials value)? phone,
    TResult Function(RefreshTokenCredentials value)? refreshToken,
    required TResult orElse(),
  }) {
    if (oauth != null) {
      return oauth(this);
    }
    return orElse();
  }
}

abstract class OAuthCredentials implements AuthCredentials {
  const factory OAuthCredentials({
    required final String provider,
    required final String accessToken,
    final String? idToken,
  }) = _$OAuthCredentialsImpl;

  String get provider;
  String get accessToken;
  String? get idToken;

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OAuthCredentialsImplCopyWith<_$OAuthCredentialsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PhoneCredentialsImplCopyWith<$Res> {
  factory _$$PhoneCredentialsImplCopyWith(
    _$PhoneCredentialsImpl value,
    $Res Function(_$PhoneCredentialsImpl) then,
  ) = __$$PhoneCredentialsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String phoneNumber, String verificationCode});
}

/// @nodoc
class __$$PhoneCredentialsImplCopyWithImpl<$Res>
    extends _$AuthCredentialsCopyWithImpl<$Res, _$PhoneCredentialsImpl>
    implements _$$PhoneCredentialsImplCopyWith<$Res> {
  __$$PhoneCredentialsImplCopyWithImpl(
    _$PhoneCredentialsImpl _value,
    $Res Function(_$PhoneCredentialsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? phoneNumber = null, Object? verificationCode = null}) {
    return _then(
      _$PhoneCredentialsImpl(
        phoneNumber: null == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        verificationCode: null == verificationCode
            ? _value.verificationCode
            : verificationCode // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$PhoneCredentialsImpl implements PhoneCredentials {
  const _$PhoneCredentialsImpl({
    required this.phoneNumber,
    required this.verificationCode,
  });

  @override
  final String phoneNumber;
  @override
  final String verificationCode;

  @override
  String toString() {
    return 'AuthCredentials.phone(phoneNumber: $phoneNumber, verificationCode: $verificationCode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PhoneCredentialsImpl &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.verificationCode, verificationCode) ||
                other.verificationCode == verificationCode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, phoneNumber, verificationCode);

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PhoneCredentialsImplCopyWith<_$PhoneCredentialsImpl> get copyWith =>
      __$$PhoneCredentialsImplCopyWithImpl<_$PhoneCredentialsImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String email, String password) emailPassword,
    required TResult Function(
      String provider,
      String accessToken,
      String? idToken,
    )
    oauth,
    required TResult Function(String phoneNumber, String verificationCode)
    phone,
    required TResult Function(String refreshToken) refreshToken,
  }) {
    return phone(phoneNumber, verificationCode);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String email, String password)? emailPassword,
    TResult? Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult? Function(String phoneNumber, String verificationCode)? phone,
    TResult? Function(String refreshToken)? refreshToken,
  }) {
    return phone?.call(phoneNumber, verificationCode);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String email, String password)? emailPassword,
    TResult Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult Function(String phoneNumber, String verificationCode)? phone,
    TResult Function(String refreshToken)? refreshToken,
    required TResult orElse(),
  }) {
    if (phone != null) {
      return phone(phoneNumber, verificationCode);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EmailPasswordCredentials value) emailPassword,
    required TResult Function(OAuthCredentials value) oauth,
    required TResult Function(PhoneCredentials value) phone,
    required TResult Function(RefreshTokenCredentials value) refreshToken,
  }) {
    return phone(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EmailPasswordCredentials value)? emailPassword,
    TResult? Function(OAuthCredentials value)? oauth,
    TResult? Function(PhoneCredentials value)? phone,
    TResult? Function(RefreshTokenCredentials value)? refreshToken,
  }) {
    return phone?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EmailPasswordCredentials value)? emailPassword,
    TResult Function(OAuthCredentials value)? oauth,
    TResult Function(PhoneCredentials value)? phone,
    TResult Function(RefreshTokenCredentials value)? refreshToken,
    required TResult orElse(),
  }) {
    if (phone != null) {
      return phone(this);
    }
    return orElse();
  }
}

abstract class PhoneCredentials implements AuthCredentials {
  const factory PhoneCredentials({
    required final String phoneNumber,
    required final String verificationCode,
  }) = _$PhoneCredentialsImpl;

  String get phoneNumber;
  String get verificationCode;

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PhoneCredentialsImplCopyWith<_$PhoneCredentialsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RefreshTokenCredentialsImplCopyWith<$Res> {
  factory _$$RefreshTokenCredentialsImplCopyWith(
    _$RefreshTokenCredentialsImpl value,
    $Res Function(_$RefreshTokenCredentialsImpl) then,
  ) = __$$RefreshTokenCredentialsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String refreshToken});
}

/// @nodoc
class __$$RefreshTokenCredentialsImplCopyWithImpl<$Res>
    extends _$AuthCredentialsCopyWithImpl<$Res, _$RefreshTokenCredentialsImpl>
    implements _$$RefreshTokenCredentialsImplCopyWith<$Res> {
  __$$RefreshTokenCredentialsImplCopyWithImpl(
    _$RefreshTokenCredentialsImpl _value,
    $Res Function(_$RefreshTokenCredentialsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? refreshToken = null}) {
    return _then(
      _$RefreshTokenCredentialsImpl(
        refreshToken: null == refreshToken
            ? _value.refreshToken
            : refreshToken // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$RefreshTokenCredentialsImpl implements RefreshTokenCredentials {
  const _$RefreshTokenCredentialsImpl({required this.refreshToken});

  @override
  final String refreshToken;

  @override
  String toString() {
    return 'AuthCredentials.refreshToken(refreshToken: $refreshToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RefreshTokenCredentialsImpl &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken));
  }

  @override
  int get hashCode => Object.hash(runtimeType, refreshToken);

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RefreshTokenCredentialsImplCopyWith<_$RefreshTokenCredentialsImpl>
  get copyWith =>
      __$$RefreshTokenCredentialsImplCopyWithImpl<
        _$RefreshTokenCredentialsImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String email, String password) emailPassword,
    required TResult Function(
      String provider,
      String accessToken,
      String? idToken,
    )
    oauth,
    required TResult Function(String phoneNumber, String verificationCode)
    phone,
    required TResult Function(String refreshToken) refreshToken,
  }) {
    return refreshToken(this.refreshToken);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String email, String password)? emailPassword,
    TResult? Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult? Function(String phoneNumber, String verificationCode)? phone,
    TResult? Function(String refreshToken)? refreshToken,
  }) {
    return refreshToken?.call(this.refreshToken);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String email, String password)? emailPassword,
    TResult Function(String provider, String accessToken, String? idToken)?
    oauth,
    TResult Function(String phoneNumber, String verificationCode)? phone,
    TResult Function(String refreshToken)? refreshToken,
    required TResult orElse(),
  }) {
    if (refreshToken != null) {
      return refreshToken(this.refreshToken);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(EmailPasswordCredentials value) emailPassword,
    required TResult Function(OAuthCredentials value) oauth,
    required TResult Function(PhoneCredentials value) phone,
    required TResult Function(RefreshTokenCredentials value) refreshToken,
  }) {
    return refreshToken(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(EmailPasswordCredentials value)? emailPassword,
    TResult? Function(OAuthCredentials value)? oauth,
    TResult? Function(PhoneCredentials value)? phone,
    TResult? Function(RefreshTokenCredentials value)? refreshToken,
  }) {
    return refreshToken?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(EmailPasswordCredentials value)? emailPassword,
    TResult Function(OAuthCredentials value)? oauth,
    TResult Function(PhoneCredentials value)? phone,
    TResult Function(RefreshTokenCredentials value)? refreshToken,
    required TResult orElse(),
  }) {
    if (refreshToken != null) {
      return refreshToken(this);
    }
    return orElse();
  }
}

abstract class RefreshTokenCredentials implements AuthCredentials {
  const factory RefreshTokenCredentials({required final String refreshToken}) =
      _$RefreshTokenCredentialsImpl;

  String get refreshToken;

  /// Create a copy of AuthCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RefreshTokenCredentialsImplCopyWith<_$RefreshTokenCredentialsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
