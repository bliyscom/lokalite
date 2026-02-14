class ChatMessage {
  final String role;
  final String content;
  final List<String>? images;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.images,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'role': role,
      'content': content,
    };
    if (images != null && images!.isNotEmpty) {
      data['images'] = images;
    }
    return data;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      images: (json['images'] as List?)?.map((e) => e as String).toList(),
    );
  }
}
