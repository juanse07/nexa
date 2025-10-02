// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Event {
  /// Unique identifier for the event
  String get id => throw _privateConstructorUsedError;

  /// Event title or name
  String get title => throw _privateConstructorUsedError;

  /// Reference to the client hosting this event
  String get clientId => throw _privateConstructorUsedError;

  /// Client name for display purposes
  String? get clientName => throw _privateConstructorUsedError;

  /// Event start date and time
  DateTime get startDate => throw _privateConstructorUsedError;

  /// Event end date and time
  DateTime get endDate => throw _privateConstructorUsedError;

  /// Venue or location name
  String? get venueName => throw _privateConstructorUsedError;

  /// Physical address of the event
  Address? get address => throw _privateConstructorUsedError;

  /// Current status of the event
  EventStatus get status => throw _privateConstructorUsedError;

  /// List of roles needed for this event
  List<EventRole> get roles => throw _privateConstructorUsedError;

  /// Additional notes or special instructions
  String? get notes => throw _privateConstructorUsedError;

  /// Contact person name for the event
  String? get contactName => throw _privateConstructorUsedError;

  /// Contact person phone number
  String? get contactPhone => throw _privateConstructorUsedError;

  /// Contact person email address
  String? get contactEmail => throw _privateConstructorUsedError;

  /// Setup time before the event starts
  DateTime? get setupTime => throw _privateConstructorUsedError;

  /// Expected total headcount/attendance
  int? get headcount => throw _privateConstructorUsedError;

  /// Dress code or uniform requirements
  String? get uniform => throw _privateConstructorUsedError;

  /// Special requirements or instructions
  String? get specialRequirements => throw _privateConstructorUsedError;

  /// When the event was created
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// When the event was last updated
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// User key of the creator
  String? get createdBy => throw _privateConstructorUsedError;

  /// Additional metadata as key-value pairs
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EventCopyWith<Event> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EventCopyWith<$Res> {
  factory $EventCopyWith(Event value, $Res Function(Event) then) =
      _$EventCopyWithImpl<$Res, Event>;
  @useResult
  $Res call({
    String id,
    String title,
    String clientId,
    String? clientName,
    DateTime startDate,
    DateTime endDate,
    String? venueName,
    Address? address,
    EventStatus status,
    List<EventRole> roles,
    String? notes,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    DateTime? setupTime,
    int? headcount,
    String? uniform,
    String? specialRequirements,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic> metadata,
  });

  $AddressCopyWith<$Res>? get address;
}

