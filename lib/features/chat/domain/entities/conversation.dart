class Conversation {
  const Conversation({
    required this.id,
    required this.updatedAt,
    this.managerId,
    this.managerName,
    this.managerEmail,
    this.managerPicture,
    this.userKey,
    this.userName,
    this.userEmail,
    this.userPicture,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.role,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      managerId: json['managerId'] as String?,
      managerName: json['managerName'] as String?,
      managerEmail: json['managerEmail'] as String?,
      managerPicture: json['managerPicture'] as String?,
      userKey: json['userKey'] as String?,
      userName: json['userName'] as String?,
      userEmail: json['userEmail'] as String?,
      userPicture: json['userPicture'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      unreadCount: json['unreadCount'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      role: json['role'] as String?,
    );
  }

  final String id;
  final String? managerId;
  final String? managerName;
  final String? managerEmail;
  final String? managerPicture;
  final String? userKey;
  final String? userName;
  final String? userEmail;
  final String? userPicture;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final DateTime updatedAt;
  final String? role;

  bool get isManagerPeer => role == 'Manager';

  String get displayName => managerName ?? userName ?? 'Unknown';
  String? get displayPicture => managerPicture ?? userPicture;
  String? get displayEmail => managerEmail ?? userEmail;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'managerId': managerId,
      'managerName': managerName,
      'managerEmail': managerEmail,
      'managerPicture': managerPicture,
      'userKey': userKey,
      'userName': userName,
      'userEmail': userEmail,
      'userPicture': userPicture,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessagePreview': lastMessagePreview,
      'unreadCount': unreadCount,
      'updatedAt': updatedAt.toIso8601String(),
      'role': role,
    };
  }
}
