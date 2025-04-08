class CallHistoryEntry {
  final String callId;
  final String callerId;
  final String receiverId;
  final bool isOutgoing; // true if current user initiated the call
  final bool isVideoCall;
  final bool isMissed;
  final int timestamp;
  final String? roomId;

  CallHistoryEntry({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.isOutgoing,
    required this.isVideoCall,
    required this.isMissed,
    required this.timestamp,
    this.roomId,
  });

  // Add factory method if you need to parse from JSON later
}
