import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum MessageType { normal, entry, gift, system }

class ChatMessage {
  final String userId;
  final String userName;
  final String message;
  final int timestamp;
  final String? avatarUrl;
  final String? itemUrl;
  final MessageType type;
  final bool isEmojiReaction;
  final GiftData? giftData;
  final String? messageId;

  ChatMessage({
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
    this.avatarUrl,
    this.itemUrl,
    this.isEmojiReaction = false,
    this.type = MessageType.normal,
    this.giftData,
    this.messageId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      avatarUrl: json['avatarUrl'],
      itemUrl: json['itemUrl'],
      type: _getMessageTypeFromString(json['type'] ?? 'normal'),
      messageId: json['messageId'],
      isEmojiReaction: json['isEmojiReaction'] ?? false,
      giftData:
          json['giftData'] != null ? GiftData.fromJson(json['giftData']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'message': message,
      'timestamp': timestamp,
      'avatarUrl': avatarUrl,
      'itemUrl': itemUrl,
      'type': type.toString().split('.').last,
      'messageId': messageId,
      'isEmojiReaction': isEmojiReaction,
      'giftData': giftData?.toJson(),
    };
  }

  static MessageType _getMessageTypeFromString(String type) {
    switch (type) {
      case 'entry':
        return MessageType.entry;
      case 'gift':
        return MessageType.gift;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.normal;
    }
  }
}

class GiftData {
  final String receiverUserId;
  final String receiverUserName;
  final String giftName;
  final int giftCount;
  final String? giftUrl;
  final int totalCost;

  GiftData({
    required this.receiverUserId,
    required this.receiverUserName,
    required this.giftName,
    required this.giftCount,
    this.giftUrl,
    required this.totalCost,
  });

  factory GiftData.fromJson(Map<String, dynamic> json) {
    return GiftData(
      receiverUserId: json['receiverUserId'] ?? '',
      receiverUserName: json['receiverUserName'] ?? '',
      giftName: json['giftName'] ?? '',
      giftCount: json['giftCount'] ?? 0,
      giftUrl: json['giftUrl'],
      totalCost: json['totalCost'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receiverUserId': receiverUserId,
      'receiverUserName': receiverUserName,
      'giftName': giftName,
      'giftCount': giftCount,
      'giftUrl': giftUrl,
      'totalCost': totalCost,
    };
  }
}

class SocketMessageService {
  final IO.Socket socket;
  final String roomId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;

  final _messageController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messageStream => _messageController.stream;

  final _messageHistoryController =
      StreamController<List<ChatMessage>>.broadcast();
  Stream<List<ChatMessage>> get messageHistoryStream =>
      _messageHistoryController.stream;

  final _historyLoadStateController = StreamController<bool>.broadcast();
  Stream<bool> get historyLoadStateStream => _historyLoadStateController.stream;

  final List<ChatMessage> _messageHistory = [];
  List<ChatMessage> get messageHistory => List.unmodifiable(_messageHistory);

  bool _historyLoaded = false;
  bool get historyLoaded => _historyLoaded;

  bool _historyRequested = false;
  Timer? _historyTimeout;

  SocketMessageService({
    required this.socket,
    required this.roomId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
  }) {
    _initializeListeners();
    _requestHistoryWithTimeout();
  }

