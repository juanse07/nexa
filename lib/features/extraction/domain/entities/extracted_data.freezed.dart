// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'extracted_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ExtractedData {
  /// Unique identifier for this extraction
  String get id => throw _privateConstructorUsedError;

  /// Source type (pdf, image, text)
  String get sourceType => throw _privateConstructorUsedError;

  /// Original source file name or identifier
  String? get sourceName => throw _privateConstructorUsedError;

  /// Extracted structured data as JSON
  Map<String, dynamic> get data => throw _privateConstructorUsedError;

  /// Confidence score (0.0 to 1.0)
  double? get confidenceScore => throw _privateConstructorUsedError;

  /// List of fields that were extracted
  List<String> get extractedFields => throw _privateConstructorUsedError;

  /// List of fields that failed to extract
  List<String> get failedFields => throw _privateConstructorUsedError;

  /// Extraction method or model used
  String? get extractionMethod => throw _privateConstructorUsedError;

  /// When the extraction was performed
  DateTime get extractedAt => throw _privateConstructorUsedError;

  /// Processing time in milliseconds
  int? get processingTimeMs => throw _privateConstructorUsedError;

  /// Any errors or warnings during extraction
  List<String> get warnings => throw _privateConstructorUsedError;

  /// Whether the extraction was successful
  bool get isSuccessful => throw _privateConstructorUsedError;

  /// Additional metadata about the extraction
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Create a copy of ExtractedData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExtractedDataCopyWith<ExtractedData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExtractedDataCopyWith<$Res> {
  factory $ExtractedDataCopyWith(
    ExtractedData value,
    $Res Function(ExtractedData) then,
  ) = _$ExtractedDataCopyWithImpl<$Res, ExtractedData>;
  @useResult
  $Res call({
    String id,
    String sourceType,
    String? sourceName,
    Map<String, dynamic> data,
    double? confidenceScore,
    List<String> extractedFields,
    List<String> failedFields,
    String? extractionMethod,
    DateTime extractedAt,
    int? processingTimeMs,
    List<String> warnings,
    bool isSuccessful,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class _$ExtractedDataCopyWithImpl<$Res, $Val extends ExtractedData>
    implements $ExtractedDataCopyWith<$Res> {
  _$ExtractedDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExtractedData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceType = null,
    Object? sourceName = freezed,
    Object? data = null,
    Object? confidenceScore = freezed,
    Object? extractedFields = null,
    Object? failedFields = null,
    Object? extractionMethod = freezed,
    Object? extractedAt = null,
    Object? processingTimeMs = freezed,
    Object? warnings = null,
    Object? isSuccessful = null,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceType: null == sourceType
                ? _value.sourceType
                : sourceType // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceName: freezed == sourceName
                ? _value.sourceName
                : sourceName // ignore: cast_nullable_to_non_nullable
                      as String?,
            data: null == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            confidenceScore: freezed == confidenceScore
                ? _value.confidenceScore
                : confidenceScore // ignore: cast_nullable_to_non_nullable
                      as double?,
            extractedFields: null == extractedFields
                ? _value.extractedFields
                : extractedFields // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            failedFields: null == failedFields
                ? _value.failedFields
                : failedFields // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            extractionMethod: freezed == extractionMethod
                ? _value.extractionMethod
                : extractionMethod // ignore: cast_nullable_to_non_nullable
                      as String?,
            extractedAt: null == extractedAt
                ? _value.extractedAt
                : extractedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            processingTimeMs: freezed == processingTimeMs
                ? _value.processingTimeMs
                : processingTimeMs // ignore: cast_nullable_to_non_nullable
                      as int?,
            warnings: null == warnings
                ? _value.warnings
                : warnings // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isSuccessful: null == isSuccessful
                ? _value.isSuccessful
                : isSuccessful // ignore: cast_nullable_to_non_nullable
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
abstract class _$$ExtractedDataImplCopyWith<$Res>
    implements $ExtractedDataCopyWith<$Res> {
  factory _$$ExtractedDataImplCopyWith(
    _$ExtractedDataImpl value,
    $Res Function(_$ExtractedDataImpl) then,
  ) = __$$ExtractedDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String sourceType,
    String? sourceName,
    Map<String, dynamic> data,
    double? confidenceScore,
    List<String> extractedFields,
    List<String> failedFields,
    String? extractionMethod,
    DateTime extractedAt,
    int? processingTimeMs,
    List<String> warnings,
    bool isSuccessful,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class __$$ExtractedDataImplCopyWithImpl<$Res>
    extends _$ExtractedDataCopyWithImpl<$Res, _$ExtractedDataImpl>
    implements _$$ExtractedDataImplCopyWith<$Res> {
  __$$ExtractedDataImplCopyWithImpl(
    _$ExtractedDataImpl _value,
    $Res Function(_$ExtractedDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExtractedData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceType = null,
    Object? sourceName = freezed,
    Object? data = null,
    Object? confidenceScore = freezed,
    Object? extractedFields = null,
    Object? failedFields = null,
    Object? extractionMethod = freezed,
    Object? extractedAt = null,
    Object? processingTimeMs = freezed,
    Object? warnings = null,
    Object? isSuccessful = null,
    Object? metadata = null,
  }) {
    return _then(
      _$ExtractedDataImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceType: null == sourceType
            ? _value.sourceType
            : sourceType // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceName: freezed == sourceName
            ? _value.sourceName
            : sourceName // ignore: cast_nullable_to_non_nullable
                  as String?,
        data: null == data
            ? _value._data
            : data // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        confidenceScore: freezed == confidenceScore
            ? _value.confidenceScore
            : confidenceScore // ignore: cast_nullable_to_non_nullable
                  as double?,
        extractedFields: null == extractedFields
            ? _value._extractedFields
            : extractedFields // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        failedFields: null == failedFields
            ? _value._failedFields
            : failedFields // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        extractionMethod: freezed == extractionMethod
            ? _value.extractionMethod
            : extractionMethod // ignore: cast_nullable_to_non_nullable
                  as String?,
        extractedAt: null == extractedAt
            ? _value.extractedAt
            : extractedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        processingTimeMs: freezed == processingTimeMs
            ? _value.processingTimeMs
            : processingTimeMs // ignore: cast_nullable_to_non_nullable
                  as int?,
        warnings: null == warnings
            ? _value._warnings
            : warnings // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isSuccessful: null == isSuccessful
            ? _value.isSuccessful
            : isSuccessful // ignore: cast_nullable_to_non_nullable
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

class _$ExtractedDataImpl extends _ExtractedData {
  const _$ExtractedDataImpl({
    required this.id,
    required this.sourceType,
    this.sourceName,
    required final Map<String, dynamic> data,
    this.confidenceScore,
    final List<String> extractedFields = const [],
    final List<String> failedFields = const [],
    this.extractionMethod,
    required this.extractedAt,
    this.processingTimeMs,
    final List<String> warnings = const [],
    this.isSuccessful = true,
    final Map<String, dynamic> metadata = const {},
  }) : _data = data,
       _extractedFields = extractedFields,
       _failedFields = failedFields,
       _warnings = warnings,
       _metadata = metadata,
       super._();

  /// Unique identifier for this extraction
  @override
  final String id;

  /// Source type (pdf, image, text)
  @override
  final String sourceType;

  /// Original source file name or identifier
  @override
  final String? sourceName;

  /// Extracted structured data as JSON
  final Map<String, dynamic> _data;

  /// Extracted structured data as JSON
  @override
  Map<String, dynamic> get data {
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_data);
  }

  /// Confidence score (0.0 to 1.0)
  @override
  final double? confidenceScore;

  /// List of fields that were extracted
  final List<String> _extractedFields;

  /// List of fields that were extracted
  @override
  @JsonKey()
  List<String> get extractedFields {
    if (_extractedFields is EqualUnmodifiableListView) return _extractedFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_extractedFields);
  }

  /// List of fields that failed to extract
  final List<String> _failedFields;

  /// List of fields that failed to extract
  @override
  @JsonKey()
  List<String> get failedFields {
    if (_failedFields is EqualUnmodifiableListView) return _failedFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_failedFields);
  }

  /// Extraction method or model used
  @override
  final String? extractionMethod;

  /// When the extraction was performed
  @override
  final DateTime extractedAt;

  /// Processing time in milliseconds
  @override
  final int? processingTimeMs;

  /// Any errors or warnings during extraction
  final List<String> _warnings;

  /// Any errors or warnings during extraction
  @override
  @JsonKey()
  List<String> get warnings {
    if (_warnings is EqualUnmodifiableListView) return _warnings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_warnings);
  }

  /// Whether the extraction was successful
  @override
  @JsonKey()
  final bool isSuccessful;

  /// Additional metadata about the extraction
  final Map<String, dynamic> _metadata;

  /// Additional metadata about the extraction
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  String toString() {
    return 'ExtractedData(id: $id, sourceType: $sourceType, sourceName: $sourceName, data: $data, confidenceScore: $confidenceScore, extractedFields: $extractedFields, failedFields: $failedFields, extractionMethod: $extractionMethod, extractedAt: $extractedAt, processingTimeMs: $processingTimeMs, warnings: $warnings, isSuccessful: $isSuccessful, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExtractedDataImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sourceType, sourceType) ||
                other.sourceType == sourceType) &&
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            (identical(other.confidenceScore, confidenceScore) ||
                other.confidenceScore == confidenceScore) &&
            const DeepCollectionEquality().equals(
              other._extractedFields,
              _extractedFields,
            ) &&
            const DeepCollectionEquality().equals(
              other._failedFields,
              _failedFields,
            ) &&
            (identical(other.extractionMethod, extractionMethod) ||
                other.extractionMethod == extractionMethod) &&
            (identical(other.extractedAt, extractedAt) ||
                other.extractedAt == extractedAt) &&
            (identical(other.processingTimeMs, processingTimeMs) ||
                other.processingTimeMs == processingTimeMs) &&
            const DeepCollectionEquality().equals(other._warnings, _warnings) &&
            (identical(other.isSuccessful, isSuccessful) ||
                other.isSuccessful == isSuccessful) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    sourceType,
    sourceName,
    const DeepCollectionEquality().hash(_data),
    confidenceScore,
    const DeepCollectionEquality().hash(_extractedFields),
    const DeepCollectionEquality().hash(_failedFields),
    extractionMethod,
    extractedAt,
    processingTimeMs,
    const DeepCollectionEquality().hash(_warnings),
    isSuccessful,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of ExtractedData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExtractedDataImplCopyWith<_$ExtractedDataImpl> get copyWith =>
      __$$ExtractedDataImplCopyWithImpl<_$ExtractedDataImpl>(this, _$identity);
}

abstract class _ExtractedData extends ExtractedData {
  const factory _ExtractedData({
    required final String id,
    required final String sourceType,
    final String? sourceName,
    required final Map<String, dynamic> data,
    final double? confidenceScore,
    final List<String> extractedFields,
    final List<String> failedFields,
    final String? extractionMethod,
    required final DateTime extractedAt,
    final int? processingTimeMs,
    final List<String> warnings,
    final bool isSuccessful,
    final Map<String, dynamic> metadata,
  }) = _$ExtractedDataImpl;
  const _ExtractedData._() : super._();

  /// Unique identifier for this extraction
  @override
  String get id;

  /// Source type (pdf, image, text)
  @override
  String get sourceType;

  /// Original source file name or identifier
  @override
  String? get sourceName;

  /// Extracted structured data as JSON
  @override
  Map<String, dynamic> get data;

  /// Confidence score (0.0 to 1.0)
  @override
  double? get confidenceScore;

  /// List of fields that were extracted
  @override
  List<String> get extractedFields;

  /// List of fields that failed to extract
  @override
  List<String> get failedFields;

  /// Extraction method or model used
  @override
  String? get extractionMethod;

  /// When the extraction was performed
  @override
  DateTime get extractedAt;

  /// Processing time in milliseconds
  @override
  int? get processingTimeMs;

  /// Any errors or warnings during extraction
  @override
  List<String> get warnings;

  /// Whether the extraction was successful
  @override
  bool get isSuccessful;

  /// Additional metadata about the extraction
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of ExtractedData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExtractedDataImplCopyWith<_$ExtractedDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
