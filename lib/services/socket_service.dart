import 'package:leo_app_01/Provider/call_history_provider.dart';
import 'package:leo_app_01/models/call_istory_model.dart';
import 'package:leo_app_01/models/request_model.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/app_constants.dart';
import '../models/message.dart';
import '../models/status_model.dart';

typedef MessageDeletedCallback = void Function(
    String messageId, bool forEveryone);
typedef MessageDeletedByOtherCallback = void Function(
    String messageId, String senderId);
typedef BroadcastUnreadCountsCallback = void Function(Map<String, int> counts);
typedef BroadcastMarkedAsReadCallback = void Function(String adminId);

typedef MessageCallback = void Function(Message message);
typedef MessagesCallback = void Function(List<Message> messages);
typedef DeliveredCallback = void Function(String messageId);
typedef ReadCallback = void Function(String messageId);
typedef TypingCallback = void Function(String userId);
typedef UserStatusCallback = void Function(Map<String, dynamic> statusMap);

// Call callback typedefs
typedef CallRequestCallback = void Function(Map<String, dynamic> callData);
typedef CallResponseCallback = void Function(Map<String, dynamic> callData);
typedef CallEndedCallback = void Function(Map<String, dynamic> callData);

// Status callbacks
typedef StatusPostedCallback = void Function(Map<String, dynamic> statusData);
typedef ActiveStatusesCallback = void Function(List<StatusUser> users);
typedef UserStatusesCallback = void Function(
    String userId, List<Status> statuses);

typedef BroadcastSentCallback = void Function(
    Map<String, dynamic> broadcastData);

typedef VoidCallback = void Function();
typedef ErrorCallback = void Function(dynamic error);
typedef ErrorDataCallback = void Function(Map<String, dynamic> errorData);
typedef ChattedUsersCallback = void Function(
    List<String> users); // New callback type
typedef AdminUsersCallback = void Function(List<Map<String, dynamic>> admins);

// Add these typedefs to your existing ones in socket_service.dart
typedef StatusLikedCallback = void Function(String statusId, int likeCount);
typedef StatusUnlikedCallback = void Function(String statusId, int likeCount);
typedef StatusLikesCallback = void Function(
    String statusId, List<String> likedBy, int likeCount);
typedef StatusLikeStatusCallback = void Function(
    String statusId, bool hasLiked, int likeCount);

typedef ChatRequestReceivedCallback = void Function(ChatRequest request);
typedef ChatRequestUpdatedCallback = void Function(ChatRequest request);
typedef ChatRequestsListCallback = void Function(List<ChatRequest> requests);

class SocketService {
  static SocketService? _instance;
  late IO.Socket _socket;
  String? _currentUserId;
  VoidCallback? onConnect;
  ErrorCallback? onConnectError;
  ErrorDataCallback? onError;
  // Existing callbacks
  MessageCallback? onNewMessage;
  MessagesCallback? onChatHistory;
  DeliveredCallback? onMessageDelivered;
  ReadCallback? onMessageRead;
  TypingCallback? onUserTyping;
  TypingCallback? onUserStoppedTyping;
  UserStatusCallback? onUserStatus;
  ChattedUsersCallback? onChattedUsers;
  // Add these properties
  StatusPostedCallback? onStatusPosted;
  ActiveStatusesCallback? onActiveStatuses;
  UserStatusesCallback? onUserStatuses;

  BroadcastSentCallback? onBroadcastSent;
  MessagesCallback? onBroadcastHistory;

  // Call callbacks
  CallRequestCallback? onIncomingCall; // renamed for clarity
  CallResponseCallback? onCallAccepted;
  CallResponseCallback? onCallRejected;
  CallEndedCallback? onCallEnded;
  CallResponseCallback? onCallRequested; // feedback to caller

  MessageDeletedCallback? onMessageDeleted;
  MessageDeletedByOtherCallback? onMessageDeletedByOther;

  BroadcastUnreadCountsCallback? onBroadcastUnreadCounts;
  BroadcastMarkedAsReadCallback? onBroadcastMarkedAsRead;

  // Add these properties to your SocketService class
  StatusLikedCallback? onStatusLiked;
  StatusUnlikedCallback? onStatusUnliked;
  StatusLikesCallback? onStatusLikes;
  StatusLikeStatusCallback? onStatusLikeStatus;
  Function(Message)? onStatusShareMessage;
  Function(String blockedUserId)? onUserBlocked;
  Function(String unblockedUserId)? onUserUnblocked;
  Function(List<String> blockedUsers)? onBlockedUsersList;
  Function(bool isUserBlocked, bool isOtherUserBlocked)? onBlockedStatus;
  Function(String blockedByUserId)? onBlockedByUser;
  Function(String receiverId, String reason)? onMessageBlocked;
  Function(Status)? onSingleStatus;

  // Keep track of processed message IDs to prevent duplicates
  final Set<String> _processedMessageIds = {};
  Function(Map<String, dynamic>)? onUnreadCountUpdate;
  Function(Map<String, int>)? onUnreadCounts;
  AdminUsersCallback? onAdminUsersList;

  // Add these new properties to your SocketService class
  ChatRequestReceivedCallback? onChatRequestReceived;
  ChatRequestUpdatedCallback? onChatRequestUpdated;
  ChatRequestsListCallback? onChatRequestsList;
  IO.Socket get socket => _socket;
  bool isAdmin(String userId) {
    return AppConstants.adminUsers.containsKey(userId);
  }

  // Singleton pattern
  factory SocketService() {
    _instance ??= SocketService._internal();
    return _instance!;
  }

  SocketService._internal() {
    _initSocket();
    _setupBlockListeners();
    _setupBroadcastListeners();
    _setupStatusLikeListeners();
    _setupChatRequestListeners();
  }
  void _setupStatusLikeListeners() {
    _socket.on('statusLiked', (data) {
      print(
          '👍 Status liked: ${data['statusId']}, count: ${data['likeCount']}');
      if (onStatusLiked != null) {
        onStatusLiked!(data['statusId'], data['likeCount']);
      }
    });

    _socket.on('statusUnliked', (data) {
      print(
          '👎 Status unliked: ${data['statusId']}, count: ${data['likeCount']}');
      if (onStatusUnliked != null) {
        onStatusUnliked!(data['statusId'], data['likeCount']);
      }
    });

    _socket.on('statusLikes', (data) {
      if (onStatusLikes != null && data['likedBy'] != null) {
        List<String> likedBy = List<String>.from(data['likedBy']);
        onStatusLikes!(data['statusId'], likedBy, data['likeCount']);
      }
    });

    _socket.on('statusLikeStatus', (data) {
      if (onStatusLikeStatus != null) {
        onStatusLikeStatus!(
            data['statusId'], data['hasLiked'], data['likeCount']);
      }
    });
  }

