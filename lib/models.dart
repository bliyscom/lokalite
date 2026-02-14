class ChatMessage {
  final String id;
  final String role;
  final String content;
  final List<String>? images;
  final DateTime timestamp;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    this.images,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'images': images,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      role: json['role'] as String,
      content: json['content'] as String,
      images: (json['images'] as List?)?.map((e) => e as String).toList(),
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : null,
    );
  }
}

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;

  ChatSession({
    String? id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String?,
      title: json['title'] as String,
      messages: (json['messages'] as List?)
          ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    );
  }
}
