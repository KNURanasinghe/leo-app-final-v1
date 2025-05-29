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
  final String? itemUrl; // Add this for entry animations
  final MessageType type; // Add this for message types
  final bool isEmojiReaction;

  ChatMessage({
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
    this.avatarUrl,
    this.itemUrl,
    this.isEmojiReaction = false,
    this.type = MessageType.normal,
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
      'type': type.toString().split('.').last, // Convert enum to string
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

class SocketMessageService {
  final IO.Socket socket;
  final String roomId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;

  final _messageController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messageStream => _messageController.stream;

  // Keep track of message history
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