  // Add this to your _setupSocketListeners() method
  // These are the methods from SocketService that handle chat requests
// Add these fixes to your SocketService class

  // Add or update these methods in your SocketService class

  void _setupChatRequestListeners() {
    // Direct event listener for chatRequestReceived
    _socket.on('chatRequestReceived', (data) {
      print('📩 Received chat request: $data');
      try {
        if (data != null) {
          // Make sure the data has the required fields
          if (data['requestId'] == null ||
              data['senderId'] == null ||
              data['receiverId'] == null) {
            print('⚠️ Received incomplete chat request data: $data');
            return;
          }

          // Add default status if missing (should be 'pending' for new requests)
          if (data['status'] == null) {
            data['status'] = 'pending';
          }

          if (onChatRequestReceived != null) {
            onChatRequestReceived!(ChatRequest.fromJson(data));
          }
        } else {
          print('⚠️ Received null data for chatRequestReceived event');
        }
      } catch (e) {
        print('❌ Error processing chat request received: $e');
      }
    });

    // Direct event listener for chatRequestUpdated
    _socket.on('chatRequestUpdated', (data) {
      print('🔄 Chat request updated: $data');
      try {
        if (data != null) {
          if (onChatRequestUpdated != null) {
            onChatRequestUpdated!(ChatRequest.fromJson(data));
          }
        } else {
          print('⚠️ Received null data for chatRequestUpdated event');
        }
      } catch (e) {
        print('❌ Error processing chat request update: $e');
      }
    });

    // Direct event listener for chatRequestStatus
    _socket.on('chatRequestStatus', (data) {
      print('📋 Received chat request status: $data');
      try {
        if (data != null && onChatRequestUpdated != null) {
          // If there's a request object included, use that
          if (data['request'] != null) {
            onChatRequestUpdated!(ChatRequest.fromJson(data['request']));
            return;
          }

          // Otherwise convert status response to full ChatRequest object
          final ChatRequest request = ChatRequest(
            requestId: data['requestId'] ??
                'status_${DateTime.now().millisecondsSinceEpoch}',
            senderId: data['senderId'] ?? '',
            receiverId: data['receiverId'] ?? '',
            senderName: data['senderName'] ?? 'Unknown',
            senderAvatar: data['senderAvatar'],
            status: data['status'] ?? 'none',
            timestamp:
                data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          );
          onChatRequestUpdated!(request);
        }
      } catch (e) {
        print('❌ Error processing chat request status: $e');
      }
    });

    // Direct event listener for chatRequestsList
    _socket.on('chatRequestsList', (data) {
      print('📋 Received chat requests list data: $data');
      try {
        if (onChatRequestsList != null && data != null) {
          List<ChatRequest> requests = [];

          // Case 1: The server sends {requests: [...]}
          if (data is Map && data['requests'] != null) {
            final List<dynamic> requestsJson = data['requests'];
            print('Found ${requestsJson.length} requests in data[requests]');

            for (var req in requestsJson) {
              try {
                requests.add(ChatRequest.fromJson(req));
                print(
                    '✓ Parsed request: ${req['requestId']} - status: ${req['status']}');
              } catch (e) {
                print('⚠️ Error parsing chat request: $e');
                print('Request data that failed: $req');
              }
            }
          }
          // Case 2: The server sends a direct array of requests
          else if (data is List) {
            final List<dynamic> requestsJson = data;
            print('Found ${requestsJson.length} requests in direct array');

            for (var req in requestsJson) {
              try {
                requests.add(ChatRequest.fromJson(req));
              } catch (e) {
                print('⚠️ Error parsing chat request from array: $e');
              }
            }
          }

          print('✅ Processed ${requests.length} chat requests');
          onChatRequestsList!(requests);
        } else {
          print('⚠️ Missing callback or data for chatRequestsList');
          // If no data but callback exists, provide empty list
          if (onChatRequestsList != null) {
            onChatRequestsList!([]);
          }
        }
      } catch (e) {
        print('❌ Error processing chat requests list: $e');
        // Provide an empty list on error
        if (onChatRequestsList != null) {
          onChatRequestsList!([]);
        }
      }
    });
  }

// Enhanced method for getting pending chat requests
  void getPendingChatRequests(String userId) {
    print('🔍 Fetching pending chat requests for user: $userId');

    if (!_socket.connected) {
      print(
          "⚠️ Socket not connected for fetching requests. Attempting to connect...");
      connect(userId);

      // Try again after connection is established
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_socket.connected) {
          print("✅ Socket reconnected, now fetching chat requests");
          _emitChatRequestQueries(userId);
        } else {
          print("❌ Failed to reconnect for pending chat requests");
          // Notify with empty list in case of connection failure
          if (onChatRequestsList != null) {
            onChatRequestsList!([]);
          }
        }
      });
      return;
    }

    _emitChatRequestQueries(userId);
  }

// Helper method to try multiple event formats
  void _emitChatRequestQueries(String userId) {
    // Try the standard event
    _socket.emit('getPendingChatRequests', {
      'userId': userId,
    });

    // Try alternate event name the server might be using
    _socket.emit('getChatRequests', {'userId': userId, 'status': 'pending'});

    // Try a third possible format
    _socket.emit(
        'fetchChatRequests', {'userId': userId, 'statusFilter': 'pending'});

    // Send a debug ping to verify communication
    _socket.emit('ping_test', {
      'action': 'Requested pending chat requests',
      'userId': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    });
  }

