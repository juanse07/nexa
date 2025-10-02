// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$User {
  /// Unique identifier for the user
  String get id => throw _privateConstructorUsedError;

  /// First name
  String get firstName => throw _privateConstructorUsedError;

  /// Last name
  String get lastName => throw _privateConstructorUsedError;

  /// Email address
  String? get email => throw _privateConstructorUsedError;

  /// Phone number
  String? get phone => throw _privateConstructorUsedError;

  /// Profile photo URL
  String? get photoUrl => throw _privateConstructorUsedError;

  /// List of role IDs the user is qualified for
  List<String> get roleIds => throw _privateConstructorUsedError;

  /// User's employment status (active, inactive, on-leave, etc.)
  UserStatus get status => throw _privateConstructorUsedError;

  /// Date of hire
  DateTime? get hireDate => throw _privateConstructorUsedError;

  /// Date of birth
  DateTime? get dateOfBirth => throw _privateConstructorUsedError;

  /// Emergency contact name
  String? get emergencyContactName => throw _privateConstructorUsedError;

  /// Emergency contact phone
  String? get emergencyContactPhone => throw _privateConstructorUsedError;

  /// User's certifications or qualifications
  List<String> get certifications => throw _privateConstructorUsedError;

  /// Languages spoken
  List<String> get languages => throw _privateConstructorUsedError;

  /// Availability notes
  String? get availabilityNotes => throw _privateConstructorUsedError;

  /// Hourly rate or salary
  double? get payRate => throw _privateConstructorUsedError;

  /// Currency code for pay rate
  String? get currency => throw _privateConstructorUsedError;

  /// User notes or comments
  String? get notes => throw _privateConstructorUsedError;

  /// When the user was added to the system
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// When the user was last updated
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call({
    String id,
    String firstName,
    String lastName,
    String? email,
    String? phone,
    String? photoUrl,
    List<String> roleIds,
    UserStatus status,
    DateTime? hireDate,
    DateTime? dateOfBirth,
    String? emergencyContactName,
    String? emergencyContactPhone,
    List<String> certifications,
    List<String> languages,
    String? availabilityNotes,
    double? payRate,
    String? currency,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? email = freezed,
    Object? phone = freezed,
    Object? photoUrl = freezed,
    Object? roleIds = null,
    Object? status = null,
    Object? hireDate = freezed,
    Object? dateOfBirth = freezed,
    Object? emergencyContactName = freezed,
    Object? emergencyContactPhone = freezed,
    Object? certifications = null,
    Object? languages = null,
    Object? availabilityNotes = freezed,
    Object? payRate = freezed,
    Object? currency = freezed,
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
            firstName: null == firstName
                ? _value.firstName
                : firstName // ignore: cast_nullable_to_non_nullable
                      as String,
            lastName: null == lastName
                ? _value.lastName
                : lastName // ignore: cast_nullable_to_non_nullable
                      as String,
            email: freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String?,
            phone: freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String?,
            photoUrl: freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            roleIds: null == roleIds
                ? _value.roleIds
                : roleIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as UserStatus,
            hireDate: freezed == hireDate
                ? _value.hireDate
                : hireDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            dateOfBirth: freezed == dateOfBirth
                ? _value.dateOfBirth
                : dateOfBirth // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            emergencyContactName: freezed == emergencyContactName
                ? _value.emergencyContactName
                : emergencyContactName // ignore: cast_nullable_to_non_nullable
                      as String?,
            emergencyContactPhone: freezed == emergencyContactPhone
                ? _value.emergencyContactPhone
                : emergencyContactPhone // ignore: cast_nullable_to_non_nullable
                      as String?,
            certifications: null == certifications
                ? _value.certifications
                : certifications // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            languages: null == languages
                ? _value.languages
                : languages // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            availabilityNotes: freezed == availabilityNotes
                ? _value.availabilityNotes
                : availabilityNotes // ignore: cast_nullable_to_non_nullable
                      as String?,
            payRate: freezed == payRate
                ? _value.payRate
                : payRate // ignore: cast_nullable_to_non_nullable
                      as double?,
            currency: freezed == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
    _$UserImpl value,
    $Res Function(_$UserImpl) then,
  ) = __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String firstName,
    String lastName,
    String? email,
    String? phone,
    String? photoUrl,
    List<String> roleIds,
    UserStatus status,
    DateTime? hireDate,
    DateTime? dateOfBirth,
    String? emergencyContactName,
    String? emergencyContactPhone,
    List<String> certifications,
    List<String> languages,
    String? availabilityNotes,
    double? payRate,
    String? currency,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
    : super(_value, _then);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? email = freezed,
    Object? phone = freezed,
    Object? photoUrl = freezed,
    Object? roleIds = null,
    Object? status = null,
    Object? hireDate = freezed,
    Object? dateOfBirth = freezed,
    Object? emergencyContactName = freezed,
    Object? emergencyContactPhone = freezed,
    Object? certifications = null,
    Object? languages = null,
    Object? availabilityNotes = freezed,
    Object? payRate = freezed,
    Object? currency = freezed,
    Object? notes = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _$UserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        firstName: null == firstName
            ? _value.firstName
            : firstName // ignore: cast_nullable_to_non_nullable
                  as String,
        lastName: null == lastName
            ? _value.lastName
            : lastName // ignore: cast_nullable_to_non_nullable
                  as String,
        email: freezed == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String?,
        phone: freezed == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String?,
        photoUrl: freezed == photoUrl
            ? _value.photoUrl
            : photoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        roleIds: null == roleIds
            ? _value._roleIds
            : roleIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as UserStatus,
        hireDate: freezed == hireDate
            ? _value.hireDate
            : hireDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        dateOfBirth: freezed == dateOfBirth
            ? _value.dateOfBirth
            : dateOfBirth // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        emergencyContactName: freezed == emergencyContactName
            ? _value.emergencyContactName
            : emergencyContactName // ignore: cast_nullable_to_non_nullable
                  as String?,
        emergencyContactPhone: freezed == emergencyContactPhone
            ? _value.emergencyContactPhone
            : emergencyContactPhone // ignore: cast_nullable_to_non_nullable
                  as String?,
        certifications: null == certifications
            ? _value._certifications
            : certifications // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        languages: null == languages
            ? _value._languages
            : languages // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        availabilityNotes: freezed == availabilityNotes
            ? _value.availabilityNotes
            : availabilityNotes // ignore: cast_nullable_to_non_nullable
                  as String?,
        payRate: freezed == payRate
            ? _value.payRate
            : payRate // ignore: cast_nullable_to_non_nullable
                  as double?,
        currency: freezed == currency
            ? _value.currency
            : currency // ignore: cast_nullable_to_non_nullable
                  as String?,
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

class _$UserImpl extends _User {
  const _$UserImpl({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.photoUrl,
    final List<String> roleIds = const [],
    this.status = UserStatus.active,
    this.hireDate,
    this.dateOfBirth,
    this.emergencyContactName,
    this.emergencyContactPhone,
    final List<String> certifications = const [],
    final List<String> languages = const [],
    this.availabilityNotes,
    this.payRate,
    this.currency,
    this.notes,
    this.createdAt,
    this.updatedAt,
    final Map<String, dynamic> metadata = const {},
  }) : _roleIds = roleIds,
       _certifications = certifications,
       _languages = languages,
       _metadata = metadata,
       super._();

  /// Unique identifier for the user
  @override
  final String id;

  /// First name
  @override
  final String firstName;

  /// Last name
  @override
  final String lastName;

  /// Email address
  @override
  final String? email;

  /// Phone number
  @override
  final String? phone;

  /// Profile photo URL
  @override
  final String? photoUrl;

  /// List of role IDs the user is qualified for
  final List<String> _roleIds;

  /// List of role IDs the user is qualified for
  @override
  @JsonKey()
  List<String> get roleIds {
    if (_roleIds is EqualUnmodifiableListView) return _roleIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_roleIds);
  }

  /// User's employment status (active, inactive, on-leave, etc.)
  @override
  @JsonKey()
  final UserStatus status;

  /// Date of hire
  @override
  final DateTime? hireDate;

  /// Date of birth
  @override
  final DateTime? dateOfBirth;

  /// Emergency contact name
  @override
  final String? emergencyContactName;

  /// Emergency contact phone
  @override
  final String? emergencyContactPhone;

  /// User's certifications or qualifications
  final List<String> _certifications;

  /// User's certifications or qualifications
  @override
  @JsonKey()
  List<String> get certifications {
    if (_certifications is EqualUnmodifiableListView) return _certifications;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_certifications);
  }

  /// Languages spoken
  final List<String> _languages;

  /// Languages spoken
  @override
  @JsonKey()
  List<String> get languages {
    if (_languages is EqualUnmodifiableListView) return _languages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_languages);
  }

  /// Availability notes
  @override
  final String? availabilityNotes;

  /// Hourly rate or salary
  @override
  final double? payRate;

  /// Currency code for pay rate
  @override
  final String? currency;

  /// User notes or comments
  @override
  final String? notes;

  /// When the user was added to the system
  @override
  final DateTime? createdAt;

  /// When the user was last updated
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
    return 'User(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, photoUrl: $photoUrl, roleIds: $roleIds, status: $status, hireDate: $hireDate, dateOfBirth: $dateOfBirth, emergencyContactName: $emergencyContactName, emergencyContactPhone: $emergencyContactPhone, certifications: $certifications, languages: $languages, availabilityNotes: $availabilityNotes, payRate: $payRate, currency: $currency, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            const DeepCollectionEquality().equals(other._roleIds, _roleIds) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.hireDate, hireDate) ||
                other.hireDate == hireDate) &&
            (identical(other.dateOfBirth, dateOfBirth) ||
                other.dateOfBirth == dateOfBirth) &&
            (identical(other.emergencyContactName, emergencyContactName) ||
                other.emergencyContactName == emergencyContactName) &&
            (identical(other.emergencyContactPhone, emergencyContactPhone) ||
                other.emergencyContactPhone == emergencyContactPhone) &&
            const DeepCollectionEquality().equals(
              other._certifications,
              _certifications,
            ) &&
            const DeepCollectionEquality().equals(
              other._languages,
              _languages,
            ) &&
            (identical(other.availabilityNotes, availabilityNotes) ||
                other.availabilityNotes == availabilityNotes) &&
            (identical(other.payRate, payRate) || other.payRate == payRate) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    firstName,
    lastName,
    email,
    phone,
    photoUrl,
    const DeepCollectionEquality().hash(_roleIds),
    status,
    hireDate,
    dateOfBirth,
    emergencyContactName,
    emergencyContactPhone,
    const DeepCollectionEquality().hash(_certifications),
    const DeepCollectionEquality().hash(_languages),
    availabilityNotes,
    payRate,
    currency,
    notes,
    createdAt,
    updatedAt,
    const DeepCollectionEquality().hash(_metadata),
  ]);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);
}

