// In models/request_model.dart

class ChatRequest {
  final String requestId;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String? senderAvatar;
  final String status; // 'pending', 'approved', 'rejected'
  final int timestamp;

  ChatRequest({
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    this.senderAvatar,
    required this.status,
    required this.timestamp,
  });

  factory ChatRequest.fromJson(Map<String, dynamic> json) {
    return ChatRequest(
      requestId: json['requestId'] ?? '',
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      senderName: json['senderName'] ?? 'Unknown',
      senderAvatar: json['senderAvatar'],
      status: json['status'] ?? 'pending',
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'status': status,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'ChatRequest{requestId: $requestId, senderId: $senderId, receiverId: $receiverId, status: $status}';
  }
}
