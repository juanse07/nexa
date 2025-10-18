class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.message,
    required this.createdAt,
    this.senderName,
    this.senderPicture,
    this.readByManager = false,
    this.readByUser = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderType: json['senderType'] as String == 'manager'
          ? SenderType.manager
          : SenderType.user,
      senderName: json['senderName'] as String?,
      senderPicture: json['senderPicture'] as String?,
      message: json['message'] as String,
      readByManager: json['readByManager'] as bool? ?? false,
      readByUser: json['readByUser'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String conversationId;
  final SenderType senderType;
  final String? senderName;
  final String? senderPicture;
  final String message;
  final bool readByManager;
  final bool readByUser;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'conversationId': conversationId,
      'senderType': senderType == SenderType.manager ? 'manager' : 'user',
      'senderName': senderName,
      'senderPicture': senderPicture,
      'message': message,
      'readByManager': readByManager,
      'readByUser': readByUser,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

enum SenderType {
  manager,
  user,
}
