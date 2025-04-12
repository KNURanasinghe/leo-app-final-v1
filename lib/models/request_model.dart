// chat_request_model.dart
class ChatRequest {
  final String requestId;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String? senderAvatar;
  final int timestamp;
  final String status; // 'pending', 'approved', 'rejected'

  ChatRequest({
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    this.senderAvatar,
    required this.timestamp,
    required this.status,
  });

  factory ChatRequest.fromJson(Map<String, dynamic> json) {
    return ChatRequest(
      requestId: json['requestId'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      senderName: json['senderName'],
      senderAvatar: json['senderAvatar'],
      timestamp: json['timestamp'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'timestamp': timestamp,
      'status': status,
    };
  }
}