  void _initializeListeners() {
    // Listen for regular room messages
    socket.on('roomMessage', (data) {
      try {
        final message = ChatMessage.fromJson(data);
        _addMessageToHistory(message);
      } catch (e) {
        print('Error processing message: $e');
      }
    });

    // **ENHANCED: Listen for message history from database**
    socket.on('messageHistory', (data) {
      try {
        print(
            '📚 Received message history from database: ${data['count']} messages');

        final List<dynamic> messagesData = data['messages'] ?? [];
        final List<ChatMessage> historyMessages = messagesData
            .map((msgData) => ChatMessage.fromJson(msgData))
            .toList();

        // Clear current history and add database messages
        _messageHistory.clear();
        _messageHistory.addAll(historyMessages);

        // Mark history as loaded
        _historyLoaded = true;
        _historyRequested = true;

        // Cancel timeout if active
        _historyTimeout?.cancel();

        // Notify listeners
        _messageHistoryController.add(List.unmodifiable(_messageHistory));
        _historyLoadStateController.add(true);

        print(
            '📚 Loaded ${historyMessages.length} historical messages from database');
      } catch (e) {
        print('Error processing message history: $e');
        _markHistoryLoadComplete();
      }
    });

    // Listen for message history errors
    socket.on('messageHistoryError', (data) {
      print('❌ Error loading message history: ${data['error']}');
      _markHistoryLoadComplete();
    });

    // Listen for entry announcements
    socket.on('userEntry', (data) {
      try {
        final entryMessage = ChatMessage(
          userId: data['userId'],
          userName: data['userName'],
          message: 'has entered the room',
          timestamp: data['timestamp'],
          avatarUrl: data['userAvatar'],
          itemUrl: data['userItem'],
          type: MessageType.entry,
        );
        _addMessageToHistory(entryMessage);
      } catch (e) {
        print('Error processing entry message: $e');
      }
    });

    // Listen for gift messages
    socket.on('giftMessage', (data) {
      try {
        final giftMessage = ChatMessage(
          userId: data['senderUserId'],
          userName: data['senderUserName'],
          message: data['message'] ??
              'sent ${data['giftCount']}x ${data['giftName']} to ${data['receiverUserName']}',
          timestamp: data['timestamp'],
          type: MessageType.gift,
          giftData: GiftData(
            receiverUserId: data['receiverUserId'],
            receiverUserName: data['receiverUserName'],
            giftName: data['giftName'],
            giftCount: data['giftCount'],
            giftUrl: data['giftUrl'],
            totalCost: data['totalCost'],
          ),
        );
        _addMessageToHistory(giftMessage);
      } catch (e) {
        print('Error processing gift message: $e');
      }
    });

    // **ENHANCED: Listen for messages cleared event**
    socket.on('messagesCleared', (data) {
      try {
        print('🗑️ Messages cleared for room ${data['roomId']}');
        _messageHistory.clear();
        _messageHistoryController.add([]);

        // Add a system message about clearing
        final clearMessage = ChatMessage(
          userId: 'system',
          userName: 'System',
          message: 'Chat history has been cleared by an administrator',
          timestamp: data['timestamp'],
          type: MessageType.system,
        );
        _addMessageToHistory(clearMessage);
      } catch (e) {
        print('Error processing messages cleared: $e');
      }
    });

    // Listen for clear messages success
    socket.on('clearMessagesSuccess', (data) {
      print('✅ Successfully cleared ${data['deletedCount']} messages');
    });
  }

  // **NEW: Request history with timeout handling**
  void _requestHistoryWithTimeout() {
    if (_historyRequested || !socket.connected) return;

    _historyRequested = true;

    // Set timeout for history loading
    _historyTimeout = Timer(const Duration(seconds: 10), () {
      if (!_historyLoaded) {
        print('⏰ Message history request timed out');
        _markHistoryLoadComplete();
      }
    });

    // Request history from database
    requestMessageHistory();
  }

  // **NEW: Mark history loading as complete**
  void _markHistoryLoadComplete() {
    _historyLoaded = true;
    _historyTimeout?.cancel();
    _historyLoadStateController.add(true);
  }

  // **ENHANCED: Helper method to add messages to history with deduplication**
  void _addMessageToHistory(ChatMessage message) {
    // Simple deduplication based on userId, timestamp, and message content
    final isDuplicate = _messageHistory.any((existing) =>
        existing.userId == message.userId &&
        existing.timestamp == message.timestamp &&
        existing.message == message.message &&
        existing.type == message.type);

    if (!isDuplicate) {
      _messageHistory.add(message);
      _messageController.add(message);

      // Limit local history size to prevent memory issues
      if (_messageHistory.length > 500) {
        _messageHistory.removeAt(0);
      }

      // Notify history listeners
      _messageHistoryController.add(List.unmodifiable(_messageHistory));
    }
  }