abstract class _User extends User {
  const factory _User({
    required final String id,
    required final String firstName,
    required final String lastName,
    final String? email,
    final String? phone,
    final String? photoUrl,
    final List<String> roleIds,
    final UserStatus status,
    final DateTime? hireDate,
    final DateTime? dateOfBirth,
    final String? emergencyContactName,
    final String? emergencyContactPhone,
    final List<String> certifications,
    final List<String> languages,
    final String? availabilityNotes,
    final double? payRate,
    final String? currency,
    final String? notes,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final Map<String, dynamic> metadata,
  }) = _$UserImpl;
  const _User._() : super._();

  /// Unique identifier for the user
  @override
  String get id;

  /// First name
  @override
  String get firstName;

  /// Last name
  @override
  String get lastName;

  /// Email address
  @override
  String? get email;

  /// Phone number
  @override
  String? get phone;

  /// Profile photo URL
  @override
  String? get photoUrl;

  /// List of role IDs the user is qualified for
  @override
  List<String> get roleIds;

  /// User's employment status (active, inactive, on-leave, etc.)
  @override
  UserStatus get status;

  /// Date of hire
  @override
  DateTime? get hireDate;

  /// Date of birth
  @override
  DateTime? get dateOfBirth;

  /// Emergency contact name
  @override
  String? get emergencyContactName;

  /// Emergency contact phone
  @override
  String? get emergencyContactPhone;

  /// User's certifications or qualifications
  @override
  List<String> get certifications;

  /// Languages spoken
  @override
  List<String> get languages;

  /// Availability notes
  @override
  String? get availabilityNotes;

  /// Hourly rate or salary
  @override
  double? get payRate;

  /// Currency code for pay rate
  @override
  String? get currency;

  /// User notes or comments
  @override
  String? get notes;

  /// When the user was added to the system
  @override
  DateTime? get createdAt;

  /// When the user was last updated
  @override
  DateTime? get updatedAt;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
