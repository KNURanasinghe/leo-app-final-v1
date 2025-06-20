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
  final GiftData? giftData; // **NEW: Add gift data**

  ChatMessage({
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
    this.avatarUrl,
    this.itemUrl,
    this.isEmojiReaction = false,
    this.type = MessageType.normal,
    this.giftData, // **NEW**
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      userId: json['userId'],
      userName: json['userName'],
      message: json['message'],
      timestamp: json['timestamp'],
      avatarUrl: json['avatarUrl'],
      itemUrl: json['itemUrl'],
      type: _getMessageTypeFromString(json['type'] ?? 'normal'),
      giftData: json['giftData'] != null
          ? GiftData.fromJson(json['giftData'])
          : null, // **NEW**
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
      'giftData': giftData?.toJson(), // **NEW**
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

// **NEW: Gift data class**
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
      receiverUserId: json['receiverUserId'],
      receiverUserName: json['receiverUserName'],
      giftName: json['giftName'],
      giftCount: json['giftCount'],
      giftUrl: json['giftUrl'],
      totalCost: json['totalCost'],
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

  final List<ChatMessage> _messageHistory = [];
  List<ChatMessage> get messageHistory => List.unmodifiable(_messageHistory);

  SocketMessageService({
    required this.socket,
    required this.roomId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
  }) {
    _initializeListeners();
  }

  void _initializeListeners() {
    // Listen for regular room messages
    socket.on('roomMessage', (data) {
      try {
        final message = ChatMessage.fromJson(data);
        _messageHistory.add(message);
        _messageController.add(message);
      } catch (e) {
        print('Error processing message: $e');
      }
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
        _messageHistory.add(entryMessage);
        _messageController.add(entryMessage);
      } catch (e) {
        print('Error processing entry message: $e');
      }
    });

    // **NEW: Listen for gift messages**
    socket.on('giftMessage', (data) {
      try {
        final giftMessage = ChatMessage(
          userId: data['senderUserId'],
          userName: data['senderUserName'],
          message:
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
        _messageHistory.add(giftMessage);
        _messageController.add(giftMessage);
      } catch (e) {
        print('Error processing gift message: $e');
      }
    });
  }

  void sendMessage(String message) {
    if (message.trim().isEmpty) return;

    final data = {
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'avatarUrl': userAvatarUrl,
      'type': 'normal',
    };

    socket.emit('roomMessage', data);
  }

  // **NEW: Method to send gift message**
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

    //socket.emit('announceEntry', data);
  }

  void dispose() {
    _messageController.close();
  }
}
