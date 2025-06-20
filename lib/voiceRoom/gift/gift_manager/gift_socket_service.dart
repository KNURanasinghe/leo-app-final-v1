// Create a singleton socket service
import 'package:leo_app_01/voiceRoom/inroom_message.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  static SocketService? _instance;
  static SocketService get instance {
    _instance ??= SocketService._internal();
    return _instance!;
  }

  SocketService._internal();

  IO.Socket? _socket;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserAvatarUrl;
  String? _currentRoomId;

  // Initialize the socket service
  void initialize({
    required IO.Socket socket,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required String roomId,
  }) {
    _socket = socket;
    _currentUserId = userId;
    _currentUserName = userName;
    _currentUserAvatarUrl = userAvatarUrl;
    _currentRoomId = roomId;
  }

  // Get message service for current room
  SocketMessageService? getMessageService() {
    if (_socket == null ||
        _currentUserId == null ||
        _currentUserName == null ||
        _currentRoomId == null) {
      return null;
    }

    return SocketMessageService(
      socket: _socket!,
      roomId: _currentRoomId!,
      userId: _currentUserId!,
      userName: _currentUserName!,
      userAvatarUrl: _currentUserAvatarUrl,
    );
  }

  // Send gift message directly
  void sendGiftMessage({
    required String receiverUserId,
    required String receiverUserName,
    required String giftName,
    required int giftCount,
    required String giftUrl,
    required int totalCost,
  }) {
    if (_socket == null ||
        _currentUserId == null ||
        _currentUserName == null ||
        _currentRoomId == null) {
      print('Socket service not properly initialized');
      return;
    }

    final data = {
      'roomId': _currentRoomId,
      'senderUserId': _currentUserId,
      'senderUserName': _currentUserName,
      'receiverUserId': receiverUserId,
      'receiverUserName': receiverUserName,
      'giftName': giftName,
      'giftCount': giftCount,
      'giftUrl': giftUrl,
      'totalCost': totalCost,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _socket!.emit('giftSent', data);
  }

  void dispose() {
    _socket = null;
    _currentUserId = null;
    _currentUserName = null;
    _currentUserAvatarUrl = null;
    _currentRoomId = null;
  }
}
