import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/socket_service.dart';
import '../constants/app_constants.dart';
import 'dart:math';

class AdminChatScreen extends StatefulWidget {
  final String adminId;
  final String
      currentUserId; // Add currentUserId to track who's using the screen

  const AdminChatScreen({
    super.key,
    required this.adminId,
    required this.currentUserId,
  });

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final SocketService _socketService = SocketService();
  final List<Message> _messages = [];
  bool _isSending = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";
  bool _isCurrentUserAdmin = false; // Track if current user is admin
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Check if current user is admin
    _isCurrentUserAdmin =
        AppConstants.adminUsers.contains(widget.currentUserId);

    // Make sure socket is connected with retry
    _connectAndSetupWithRetry();
  }

  void _connectAndSetupWithRetry() {
    // Connect to socket with the current user's ID (not the admin's ID)
    _socketService.connect(widget.currentUserId);

    // Setup listeners
    _setupSocketListeners();

    // Get broadcast history
    _getBroadcastHistory();

    // Set a timeout to handle cases where data doesn't load
    _setLoadingTimeout();
  }

  void _setLoadingTimeout() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        // If we're still loading after 10 seconds, show empty state
        setState(() {
          _isLoading = false;
          print("Loading timeout - showing empty state");
        });
      }
    });
  }

  void _setupSocketListeners() {
    // Listen for socket connection status
    _socketService.onConnect = () {
      print(
          "Socket connected for user ${widget.currentUserId} viewing admin ${widget.adminId}");
      // Retry getting broadcast history if connection was reestablished
      if (_isLoading) {
        _getBroadcastHistory();
      }
    };

    // Listen for connection errors
    _socketService.onConnectError = (error) {
      print("Socket connection error: $error");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "Connection error: $error";
          _isLoading = false;
        });
      }
    };

    // Listen for broadcast sent confirmation
    _socketService.onBroadcastSent = (data) {
      if (mounted) {
        setState(() {
          _isSending = false;

          // Create a message object from the broadcast data
          if (data['messageId'] != null) {
            final Message message = Message(
              messageId: data['messageId'],
              senderId: widget.currentUserId, // Using current user ID as sender
              receiverId: 'broadcast', // Special receiver ID for broadcasts
              message: data['message'] ?? '',
              timestamp:
                  data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
              messageType: data['messageType'] ?? AppConstants.messageTypeText,
              fileName: data['fileName'],
              fileUrl: data['fileUrl'],
              isBroadcast: true,
              isAdminMessage: true,
            );

            // Add to messages list if not already there
            if (!_messages.any((m) => m.messageId == message.messageId)) {
              _messages.add(message);
              _sortMessages();
            }
          }
        });
      }
    };

    // Listen for all broadcasts (to show the admin their history)
    _socketService.onNewMessage = (message) {
      if (message.isBroadcast) {
        if (mounted) {
          setState(() {
            if (!_messages.any((m) => m.messageId == message.messageId)) {
              _messages.add(message);
              _sortMessages();
            }
          });
        }
      }
    };

    // Listen for broadcast history
    _socketService.onBroadcastHistory = (messages) {
      print("Received broadcast history: ${messages.length} messages");

      if (mounted) {
        setState(() {
          _isLoading = false;

          // Add all messages from the admin we're viewing
          for (final message in messages) {
            if (message.senderId == widget.adminId &&
                !_messages.any((m) => m.messageId == message.messageId)) {
              _messages.add(message);
            }
          }

          _sortMessages();
        });
      }
    };

    // Error listener
    _socketService.onError = (errorData) {
      print("Socket error: ${errorData['message']}");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = errorData['message'] ?? 'An error occurred';
          _isLoading = false;
        });
      }
    };
  }

  void _getBroadcastHistory() {
    print("Getting broadcast history for admin: ${widget.adminId}");

    // Add debugging - ping the server first to verify connection
    _socketService.checkServerConnection();

    // Request broadcast history for this admin with a small delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _socketService.getBroadcastHistoryForAdmin(widget.adminId);
    });
  }

  void _sortMessages() {
    // Sort messages with oldest first (ascending order by timestamp)
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _sendBroadcast() {
    // Only allow the specific admin to send broadcasts from their own screen
    if (widget.currentUserId != widget.adminId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('You can only send messages from your own admin account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isSending = true;
    });

    final message = Message(
      messageId:
          'broadcast_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      senderId: widget.currentUserId, // Using current user ID as sender
      receiverId: 'broadcast', // Special ID for broadcasts
      message: messageText,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      messageType: AppConstants.messageTypeText,
      isBroadcast: true,
      isAdminMessage: true,
    );

    // Important: Add message to local list FIRST for immediate display
    setState(() {
      _messages.add(message);
      _sortMessages();
    });

    // Then send broadcast to server
    _socketService.broadcastMessage(message);

    // Auto-scroll to the bottom to show the new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _retryConnection() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = "";
    });

    // Reconnect and retry
    _connectAndSetupWithRetry();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if this is the admin's own broadcast page
    final bool isOwnAdminPage =
        widget.currentUserId == widget.adminId && _isCurrentUserAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnAdminPage
            ? 'Admin Broadcast Center'
            : 'Announcements from ${widget.adminId}'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _retryConnection,
            tooltip: 'Reload broadcasts',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade100,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOwnAdminPage
                        ? 'Messages sent from here will be broadcast to all users. Users cannot reply to broadcast messages.'
                        : 'These are announcements from administrators. You cannot reply to these messages.',
                    style: TextStyle(color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),

          // Message list
          Expanded(
            child: _buildMessageArea(),
          ),

          // Input bar - only show if current user is the admin viewing their own page
          if (isOwnAdminPage)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a broadcast message...',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSending
                      ? const CircularProgressIndicator()
                      : FloatingActionButton(
                          onPressed: _sendBroadcast,
                          backgroundColor: Colors.blue[700],
                          child: const Icon(Icons.campaign),
                        ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageArea() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading broadcast history...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading broadcasts',
              style: TextStyle(
                  color: Colors.red.shade700, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryConnection,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No broadcasts yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.currentUserId == widget.adminId && _isCurrentUserAdmin
                  ? 'Send your first announcement'
                  : 'Check back later for announcements',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildBroadcastItem(message);
      },
    );
  }

  Widget _buildBroadcastItem(Message message) {
    // Determine who sent the message
    final isSentByCurrentUser = message.senderId == widget.currentUserId;
    final displayName = isSentByCurrentUser
        ? 'You (Admin)'
        : 'Admin ${message.senderId.substring(0, 4)}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Broadcast header
            Row(
              children: [
                Icon(Icons.campaign, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'From: $displayName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const Divider(),

            // Message content
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                message.message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Don't disconnect the socket here
    super.dispose();
  }
}