/// @nodoc
class _$EventCopyWithImpl<$Res, $Val extends Event>
    implements $EventCopyWith<$Res> {
  _$EventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? clientId = null,
    Object? clientName = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? venueName = freezed,
    Object? address = freezed,
    Object? status = null,
    Object? roles = null,
    Object? notes = freezed,
    Object? contactName = freezed,
    Object? contactPhone = freezed,
    Object? contactEmail = freezed,
    Object? setupTime = freezed,
    Object? headcount = freezed,
    Object? uniform = freezed,
    Object? specialRequirements = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? createdBy = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            clientId: null == clientId
                ? _value.clientId
                : clientId // ignore: cast_nullable_to_non_nullable
                      as String,
            clientName: freezed == clientName
                ? _value.clientName
                : clientName // ignore: cast_nullable_to_non_nullable
                      as String?,
            startDate: null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endDate: null == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            venueName: freezed == venueName
                ? _value.venueName
                : venueName // ignore: cast_nullable_to_non_nullable
                      as String?,
            address: freezed == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as Address?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as EventStatus,
            roles: null == roles
                ? _value.roles
                : roles // ignore: cast_nullable_to_non_nullable
                      as List<EventRole>,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            contactName: freezed == contactName
                ? _value.contactName
                : contactName // ignore: cast_nullable_to_non_nullable
                      as String?,
            contactPhone: freezed == contactPhone
                ? _value.contactPhone
                : contactPhone // ignore: cast_nullable_to_non_nullable
                      as String?,
            contactEmail: freezed == contactEmail
                ? _value.contactEmail
                : contactEmail // ignore: cast_nullable_to_non_nullable
                      as String?,
            setupTime: freezed == setupTime
                ? _value.setupTime
                : setupTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            headcount: freezed == headcount
                ? _value.headcount
                : headcount // ignore: cast_nullable_to_non_nullable
                      as int?,
            uniform: freezed == uniform
                ? _value.uniform
                : uniform // ignore: cast_nullable_to_non_nullable
                      as String?,
            specialRequirements: freezed == specialRequirements
                ? _value.specialRequirements
                : specialRequirements // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            metadata: null == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AddressCopyWith<$Res>? get address {
    if (_value.address == null) {
      return null;
    }

    return $AddressCopyWith<$Res>(_value.address!, (value) {
      return _then(_value.copyWith(address: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$EventImplCopyWith<$Res> implements $EventCopyWith<$Res> {
  factory _$$EventImplCopyWith(
    _$EventImpl value,
    $Res Function(_$EventImpl) then,
  ) = __$$EventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String clientId,
    String? clientName,
    DateTime startDate,
    DateTime endDate,
    String? venueName,
    Address? address,
    EventStatus status,
    List<EventRole> roles,
    String? notes,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    DateTime? setupTime,
    int? headcount,
    String? uniform,
    String? specialRequirements,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic> metadata,
  });

  @override
  $AddressCopyWith<$Res>? get address;
}

/// @nodoc
class __$$EventImplCopyWithImpl<$Res>
    extends _$EventCopyWithImpl<$Res, _$EventImpl>
    implements _$$EventImplCopyWith<$Res> {
  __$$EventImplCopyWithImpl(
    _$EventImpl _value,
    $Res Function(_$EventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? clientId = null,
    Object? clientName = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? venueName = freezed,
    Object? address = freezed,
    Object? status = null,
    Object? roles = null,
    Object? notes = freezed,
    Object? contactName = freezed,
    Object? contactPhone = freezed,
    Object? contactEmail = freezed,
    Object? setupTime = freezed,
    Object? headcount = freezed,
    Object? uniform = freezed,
    Object? specialRequirements = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? createdBy = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _$EventImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        clientId: null == clientId
            ? _value.clientId
            : clientId // ignore: cast_nullable_to_non_nullable
                  as String,
        clientName: freezed == clientName
            ? _value.clientName
            : clientName // ignore: cast_nullable_to_non_nullable
                  as String?,
        startDate: null == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endDate: null == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        venueName: freezed == venueName
            ? _value.venueName
            : venueName // ignore: cast_nullable_to_non_nullable
                  as String?,
        address: freezed == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as Address?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as EventStatus,
        roles: null == roles
            ? _value._roles
            : roles // ignore: cast_nullable_to_non_nullable
                  as List<EventRole>,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        contactName: freezed == contactName
            ? _value.contactName
            : contactName // ignore: cast_nullable_to_non_nullable
                  as String?,
        contactPhone: freezed == contactPhone
            ? _value.contactPhone
            : contactPhone // ignore: cast_nullable_to_non_nullable
                  as String?,
        contactEmail: freezed == contactEmail
            ? _value.contactEmail
            : contactEmail // ignore: cast_nullable_to_non_nullable
                  as String?,
        setupTime: freezed == setupTime
            ? _value.setupTime
            : setupTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        headcount: freezed == headcount
            ? _value.headcount
            : headcount // ignore: cast_nullable_to_non_nullable
                  as int?,
        uniform: freezed == uniform
            ? _value.uniform
            : uniform // ignore: cast_nullable_to_non_nullable
                  as String?,
        specialRequirements: freezed == specialRequirements
            ? _value.specialRequirements
            : specialRequirements // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        metadata: null == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc

class _$EventImpl extends _Event {
  const _$EventImpl({
    required this.id,
    required this.title,
    required this.clientId,
    this.clientName,
    required this.startDate,
    required this.endDate,
    this.venueName,
    this.address,
    this.status = EventStatus.draft,
    final List<EventRole> roles = const [],
    this.notes,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.setupTime,
    this.headcount,
    this.uniform,
    this.specialRequirements,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    final Map<String, dynamic> metadata = const {},
  }) : _roles = roles,
       _metadata = metadata,
       super._();

  /// Unique identifier for the event
  @override
  final String id;

  /// Event title or name
  @override
  final String title;

  /// Reference to the client hosting this event
  @override
  final String clientId;

  /// Client name for display purposes
  @override
  final String? clientName;

  /// Event start date and time
  @override
  final DateTime startDate;

  /// Event end date and time
  @override
  final DateTime endDate;

  /// Venue or location name
  @override
  final String? venueName;

  /// Physical address of the event
  @override
  final Address? address;

  /// Current status of the event
  @override
  @JsonKey()
  final EventStatus status;

  /// List of roles needed for this event
  final List<EventRole> _roles;

  /// List of roles needed for this event
  @override
  @JsonKey()
  List<EventRole> get roles {
    if (_roles is EqualUnmodifiableListView) return _roles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_roles);
  }

  /// Additional notes or special instructions
  @override
  final String? notes;

  /// Contact person name for the event
  @override
  final String? contactName;

  /// Contact person phone number
  @override
  final String? contactPhone;

  /// Contact person email address
  @override
  final String? contactEmail;

  /// Setup time before the event starts
  @override
  final DateTime? setupTime;

  /// Expected total headcount/attendance
  @override
  final int? headcount;

  /// Dress code or uniform requirements
  @override
  final String? uniform;

  /// Special requirements or instructions
  @override
  final String? specialRequirements;

  /// When the event was created
  @override
  final DateTime? createdAt;

  /// When the event was last updated
  @override
  final DateTime? updatedAt;

  /// User key of the creator
  @override
  final String? createdBy;

  /// Additional metadata as key-value pairs
  final Map<String, dynamic> _metadata;

  /// Additional metadata as key-value pairs
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  String toString() {
    return 'Event(id: $id, title: $title, clientId: $clientId, clientName: $clientName, startDate: $startDate, endDate: $endDate, venueName: $venueName, address: $address, status: $status, roles: $roles, notes: $notes, contactName: $contactName, contactPhone: $contactPhone, contactEmail: $contactEmail, setupTime: $setupTime, headcount: $headcount, uniform: $uniform, specialRequirements: $specialRequirements, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.clientId, clientId) ||
                other.clientId == clientId) &&
            (identical(other.clientName, clientName) ||
                other.clientName == clientName) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.venueName, venueName) ||
                other.venueName == venueName) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._roles, _roles) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.contactName, contactName) ||
                other.contactName == contactName) &&
            (identical(other.contactPhone, contactPhone) ||
                other.contactPhone == contactPhone) &&
            (identical(other.contactEmail, contactEmail) ||
                other.contactEmail == contactEmail) &&
            (identical(other.setupTime, setupTime) ||
                other.setupTime == setupTime) &&
            (identical(other.headcount, headcount) ||
                other.headcount == headcount) &&
            (identical(other.uniform, uniform) || other.uniform == uniform) &&
            (identical(other.specialRequirements, specialRequirements) ||
                other.specialRequirements == specialRequirements) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    title,
    clientId,
    clientName,
    startDate,
    endDate,
    venueName,
    address,
    status,
    const DeepCollectionEquality().hash(_roles),
    notes,
    contactName,
    contactPhone,
    contactEmail,
    setupTime,
    headcount,
    uniform,
    specialRequirements,
    createdAt,
    updatedAt,
    createdBy,
    const DeepCollectionEquality().hash(_metadata),
  ]);

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EventImplCopyWith<_$EventImpl> get copyWith =>
      __$$EventImplCopyWithImpl<_$EventImpl>(this, _$identity);
}

