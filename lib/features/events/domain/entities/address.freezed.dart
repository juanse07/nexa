// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'address.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Address {
  /// Street address (e.g., "123 Main St, Suite 100")
  String? get street => throw _privateConstructorUsedError;

  /// City name
  String? get city => throw _privateConstructorUsedError;

  /// State or province
  String? get state => throw _privateConstructorUsedError;

  /// Postal or ZIP code
  String? get zip => throw _privateConstructorUsedError;

  /// Country name
  String? get country => throw _privateConstructorUsedError;

  /// Latitude coordinate for mapping
  double? get latitude => throw _privateConstructorUsedError;

  /// Longitude coordinate for mapping
  double? get longitude => throw _privateConstructorUsedError;

  /// Full formatted address string
  String? get formattedAddress => throw _privateConstructorUsedError;

  /// Create a copy of Address
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AddressCopyWith<Address> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AddressCopyWith<$Res> {
  factory $AddressCopyWith(Address value, $Res Function(Address) then) =
      _$AddressCopyWithImpl<$Res, Address>;
  @useResult
  $Res call({
    String? street,
    String? city,
    String? state,
    String? zip,
    String? country,
    double? latitude,
    double? longitude,
    String? formattedAddress,
  });
}

/// @nodoc
class _$AddressCopyWithImpl<$Res, $Val extends Address>
    implements $AddressCopyWith<$Res> {
  _$AddressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Address
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? street = freezed,
    Object? city = freezed,
    Object? state = freezed,
    Object? zip = freezed,
    Object? country = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? formattedAddress = freezed,
  }) {
    return _then(
      _value.copyWith(
            street: freezed == street
                ? _value.street
                : street // ignore: cast_nullable_to_non_nullable
                      as String?,
            city: freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String?,
            state: freezed == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as String?,
            zip: freezed == zip
                ? _value.zip
                : zip // ignore: cast_nullable_to_non_nullable
                      as String?,
            country: freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                      as String?,
            latitude: freezed == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            longitude: freezed == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            formattedAddress: freezed == formattedAddress
                ? _value.formattedAddress
                : formattedAddress // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AddressImplCopyWith<$Res> implements $AddressCopyWith<$Res> {
  factory _$$AddressImplCopyWith(
    _$AddressImpl value,
    $Res Function(_$AddressImpl) then,
  ) = __$$AddressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? street,
    String? city,
    String? state,
    String? zip,
    String? country,
    double? latitude,
    double? longitude,
    String? formattedAddress,
  });
}

/// @nodoc
class __$$AddressImplCopyWithImpl<$Res>
    extends _$AddressCopyWithImpl<$Res, _$AddressImpl>
    implements _$$AddressImplCopyWith<$Res> {
  __$$AddressImplCopyWithImpl(
    _$AddressImpl _value,
    $Res Function(_$AddressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Address
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? street = freezed,
    Object? city = freezed,
    Object? state = freezed,
    Object? zip = freezed,
    Object? country = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? formattedAddress = freezed,
  }) {
    return _then(
      _$AddressImpl(
        street: freezed == street
            ? _value.street
            : street // ignore: cast_nullable_to_non_nullable
                  as String?,
        city: freezed == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String?,
        state: freezed == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as String?,
        zip: freezed == zip
            ? _value.zip
            : zip // ignore: cast_nullable_to_non_nullable
                  as String?,
        country: freezed == country
            ? _value.country
            : country // ignore: cast_nullable_to_non_nullable
                  as String?,
        latitude: freezed == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        longitude: freezed == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        formattedAddress: freezed == formattedAddress
            ? _value.formattedAddress
            : formattedAddress // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$AddressImpl extends _Address {
  const _$AddressImpl({
    this.street,
    this.city,
    this.state,
    this.zip,
    this.country,
    this.latitude,
    this.longitude,
    this.formattedAddress,
  }) : super._();

  /// Street address (e.g., "123 Main St, Suite 100")
  @override
  final String? street;

  /// City name
  @override
  final String? city;

  /// State or province
  @override
  final String? state;

  /// Postal or ZIP code
  @override
  final String? zip;

  /// Country name
  @override
  final String? country;

  /// Latitude coordinate for mapping
  @override
  final double? latitude;

  /// Longitude coordinate for mapping
  @override
  final double? longitude;

  /// Full formatted address string
  @override
  final String? formattedAddress;

  @override
  String toString() {
    return 'Address(street: $street, city: $city, state: $state, zip: $zip, country: $country, latitude: $latitude, longitude: $longitude, formattedAddress: $formattedAddress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AddressImpl &&
            (identical(other.street, street) || other.street == street) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.zip, zip) || other.zip == zip) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.formattedAddress, formattedAddress) ||
                other.formattedAddress == formattedAddress));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    street,
    city,
    state,
    zip,
    country,
    latitude,
    longitude,
    formattedAddress,
  );

  /// Create a copy of Address
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AddressImplCopyWith<_$AddressImpl> get copyWith =>
      __$$AddressImplCopyWithImpl<_$AddressImpl>(this, _$identity);
}

abstract class _Address extends Address {
  const factory _Address({
    final String? street,
    final String? city,
    final String? state,
    final String? zip,
    final String? country,
    final double? latitude,
    final double? longitude,
    final String? formattedAddress,
  }) = _$AddressImpl;
  const _Address._() : super._();

  /// Street address (e.g., "123 Main St, Suite 100")
  @override
  String? get street;

  /// City name
  @override
  String? get city;

  /// State or province
  @override
  String? get state;

  /// Postal or ZIP code
  @override
  String? get zip;

  /// Country name
  @override
  String? get country;

  /// Latitude coordinate for mapping
  @override
  double? get latitude;

  /// Longitude coordinate for mapping
  @override
  double? get longitude;

  /// Full formatted address string
  @override
  String? get formattedAddress;

  /// Create a copy of Address
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AddressImplCopyWith<_$AddressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