  // **ENHANCED: Request message history with pagination support**
  void requestMessageHistory({int limit = 100, int? beforeTimestamp}) {
    if (!socket.connected) {
      print('❌ Socket not connected, cannot request message history');
      return;
    }

    final requestData = {
      'roomId': roomId,
      'limit': limit,
    };

    if (beforeTimestamp != null) {
      requestData['beforeTimestamp'] = beforeTimestamp;
    }

    socket.emit('requestMessageHistory', requestData);
    print('📚 Requested message history for room $roomId (limit: $limit)');
  }

  // **NEW: Load more historical messages (pagination)**
  void loadMoreHistory({int limit = 50}) {
    if (_messageHistory.isEmpty) {
      requestMessageHistory(limit: limit);
      return;
    }

    // Get timestamp of oldest message
    final oldestTimestamp = _messageHistory.first.timestamp;
    requestMessageHistory(limit: limit, beforeTimestamp: oldestTimestamp);
  }

  // **ENHANCED: Wait for history to load with better error handling**
  Future<bool> waitForHistoryLoad(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_historyLoaded) return true;

    try {
      await _historyLoadStateController.stream.timeout(timeout).first;
      return _historyLoaded;
    } catch (e) {
      print('⏰ Timeout or error waiting for message history: $e');
      _markHistoryLoadComplete();
      return false;
    }
  }

  // **NEW: Get message count**
  int get messageCount => _messageHistory.length;

  // **NEW: Get latest message**
  ChatMessage? get latestMessage =>
      _messageHistory.isNotEmpty ? _messageHistory.last : null;

  // **NEW: Get messages by type**
  List<ChatMessage> getMessagesByType(MessageType type) {
    return _messageHistory.where((msg) => msg.type == type).toList();
  }

  // **NEW: Search messages**
  List<ChatMessage> searchMessages(String query) {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return _messageHistory
        .where((msg) =>
            msg.message.toLowerCase().contains(lowerQuery) ||
            msg.userName.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // Existing methods with enhancements...
  void sendMessage(String message) {
    if (message.trim().isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
      'message': message,
      'timestamp': timestamp,
      'avatarUrl': userAvatarUrl,
      'type': 'normal',
    };

    socket.emit('roomMessage', data);
    print('📤 Sent message: $message');
  }

  void sendGiftMessage({
    required String receiverUserId,
    required String receiverUserName,
    required String giftName,
    required int giftCount,
    required String giftUrl,
    required int totalCost,
  }) {
    final data = {
      'roomId': roomId,
      'senderUserId': userId,
      'senderUserName': userName,
      'receiverUserId': receiverUserId,
      'receiverUserName': receiverUserName,
      'giftName': giftName,
      'giftCount': giftCount,
      'giftUrl': giftUrl,
      'totalCost': totalCost,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    socket.emit('giftSent', data);
    print('🎁 Sent gift: ${giftCount}x $giftName to $receiverUserName');
  }

  void announceEntry({String? itemUrl}) {
    final data = {
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatarUrl,
      'userItem': itemUrl,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    socket.emit('announceEntry', data);
    print('📢 Announced entry to room $roomId');
  }

  // **ENHANCED: Admin function to clear room messages with better error handling**
  void clearRoomMessages(String adminToken) {
    if (!socket.connected) {
      print('❌ Socket not connected, cannot clear messages');
      return;
    }

    final data = {
      'roomId': roomId,
      'userId': userId,
      'adminToken': adminToken,
    };

    socket.emit('clearRoomMessages', data);
    print('🗑️ Requested to clear room messages');
  }

  // **NEW: Retry connection and reload history**
  void retryConnection() {
    if (socket.connected) {
      _historyLoaded = false;
      _historyRequested = false;
      _requestHistoryWithTimeout();
    } else {
      print('❌ Socket not connected, cannot retry');
    }
  }

  // **NEW: Get connection status**
  bool get isConnected => socket.connected;

  // **ENHANCED: Dispose with proper cleanup**
  void dispose() {
    _historyTimeout?.cancel();
    _messageController.close();
    _messageHistoryController.close();
    _historyLoadStateController.close();
    print('🧹 SocketMessageService disposed');
  }
}