abstract class _Event extends Event {
  const factory _Event({
    required final String id,
    required final String title,
    required final String clientId,
    final String? clientName,
    required final DateTime startDate,
    required final DateTime endDate,
    final String? venueName,
    final Address? address,
    final EventStatus status,
    final List<EventRole> roles,
    final String? notes,
    final String? contactName,
    final String? contactPhone,
    final String? contactEmail,
    final DateTime? setupTime,
    final int? headcount,
    final String? uniform,
    final String? specialRequirements,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final String? createdBy,
    final Map<String, dynamic> metadata,
  }) = _$EventImpl;
  const _Event._() : super._();

  /// Unique identifier for the event
  @override
  String get id;

  /// Event title or name
  @override
  String get title;

  /// Reference to the client hosting this event
  @override
  String get clientId;

  /// Client name for display purposes
  @override
  String? get clientName;

  /// Event start date and time
  @override
  DateTime get startDate;

  /// Event end date and time
  @override
  DateTime get endDate;

  /// Venue or location name
  @override
  String? get venueName;

  /// Physical address of the event
  @override
  Address? get address;

  /// Current status of the event
  @override
  EventStatus get status;

  /// List of roles needed for this event
  @override
  List<EventRole> get roles;

  /// Additional notes or special instructions
  @override
  String? get notes;

  /// Contact person name for the event
  @override
  String? get contactName;

  /// Contact person phone number
  @override
  String? get contactPhone;

  /// Contact person email address
  @override
  String? get contactEmail;

  /// Setup time before the event starts
  @override
  DateTime? get setupTime;

  /// Expected total headcount/attendance
  @override
  int? get headcount;

  /// Dress code or uniform requirements
  @override
  String? get uniform;

  /// Special requirements or instructions
  @override
  String? get specialRequirements;

  /// When the event was created
  @override
  DateTime? get createdAt;

  /// When the event was last updated
  @override
  DateTime? get updatedAt;

  /// User key of the creator
  @override
  String? get createdBy;

  /// Additional metadata as key-value pairs
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of Event
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EventImplCopyWith<_$EventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