// Enhanced method for checking chat request status
  void checkChatRequestStatus(String senderId, String receiverId) {
    print('🔍 Checking chat request status between $senderId and $receiverId');

    if (!_socket.connected) {
      print(
          "⚠️ Socket not connected for checking status. Attempting to connect...");
      connect(senderId);

      // Try again after connection is established
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_socket.connected) {
          print("✅ Socket reconnected, now checking chat request status");
          _emitStatusCheckQueries(senderId, receiverId);
        } else {
          print("❌ Failed to reconnect for chat request status");
        }
      });
      return;
    }

    _emitStatusCheckQueries(senderId, receiverId);
  }

// Helper method to try multiple status check formats
  void _emitStatusCheckQueries(String senderId, String receiverId) {
    // Try the standard event
    _socket.emit('checkChatRequestStatus', {
      'senderId': senderId,
      'receiverId': receiverId,
    });

    // Try an alternate format
    _socket.emit('getChatRequestStatus', {
      'senderId': senderId,
      'receiverId': receiverId,
    });

    // Also try just getting all pending requests (server might filter there)
    _socket.emit('getPendingChatRequests', {
      'userId': receiverId,
    });
  }

// Enhanced method for sending chat requests with better error handling
  void sendChatRequest(String senderId, String receiverId, String senderName,
      String? senderAvatar) {
    print('📤 Sending chat request from $senderId to $receiverId');

    // Check connection first
    if (!_socket.connected) {
      print(
          "⚠️ Socket not connected for sending chat request. Attempting to connect...");
      connect(senderId);

      // Try again after connection is established
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_socket.connected) {
          print("✅ Socket reconnected, now sending chat request");
          _emitChatRequest(senderId, receiverId, senderName, senderAvatar);
        } else {
          print("❌ Failed to reconnect for chat request");
          if (onError != null) {
            onError!({
              "message": "Failed to connect to server for sending chat request"
            });
          }
        }
      });
      return;
    }

    _emitChatRequest(senderId, receiverId, senderName, senderAvatar);
  }

// Helper method to emit chat request with proper data format
  void _emitChatRequest(String senderId, String receiverId, String senderName,
      String? senderAvatar) {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final requestId = 'req_${senderId}_${receiverId}_$timestamp';

      // Debug connection status
      print(
          '🔌 Socket connected: ${_socket.connected}, Socket ID: ${_socket.id}');

      // Create request payload with all required fields
      final requestPayload = {
        'requestId': requestId,
        'senderId': senderId,
        'receiverId': receiverId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'timestamp': timestamp,
        'status': 'pending', // Explicitly set status
      };

      // Send the request using the standard event name
      _socket.emit('sendChatRequest', requestPayload);

      // Also try alternative event name that the server might be using
      _socket.emit('createChatRequest', requestPayload);

      print('📤 Emitted chat request: $requestId');

      // Add a ping to make sure server connection is alive
      _socket.emit('ping_test', {
        'action': 'Sent chat request',
        'timestamp': timestamp,
        'requestId': requestId
      });

      // Create a local ChatRequest object to help update UI immediately
      final newRequest = ChatRequest(
        requestId: requestId,
        senderId: senderId,
        receiverId: receiverId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        status: 'pending',
        timestamp: timestamp,
      );

      // If we have a callback for chat request updates, notify it
      if (onChatRequestUpdated != null) {
        onChatRequestUpdated!(newRequest);
      }
    } catch (e) {
      print('❌ Error sending chat request: $e');
      if (onError != null) {
        onError!({"message": "Error sending chat request: $e"});
      }
    }
  }

// Enhanced method for responding to chat requests with better error handling
  void respondToChatRequest(
      String requestId, String receiverId, String senderId, bool approved) {
    print(
        '📤 Responding to chat request $requestId: ${approved ? 'Approved' : 'Rejected'}');

    if (!_socket.connected) {
      print(
          "⚠️ Socket not connected for chat request response. Attempting to connect...");
      connect(receiverId);

      // Try again after connection is established
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_socket.connected) {
          print("✅ Socket reconnected, now sending chat request response");
          _emitChatRequestResponse(requestId, receiverId, senderId, approved);
        } else {
          print("❌ Failed to reconnect for chat request response");
          if (onError != null) {
            onError!({
              "message":
                  "Failed to connect to server for sending chat request response"
            });
          }
        }
      });
      return;
    }

    _emitChatRequestResponse(requestId, receiverId, senderId, approved);
  }

// Helper method for sending chat request responses
  void _emitChatRequestResponse(
      String requestId, String receiverId, String senderId, bool approved) {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Create the request payload
      final responsePayload = {
        'requestId': requestId,
        'receiverId': receiverId,
        'senderId': senderId,
        'approved': approved,
        'timestamp': timestamp,
      };

      // Send using the standard event name
      _socket.emit('respondToChatRequest', responsePayload);

      // Also try alternative event name
      _socket.emit('updateChatRequest', {
        ...responsePayload,
        'status': approved ? 'approved' : 'rejected',
      });

      print(
          '📤 Emitted chat request response: $requestId, approved: $approved');

      // Add a ping to make sure server connection is alive
      _socket.emit('ping_test', {
        'action': 'Responded to chat request',
        'requestId': requestId,
        'approved': approved,
        'timestamp': timestamp
      });

      // Create local ChatRequest for immediate UI update
      final updatedRequest = ChatRequest(
        requestId: requestId,
        senderId: senderId,
        receiverId: receiverId,
        senderName: '', // We might not have this info
        senderAvatar: null,
        status: approved ? 'approved' : 'rejected',
        timestamp: timestamp,
      );

      // If we have a callback for chat request updates, notify it
      if (onChatRequestUpdated != null) {
        onChatRequestUpdated!(updatedRequest);
      }
    } catch (e) {
      print('❌ Error responding to chat request: $e');
      if (onError != null) {
        onError!({"message": "Error responding to chat request: $e"});
      }
    }
  }

