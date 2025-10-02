// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'extraction_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ExtractionRequest {
  /// The source content (file path, base64 data, or text)
  String get source => throw _privateConstructorUsedError;

  /// The type of source (pdf, image, text)
  ExtractionSourceType get sourceType => throw _privateConstructorUsedError;

  /// Target schema or template for extraction
  String? get targetSchema => throw _privateConstructorUsedError;

  /// List of specific fields to extract
  List<String>? get fieldsToExtract => throw _privateConstructorUsedError;

  /// API key for the extraction service
  String? get apiKey => throw _privateConstructorUsedError;

  /// Additional extraction options
  Map<String, dynamic> get options => throw _privateConstructorUsedError;

  /// Create a copy of ExtractionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExtractionRequestCopyWith<ExtractionRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExtractionRequestCopyWith<$Res> {
  factory $ExtractionRequestCopyWith(
    ExtractionRequest value,
    $Res Function(ExtractionRequest) then,
  ) = _$ExtractionRequestCopyWithImpl<$Res, ExtractionRequest>;
  @useResult
  $Res call({
    String source,
    ExtractionSourceType sourceType,
    String? targetSchema,
    List<String>? fieldsToExtract,
    String? apiKey,
    Map<String, dynamic> options,
  });
}

/// @nodoc
class _$ExtractionRequestCopyWithImpl<$Res, $Val extends ExtractionRequest>
    implements $ExtractionRequestCopyWith<$Res> {
  _$ExtractionRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExtractionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? source = null,
    Object? sourceType = null,
    Object? targetSchema = freezed,
    Object? fieldsToExtract = freezed,
    Object? apiKey = freezed,
    Object? options = null,
  }) {
    return _then(
      _value.copyWith(
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceType: null == sourceType
                ? _value.sourceType
                : sourceType // ignore: cast_nullable_to_non_nullable
                      as ExtractionSourceType,
            targetSchema: freezed == targetSchema
                ? _value.targetSchema
                : targetSchema // ignore: cast_nullable_to_non_nullable
                      as String?,
            fieldsToExtract: freezed == fieldsToExtract
                ? _value.fieldsToExtract
                : fieldsToExtract // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            apiKey: freezed == apiKey
                ? _value.apiKey
                : apiKey // ignore: cast_nullable_to_non_nullable
                      as String?,
            options: null == options
                ? _value.options
                : options // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExtractionRequestImplCopyWith<$Res>
    implements $ExtractionRequestCopyWith<$Res> {
  factory _$$ExtractionRequestImplCopyWith(
    _$ExtractionRequestImpl value,
    $Res Function(_$ExtractionRequestImpl) then,
  ) = __$$ExtractionRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String source,
    ExtractionSourceType sourceType,
    String? targetSchema,
    List<String>? fieldsToExtract,
    String? apiKey,
    Map<String, dynamic> options,
  });
}

/// @nodoc
class __$$ExtractionRequestImplCopyWithImpl<$Res>
    extends _$ExtractionRequestCopyWithImpl<$Res, _$ExtractionRequestImpl>
    implements _$$ExtractionRequestImplCopyWith<$Res> {
  __$$ExtractionRequestImplCopyWithImpl(
    _$ExtractionRequestImpl _value,
    $Res Function(_$ExtractionRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExtractionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? source = null,
    Object? sourceType = null,
    Object? targetSchema = freezed,
    Object? fieldsToExtract = freezed,
    Object? apiKey = freezed,
    Object? options = null,
  }) {
    return _then(
      _$ExtractionRequestImpl(
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceType: null == sourceType
            ? _value.sourceType
            : sourceType // ignore: cast_nullable_to_non_nullable
                  as ExtractionSourceType,
        targetSchema: freezed == targetSchema
            ? _value.targetSchema
            : targetSchema // ignore: cast_nullable_to_non_nullable
                  as String?,
        fieldsToExtract: freezed == fieldsToExtract
            ? _value._fieldsToExtract
            : fieldsToExtract // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        apiKey: freezed == apiKey
            ? _value.apiKey
            : apiKey // ignore: cast_nullable_to_non_nullable
                  as String?,
        options: null == options
            ? _value._options
            : options // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc

class _$ExtractionRequestImpl extends _ExtractionRequest {
  const _$ExtractionRequestImpl({
    required this.source,
    required this.sourceType,
    this.targetSchema,
    final List<String>? fieldsToExtract,
    this.apiKey,
    final Map<String, dynamic> options = const {},
  }) : _fieldsToExtract = fieldsToExtract,
       _options = options,
       super._();

  /// The source content (file path, base64 data, or text)
  @override
  final String source;

  /// The type of source (pdf, image, text)
  @override
  final ExtractionSourceType sourceType;

  /// Target schema or template for extraction
  @override
  final String? targetSchema;

  /// List of specific fields to extract
  final List<String>? _fieldsToExtract;

  /// List of specific fields to extract
  @override
  List<String>? get fieldsToExtract {
    final value = _fieldsToExtract;
    if (value == null) return null;
    if (_fieldsToExtract is EqualUnmodifiableListView) return _fieldsToExtract;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// API key for the extraction service
  @override
  final String? apiKey;

  /// Additional extraction options
  final Map<String, dynamic> _options;

  /// Additional extraction options
  @override
  @JsonKey()
  Map<String, dynamic> get options {
    if (_options is EqualUnmodifiableMapView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_options);
  }

  @override
  String toString() {
    return 'ExtractionRequest(source: $source, sourceType: $sourceType, targetSchema: $targetSchema, fieldsToExtract: $fieldsToExtract, apiKey: $apiKey, options: $options)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExtractionRequestImpl &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.sourceType, sourceType) ||
                other.sourceType == sourceType) &&
            (identical(other.targetSchema, targetSchema) ||
                other.targetSchema == targetSchema) &&
            const DeepCollectionEquality().equals(
              other._fieldsToExtract,
              _fieldsToExtract,
            ) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    source,
    sourceType,
    targetSchema,
    const DeepCollectionEquality().hash(_fieldsToExtract),
    apiKey,
    const DeepCollectionEquality().hash(_options),
  );

  /// Create a copy of ExtractionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExtractionRequestImplCopyWith<_$ExtractionRequestImpl> get copyWith =>
      __$$ExtractionRequestImplCopyWithImpl<_$ExtractionRequestImpl>(
        this,
        _$identity,
      );
}

abstract class _ExtractionRequest extends ExtractionRequest {
  const factory _ExtractionRequest({
    required final String source,
    required final ExtractionSourceType sourceType,
    final String? targetSchema,
    final List<String>? fieldsToExtract,
    final String? apiKey,
    final Map<String, dynamic> options,
  }) = _$ExtractionRequestImpl;
  const _ExtractionRequest._() : super._();

  /// The source content (file path, base64 data, or text)
  @override
  String get source;

  /// The type of source (pdf, image, text)
  @override
  ExtractionSourceType get sourceType;

  /// Target schema or template for extraction
  @override
  String? get targetSchema;

  /// List of specific fields to extract
  @override
  List<String>? get fieldsToExtract;

  /// API key for the extraction service
  @override
  String? get apiKey;

  /// Additional extraction options
  @override
  Map<String, dynamic> get options;

  /// Create a copy of ExtractionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExtractionRequestImplCopyWith<_$ExtractionRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