// Improved implementations of chat request methods

  void _setupBroadcastListeners() {
    _socket.on('broadcastSent', (data) {
      print('✅ Broadcast sent confirmation: $data');
      if (onBroadcastSent != null) {
        onBroadcastSent!(Map<String, dynamic>.from(data));
      }
    });
    _socket.on('broadcastUnreadCounts', (data) {
      print('📢 Received broadcast unread counts: ${data['counts']}');
      if (onBroadcastUnreadCounts != null && data['counts'] != null) {
        onBroadcastUnreadCounts!(Map<String, int>.from(data['counts']));
      }
    });

    _socket.on('broadcastMarkedAsRead', (data) {
      print('✓ Broadcasts from ${data['adminId']} marked as read');
      if (onBroadcastMarkedAsRead != null && data['adminId'] != null) {
        onBroadcastMarkedAsRead!(data['adminId']);
      }
    });

    // For broadcast history
    _socket.on('broadcastHistory', (data) {
      print('📜 Received broadcast history');
      if (onBroadcastHistory != null && data['messages'] != null) {
        final List<dynamic> messagesJson = data['messages'];
        final List<Message> messages = [];
        for (var msg in messagesJson) {
          final message = Message.fromJson(msg);
          messages.add(message);
        }
        // Sort by timestamp
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        onBroadcastHistory!(messages);
      }
    });

    // Admin users list
    _socket.on('adminUsersList', (data) {
      print('👤 Received admin users list');
      if (onAdminUsersList != null && data['admins'] != null) {
        final List<dynamic> adminsJson = data['admins'];
        final List<Map<String, dynamic>> admins = adminsJson
            .map((admin) => Map<String, dynamic>.from(admin))
            .toList();
        onAdminUsersList!(admins);
      }
    });
  }

  void _setupBlockListeners() {
    _socket.on('userBlocked', (data) {
      if (onUserBlocked != null) {
        onUserBlocked!(data['blockedUserId']);
      }
    });

    _socket.on('userUnblocked', (data) {
      if (onUserUnblocked != null) {
        onUserUnblocked!(data['unblockedUserId']);
      }
    });

    _socket.on('blockedUsersList', (data) {
      if (onBlockedUsersList != null) {
        List<String> blockedUsers = List<String>.from(data['blockedUsers']);
        onBlockedUsersList!(blockedUsers);
      }
    });

    _socket.on('blockedStatus', (data) {
      if (onBlockedStatus != null) {
        onBlockedStatus!(
          data['isUserBlocked'],
          data['isOtherUserBlocked'],
        );
      }
    });

    _socket.on('blockedByUser', (data) {
      if (onBlockedByUser != null) {
        onBlockedByUser!(data['blockedByUserId']);
      }
    });

    _socket.on('messageBlocked', (data) {
      if (onMessageBlocked != null) {
        onMessageBlocked!(data['receiverId'], data['reason']);
      }
    });
  }

  void _initSocket() {
    _socket = IO.io(AppConstants.serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.onConnect((_) {
      print('🟢 Connected to server with ID: ${_socket.id}');
      if (_currentUserId != null) {
        _socket.emit('register', _currentUserId);
        print('🔄 Registered user ID: $_currentUserId');
      }
      if (onConnect != null) {
        onConnect!();
      }
    });

    _socket.onConnectError((error) {
      print('⚠️ Connect error: $error');
      if (onConnectError != null) {
        onConnectError!(error);
      }
    });
    _socket.onDisconnect((_) => print('🔴 Disconnected from server'));
    _socket.onError((err) {
      print('❌ Socket error: $err');
      if (onError != null) {
        onError!({"message": err.toString()});
      }
    });

    // Add this to monitor all events
    _socket.onAny((event, data) {
      print('📌 EVENT: $event - DATA: $data');
    });

    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socket.on('statusShareMessage', (data) {
      print("RECEIVED: Status share message: $data");

      try {
        final message = Message.fromJson(data);

        print("PARSED: Status ID: ${message.statusId}");
        print("PARSED: Status Type: ${message.statusType}");
        print("PARSED: Status Content: ${message.statusContent}");
        print("PARSED: Status URL: ${message.statusFileUrl}");

        // Notify listeners
        if (onStatusShareMessage != null) {
          onStatusShareMessage!(message);
        }

        // Also notify through regular message channel
        if (onNewMessage != null) {
          onNewMessage!(message);
        }
      } catch (e) {
        print("Error parsing status share message: $e");
      }
    });
    _socket.on('messageDeleted', (data) {
      print(
          '✅ Message deleted: ${data['messageId']}, for everyone: ${data['forEveryone']}');
      if (onMessageDeleted != null) {
        onMessageDeleted!(
          data['messageId'],
          data['forEveryone'] ?? false,
        );
      }
    });

    _socket.on('messageDeletedByOther', (data) {
      print(
          '🗑️ Message ${data['messageId']} was deleted by ${data['senderId']}');
      if (onMessageDeletedByOther != null) {
        onMessageDeletedByOther!(
          data['messageId'],
          data['senderId'],
        );
      }
    });

    _socket.on('unreadCountUpdate', (data) {
      print('📬 Received unread count update: $data');
      if (onUnreadCountUpdate != null) {
        onUnreadCountUpdate!(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('unreadCounts', (data) {
      print('📊 Received all unread counts: ${data['counts']}');
      if (onUnreadCounts != null && data['counts'] != null) {
        onUnreadCounts!(Map<String, int>.from(data['counts']));
      }
    });

    // Implement message listener with deduplication
    // In SocketService.dart, modify the 'newMessage' listener
// Add this patch inside the _setupSocketListeners method

    _socket.on('newMessage', (data) {
      print(
          "Received message: ${data['messageType']} from ${data['senderId']}");

      // Special handling for status_share messages
      if (data['messageType'] == 'status_share') {
        print("⭐ STATUS SHARE MESSAGE RECEIVED ⭐");

        // Check if status fields are present
        bool hasStatusFields =
            data['statusId'] != null && data['statusFileUrl'] != null;

        if (!hasStatusFields) {
          print(
              "⚠️ Status fields missing! Attempting to restore from metadata...");

          // This is where we would ideally fetch the missing information
          // For now, let's check if we have metadata stored locally

          // If no restoration is possible, add log warning
          print(
              "⚠️ Unable to restore status fields, message will be incomplete");
        } else {
          print("Status ID: ${data['statusId']}");
          print("Status Type: ${data['statusType']}");
          print("Status Content: ${data['statusContent']}");
          print("Status File URL: ${data['statusFileUrl']}");
        }
      }

      // Create message from data
      final message = Message.fromJson(data);

      // For status_share messages with missing fields, let's try to handle them
      if (message.messageType == 'status_share' &&
          (message.statusId == null || message.statusId!.isEmpty)) {
        print("⚠️ Received status_share message with missing fields");
      }

      if (!_processedMessageIds.contains(message.messageId)) {
        _processedMessageIds.add(message.messageId);

        if (onNewMessage != null) {
          onNewMessage!(message);
        }
      } else {
        print("🔄 Skipping duplicate message: ${message.messageId}");
      }
    });

    // Fixed chatHistory handler
    _socket.on('chatHistory', (data) {
      print(
          "📦 CHAT HISTORY RECEIVED: userId=${data['userId']}, otherUserId=${data['otherUserId']}");

      if (data['messages'] == null) {
        print("⚠️ No messages found in chat history data");
        if (onChatHistory != null) {
          onChatHistory!([]); // Send empty list
        }
        return;
      }

      final List<dynamic> messagesJson = data['messages'];
      print("📊 Received ${messagesJson.length} messages in chat history");

      try {
        // Create a separate set for this chat history to avoid conflicts
        final Set<String> chatHistoryMessageIds = {};

        // Convert to Message objects
        final List<Message> messages = [];
        for (var msg in messagesJson) {
          try {
            final message = Message.fromJson(msg);

            // Only add if not already in this batch (avoid duplicates within same history)
            if (!chatHistoryMessageIds.contains(message.messageId)) {
              chatHistoryMessageIds.add(message.messageId);
              messages.add(message);
              print(
                  "✓ Added message: ${message.messageId} - ${message.message.substring(0, message.message.length > 20 ? 20 : message.message.length)}...");
            } else {
              print(
                  "⚠️ Skipping duplicate message in history: ${message.messageId}");
            }
          } catch (e) {
            print("⚠️ Error parsing message: $e");
          }
        }

        // Sort by timestamp (ascending for chat display)
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        if (onChatHistory != null) {
          print("🔄 Calling onChatHistory with ${messages.length} messages");
          onChatHistory!(messages);
        } else {
          print("⚠️ onChatHistory callback is null - no listener set up!");
        }
      } catch (e) {
        print("❌ Error processing chat history: $e");
        // Still send an empty list if error occurs
        if (onChatHistory != null) {
          onChatHistory!([]);
        }
      }
    });

    // Add this to your _setupSocketListeners() method in SocketService class
    _socket.on('chatContacts', (data) {
      print(
          '📋 Received chat contacts: ${data['contacts']?.length ?? 0} contacts');

      if (onChattedUsers != null && data['contacts'] != null) {
        final List<dynamic> contactsJson = data['contacts'];

        // Extract just the user IDs from the contacts
        final List<String> userIds = contactsJson
            .map((contact) => contact['userId'].toString())
            .toList();

        onChattedUsers!(userIds);
      }
    });

    _socket.on('broadcastSent', (data) {
      print('✅ Broadcast sent confirmation: $data');
      if (onBroadcastSent != null) {
        onBroadcastSent!(Map<String, dynamic>.from(data));
      }
    });

    // For broadcast history
    _socket.on('broadcastHistory', (data) {
      print('📜 Received broadcast history');
      if (onBroadcastHistory != null && data['messages'] != null) {
        final List<dynamic> messagesJson = data['messages'];
        _processedMessageIds.clear();
        final List<Message> messages = [];
        for (var msg in messagesJson) {
          final message = Message.fromJson(msg);
          _processedMessageIds.add(message.messageId);
          messages.add(message);
        }
        // Sort by timestamp
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        onBroadcastHistory!(messages);
      }
    });

    // Make sure your 'error' listener handles admin message errors
    _socket.on('error', (data) {
      print('Socket error: $data');
      if (data['errorType'] == 'ADMIN_MESSAGE_BLOCKED') {
        // Handle admin message blocking (show special UI message)
        print('Cannot send messages to admin broadcast accounts');
      }
    });

    _socket.on('messageDelivered', (data) {
      if (onMessageDelivered != null && data['messageId'] != null) {
        onMessageDelivered!(data['messageId']);
      }
    });

    _socket.on('messageRead', (data) {
      if (onMessageRead != null && data['messageId'] != null) {
        onMessageRead!(data['messageId']);
      }
    });

    _socket.on('userTyping', (data) {
      if (onUserTyping != null && data['userId'] != null) {
        onUserTyping!(data['userId']);
      }
    });

    _socket.on('userStoppedTyping', (data) {
      if (onUserStoppedTyping != null && data['userId'] != null) {
        onUserStoppedTyping!(data['userId']);
      }
    });

    _socket.on('userStatus', (data) {
      print('👤 Received user status update: $data');

      if (data is Map<String, dynamic>) {
        try {
          // Convert the status data to a properly typed map
          Map<String, dynamic> statusMap = {};

          // Process each user status entry
          data.forEach((userId, statusInfo) {
            if (statusInfo is Map) {
              // Extract and normalize the online status
              bool isOnline = false;
              if (statusInfo.containsKey('online')) {
                isOnline = statusInfo['online'] == true;
              }

              // Store in our map with standard format
              statusMap[userId] = {
                'online': isOnline,
                'lastSeen': statusInfo['lastSeen'] ??
                    DateTime.now().millisecondsSinceEpoch,
              };

              print(
                  '📊 User $userId is ${isOnline ? 'online' : 'offline'}, last seen: ${statusMap[userId]['lastSeen']}');
            }
          });

          if (onUserStatus != null) {
            onUserStatus!(statusMap);
          }
        } catch (e) {
          print('❌ Error processing user status: $e');
        }
      } else {
        print('⚠️ Received malformed user status data: $data');
      }
    });

    // Call listeners - listen to the correct event names
    _socket.on('incoming_call', (data) {
      print("INCOMING CALL RECEIVED: ${data.toString()}");
      final callId =
          data['callId'] ?? "call_${DateTime.now().millisecondsSinceEpoch}";

      // We don't know if missed yet, will update later
      CallHistoryService().addCall(CallHistoryEntry(
        callId: callId,
        callerId: data['caller'],
        receiverId: data['target'],
        isOutgoing: false,
        isVideoCall: data['isVideoCall'] ?? false,
        isMissed: false, // Will update this when call is accepted/rejected
        timestamp: data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        roomId: data['roomId'],
      ));
      if (onIncomingCall != null) {
        onIncomingCall!(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('call_requested', (data) {
      final callId = "call_${DateTime.now().millisecondsSinceEpoch}";

      CallHistoryService().addCall(CallHistoryEntry(
        callId: callId,
        callerId: data['caller'],
        receiverId: data['target'],
        isOutgoing: true,
        isVideoCall: data['isVideoCall'] ?? false,
        isMissed: false, // We don't know yet
        timestamp: DateTime.now().millisecondsSinceEpoch,
        roomId: data['roomId'],
      ));
      if (onCallRequested != null) {
        onCallRequested!(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('call_accepted', (data) {
      final callEntries = CallHistoryService().allCalls;
      final callEntry = callEntries.lastWhere(
        (call) =>
            call.callerId == data['caller'] &&
            call.receiverId == data['target'],
        orElse: () => CallHistoryEntry(
          callId:
              data['callId'] ?? "call_${DateTime.now().millisecondsSinceEpoch}",
          callerId: data['caller'],
          receiverId: data['target'],
          isOutgoing: false,
          isVideoCall: data['isVideoCall'] ?? false,
          isMissed: true, // Default to missed until we know otherwise
          timestamp: data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          roomId: data['roomId'],
        ),
      );

      // Update the entry (you'll need to implement this)
      // For now we'll assume the list always has the most recent call first
      callEntries[0] = CallHistoryEntry(
        callId: callEntry.callId,
        callerId: callEntry.callerId,
        receiverId: callEntry.receiverId,
        isOutgoing: callEntry.isOutgoing,
        isVideoCall: callEntry.isVideoCall,
        isMissed: false, // Call was accepted
        timestamp: callEntry.timestamp,
        roomId: callEntry.roomId,
      );
      if (onCallAccepted != null) {
        onCallAccepted!(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('call_rejected', (data) {
      final callEntries = CallHistoryService().allCalls;
      if (callEntries.isNotEmpty) {
        // Assume the first entry is the most recent call
        final callEntry = callEntries[0];
        callEntries[0] = CallHistoryEntry(
          callId: callEntry.callId,
          callerId: callEntry.callerId,
          receiverId: callEntry.receiverId,
          isOutgoing: callEntry.isOutgoing,
          isVideoCall: callEntry.isVideoCall,
          isMissed: true, // Call was missed/rejected
          timestamp: callEntry.timestamp,
          roomId: callEntry.roomId,
        );
      }
      if (onCallRejected != null) {
        onCallRejected!(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('call_ended', (data) {
      if (onCallEnded != null) {
        onCallEnded!(Map<String, dynamic>.from(data));
      }
    });
    // Add this listener
    _socket.on('user_online_status', (data) {
      print("TARGET USER ONLINE STATUS: ${data['isOnline']}");
    });

    _socket.on('debug_call_flow_echo', (data) {
      print("CALL FLOW DEBUG ECHO: ${data['step']} - ${data['details']}");
    });

    // Status listeners
    _socket.on('statusPosted', (data) {
      print('✅ Status posted event received: ${data.toString()}');
      if (data['debug_id'] != null) {
        print('   Debug ID: ${data['debug_id']}');
      }

      if (onStatusPosted != null) {
        onStatusPosted!(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('activeStatuses', (data) {
      print("Received active statuses: $data");
      if (onActiveStatuses != null) {
        final List<dynamic> usersJson = data['users'];
        print("Users with status: ${usersJson.length}");
        final users =
            usersJson.map((user) => StatusUser.fromJson(user)).toList();
        onActiveStatuses!(users);
      }
    });

    _socket.on('userStatuses', (data) {
      if (onUserStatuses != null) {
        final String userId = data['userId'];
        final List<dynamic> statusesJson = data['statuses'];
        final statuses =
            statusesJson.map((status) => Status.fromJson(status)).toList();
        onUserStatuses!(userId, statuses);
      }
    });
  }

  void blockUser(String userId, String blockedUserId) {
    _socket.emit('blockUser', {
      'userId': userId,
      'blockedUserId': blockedUserId,
    });
  }

  void unblockUser(String userId, String unblockedUserId) {
    _socket.emit('unblockUser', {
      'userId': userId,
      'unblockedUserId': unblockedUserId,
    });
  }

  void getBlockedUsers(String userId, Function(List<String>) callback) {
    // Clear any existing handler first to avoid duplicates
    onBlockedUsersList = null;

    // Set up the callback handler
    onBlockedUsersList = (List<String> blockedUsers) {
      // Call the provided callback with the results
      callback(blockedUsers);
    };

    // Request the blocked users list
    _socket.emit('getBlockedUsers', {
      'userId': userId,
    });
  }

  void checkBlockedStatus(String userId, String otherUserId) {
    _socket.emit('checkBlocked', {
      'userId': userId,
      'otherUserId': otherUserId,
    });
  }

  void getChattedUsers(String userId) {
    print('🔍 Requesting chatted users for: $userId');

    // Check connection status
    if (!_socket.connected) {
      print("⚠️ Socket not connected. Attempting to reconnect...");
      connect(_currentUserId ?? userId);

      // Retry after a delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_socket.connected) {
          print("✅ Reconnected, now requesting chatted users");
          _socket.emit('getChatContacts', {'userId': userId});
        } else {
          print("❌ Failed to reconnect for chatted users request");
        }
      });
      return;
    }

    _socket.emit('getChatContacts', {'userId': userId});
  }

  void postStatus({
    required String userId,
    required String statusType,
    required String content,
    String? fileUrl,
    String? fileName,
    int? duration,
  }) {
    // Ensure duration has a default value of 24 hours (in milliseconds)
    final actualDuration = duration ?? 86400000; // 24 hours in milliseconds

    print('Posting status with duration: $actualDuration ms');

    _socket.emit('postStatus', {
      'userId': userId,
      'statusType': statusType,
      'content': content,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'duration': actualDuration,
    });
  }

  void getActiveStatuses() {
    _socket.emit('getActiveStatuses');
  }

  void getUserStatuses(String userId) {
    _socket.emit('getUserStatuses', {
      'userId': userId,
    });
  }

  void replyToStatus({
    required String statusId,
    required String message,
    required String senderId,
    required String receiverId,
    String? statusContent,
  }) {
    print(
        'Replying to status $statusId: From $senderId to $receiverId - "$message"   with content: $statusContent');

    _socket.emit('replyToStatus', {
      'statusId': statusId,
      'message': message,
      'senderId': senderId,
      'receiverId': receiverId,
      'statusFileUrl': statusContent,
    });
  }

  // Existing methods
  void connect(String userId) {
    _currentUserId = userId;

    if (!_socket.connected) {
      _socket.connect();
    } else {
      _socket.emit('register', userId);
    }
  }

  void disconnect() {
    _socket.disconnect();
  }

  // Update this method to properly handle message sending and avoid echoes
  void sendMessage(Message message) {
    // Add to processed IDs to prevent echoing the same message back
    _processedMessageIds.add(message.messageId);

    print(
        "📤 Sending message: ${message.messageId} from ${message.senderId} to ${message.receiverId}");
    _socket.emit('sendMessage', message.toJson());
  }

  void getChatHistory(String userId, String otherUserId,
      {int limit = 100, int offset = 0}) {
    if (userId.isEmpty || otherUserId.isEmpty) {
      print(
          "⚠️ Invalid user IDs for chat history: userId=$userId, otherUserId=$otherUserId");
      return;
    }

    print(
        '🔍 Requesting chat history between $userId and $otherUserId (limit: $limit, offset: $offset)');

    // Check connection status
    if (!_socket.connected) {
      print("⚠️ Socket not connected. Attempting to reconnect...");
      connect(_currentUserId ?? userId);

      // Retry after a delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_socket.connected) {
          print("✅ Reconnected, now requesting chat history");
          _emitChatHistoryRequest(userId, otherUserId, limit, offset);
        } else {
          print("❌ Failed to reconnect for chat history request");
        }
      });
      return;
    }

    _emitChatHistoryRequest(userId, otherUserId, limit, offset);
  }

  // Helper method to emit the chat history request with consistent parameters
  void _emitChatHistoryRequest(
      String userId, String otherUserId, int limit, int offset) {
    _socket.emit('getChatHistory', {
      'userId': userId,
      'otherUserId': otherUserId,
      'limit': limit,
      'offset': offset,
    });

    // For debugging, send a ping test
    _socket.emit('ping_test', {
      'action': 'Request chat history',
      'userId': userId,
      'otherUserId': otherUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    });
  }

  void markAsDelivered(String messageId, String senderId, String receiverId) {
    _socket.emit('messageDelivered', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  void markAsRead(String messageId, String senderId, String receiverId) {
    _socket.emit('messageRead', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  void sendTypingStatus(String senderId, String receiverId, bool isTyping) {
    final event = isTyping ? 'typing' : 'stopTyping';
    _socket.emit(event, {
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  void getUserStatus({List<String>? userIds}) {
    if (userIds != null && userIds.isNotEmpty) {
      print('🔍 Requesting status for specific users: $userIds');
      _socket.emit('getUserStatus', {'userIds': userIds});
    } else {
      print('🔍 Requesting all user statuses');
      _socket.emit('getUserStatus');
    }
  }

  void keepAlive() {
    if (_currentUserId != null && _socket.connected) {
      print('💓 Sending keep-alive for user: $_currentUserId');
      _socket.emit('user_online', {'userId': _currentUserId});
    }
  }

  bool get isConnected => _socket.connected;

  // Call methods
  void userOnline() {
    if (_currentUserId != null && isConnected) {
      _socket.emit('user_online', _currentUserId);
    }
  }

  void requestCall(
      String callerId, String targetId, String roomId, bool isVideoCall) {
    print("📱 OUTGOING CALL: from $callerId to $targetId in room $roomId");

    if (!_socket.connected) {
      print("⚠️ Socket not connected when trying to place call!");
      connect(_currentUserId ?? callerId);

      // Try again after reconnection
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_socket.connected) {
          _emitCallRequest(callerId, targetId, roomId, isVideoCall);
        } else {
          print("❌ Failed to reconnect socket for call request");
        }
      });
      return;
    }

    _emitCallRequest(callerId, targetId, roomId, isVideoCall);
  }

  // Request a call to another user - use the correct event name
  void _emitCallRequest(
      String callerId, String targetId, String roomId, bool isVideoCall) {
    _socket.emit('request_call', {
      'caller': callerId,
      'target': targetId,
      'roomId': roomId,
      'isVideoCall': isVideoCall,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void deleteMessageForMe(String userId, String messageId) {
    print('🗑️ Deleting message $messageId for user $userId');
    _socket.emit('deleteMessageForMe', {
      'userId': userId,
      'messageId': messageId,
    });
  }

  void deleteMessageForEveryone(String senderId, String messageId) {
    print('🗑️🌐 Deleting message $messageId for everyone by $senderId');
    _socket.emit('deleteMessageForEveryone', {
      'senderId': senderId,
      'messageId': messageId,
    });
  }

  void getUnreadCounts(String userId) {
    print('🔍 Requesting unread counts for: $userId');
    _socket.emit('getUnreadCounts', {
      'userId': userId,
    });
  }

  void markMessagesAsRead(String userId, String otherUserId) {
    print('✓ Marking messages from $otherUserId as read by $userId');
    _socket.emit('markMessagesAsRead', {
      'userId': userId,
      'otherUserId': otherUserId,
    });
  }

  void clearUnreadMessages(String userId, String senderId) {
    print('🧹 Clearing unread messages from $senderId for $userId');
    _socket.emit('clearUnreadMessages', {
      'userId': userId,
      'senderId': senderId,
    });
  }

  // Add this method to check server connectivity
  void checkServerConnection() {
    try {
      _socket.emit('ping_test', {
        'userId': _currentUserId,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
      print('🏓 Ping test sent to server');
    } catch (e) {
      print('❌ Error sending ping test: $e');
    }
  }

  // In your SocketService.dart file
  // Fix acceptance/rejection event names
  void acceptCall(String callerId, String targetId, String roomId) {
    _socket.emit('accept_call', {
      // Changed from 'call-accepted' to 'accept_call'
      'caller': callerId,
      'target': targetId,
      'roomId': roomId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void rejectCall(String callerId, String targetId) {
    _socket.emit('reject_call', {
      // Changed from 'call-rejected' to 'reject_call'
      'caller': callerId,
      'target': targetId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void endCall(String callerId, String targetId, String roomId) {
    _socket.emit('end_call', {
      // Changed from 'call-ended' to 'end_call'
      'caller': callerId,
      'target': targetId,
      'roomId': roomId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Add to your SocketService class
  void checkUserOnline(String targetId) {
    _socket.emit('check_user_online', {'targetId': targetId});
  }

  void debugCallFlow(String step, Map<String, dynamic> details) {
    _socket.emit('debug_call_flow', {'step': step, 'details': details});
  }

  void getBroadcastUnreadCounts(String userId) {
    print('🔍 Requesting broadcast unread counts for: $userId');
    _socket.emit('getBroadcastUnreadCounts', {
      'userId': userId,
    });
  }

  void markBroadcastAsRead(String userId, String adminId) {
    print('✓ Marking broadcasts from $adminId as read by $userId');
    _socket.emit('markBroadcastAsRead', {
      'userId': userId,
      'adminId': adminId,
    });
  }

  // Handle call quality updates
  void updateCallStats(String roomId, Map<String, dynamic> stats) {
    _socket.emit('call_stats', {
      'roomId': roomId,
      'userId': _currentUserId,
      'stats': stats,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void broadcastMessage(Message message) {
    // Check if current user is an admin
    if (!isAdmin(message.senderId)) {
      print('❌ Error: Only admin users can broadcast messages');
      if (onError != null) {
        onError!({"message": "Only admin users can broadcast messages"});
      }
      return;
    }

    if (!_socket.connected) {
      print(
          '⚠️ Socket not connected when trying to broadcast! Attempting to reconnect...');
      connect(message.senderId);

      // Try again after reconnection
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_socket.connected) {
          print('🔄 Socket reconnected, sending broadcast after delay');
          _emitBroadcast(message);
        } else {
          print('❌ Failed to reconnect socket for broadcast');
        }
      });
      return;
    }

    _emitBroadcast(message);
  }

// Helper method to emit broadcast with proper logging
  void _emitBroadcast(Message message) {
    try {
      // Create a properly formatted broadcast message
      final broadcastMessage = {
        ...message.toJson(),
        'isBroadcast': true, // Ensure this flag is set
        'messageId': message.messageId ??
            "broadcast_${DateTime.now().millisecondsSinceEpoch}",
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      print('📣 Emitting broadcastMessage event:');
      print('   - Sender: ${message.senderId}');
      print('   - Message: ${message.message}');
      print('   - Message Type: ${message.messageType}');
      print('   - Connected: ${_socket.connected}');
      print('   - Socket ID: ${_socket.id}');

      // Send the broadcast
      _socket.emit('broadcastMessage', broadcastMessage);
    } catch (e) {
      print('❌ Exception when broadcasting: $e');
    }
  }

  void getBroadcastHistoryForAdmin(String adminId) {
    if (!_socket.connected) {
      print(
          '⚠️ Socket not connected, attempting to reconnect for broadcast history...');
      connect(_currentUserId!);

      // Try again after reconnection
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_socket.connected) {
          print(
              '✅ Socket reconnected, now fetching broadcast history for admin: $adminId');
          _socket.emit('getBroadcastHistory', {'adminId': adminId});
        } else {
          print('❌ Failed to reconnect socket for getting broadcast history');
        }
      });
      return;
    }

    print('🔍 Requesting broadcast history for admin: $adminId');
    _socket.emit('getBroadcastHistory', {'adminId': adminId});
  }

  void getAdminUsers() {
    if (!_socket.connected) {
      print(
          '⚠️ Socket not connected, attempting to reconnect for admin users list...');
      connect(_currentUserId!);

      // Try again after reconnection
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_socket.connected) {
          print('✅ Socket reconnected, now fetching admin users');
          _socket.emit('getAdminUsers');
        } else {
          print('❌ Failed to reconnect socket for getting admin users');
        }
      });
      return;
    }

    print('🔍 Requesting admin users list');
    _socket.emit('getAdminUsers');
  }

  void likeStatus(String userId, String statusId) {
    print('👍 Sending like for status: $statusId by user: $userId');
    _socket.emit('likeStatus', {
      'userId': userId,
      'statusId': statusId,
    });
  }

  void getStatusLikes(String statusId) {
    print('🔍 Requesting likes for status: $statusId');
    _socket.emit('getStatusLikes', {
      'statusId': statusId,
    });
  }

  void checkStatusLike(String userId, String statusId) {
    print('🔍 Checking if user $userId liked status: $statusId');
    _socket.emit('checkStatusLike', {
      'userId': userId,
      'statusId': statusId,
    });
  }

  void _setupStatusShareHandler() {
    _socket.on('statusShareMessage', (data) {
      print('Received status share message: $data');

      // Parse the message
      final message = Message.fromJson(data);

      // Notify listeners
      if (onStatusShareMessage != null) {
        onStatusShareMessage!(message);
      }

      // Also notify through regular message channel
      if (onNewMessage != null) {
        onNewMessage!(message);
      }
    });
  }

  void getStatusById(String statusId) {
    socket.emit('getStatusById', {'statusId': statusId});
  }

  void sendStatusShareMessage(Message message) {
    // Add to processed IDs to prevent echoing
    _processedMessageIds.add(message.messageId);

    print("SOCKET SERVICE: Sending status share message");
    print("SOCKET SERVICE: Status ID: ${message.statusId}");
    print("SOCKET SERVICE: Status Type: ${message.statusType}");
    print("SOCKET SERVICE: Status Content: ${message.statusContent}");
    print("SOCKET SERVICE: Status URL: ${message.statusFileUrl}");

    // Convert to JSON and check fields again
    final json = message.toJson();
    print("SOCKET SERVICE: JSON: $json");

    // Make sure we're sending the correct fields
    if (message.statusId == null || message.statusId!.isEmpty) {
      print("WARNING: statusId is empty or null!");
    }
    if (message.statusType == null || message.statusType!.isEmpty) {
      print("WARNING: statusType is empty or null!");
    }
    if (message.statusFileUrl == null || message.statusFileUrl!.isEmpty) {
      print("WARNING: statusFileUrl is empty or null!");
    }

    // Send as specific status share event
    _socket.emit('statusShareMessage', json);

    // Also send as regular message for compatibility
    _socket.emit('sendMessage', json);
  }
}
