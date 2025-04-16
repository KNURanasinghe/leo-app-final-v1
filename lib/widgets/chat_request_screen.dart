// chat_request_screen.dart
import 'package:flutter/material.dart';
import 'package:leo_app_01/models/request_model.dart';
import '../services/socket_service.dart';

class ChatRequestScreen extends StatefulWidget {
  final String currentUserId;

  const ChatRequestScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  _ChatRequestScreenState createState() => _ChatRequestScreenState();
}

class _ChatRequestScreenState extends State<ChatRequestScreen> {
  final SocketService _socketService = SocketService();
  final List<ChatRequest> _pendingRequests = [];
  bool _isLoading = true;
  bool _hasInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();

    // Add a short delay to ensure socket connection is established
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadPendingRequests();
    });

    // Add a failsafe in case we don't receive a response
    Future.delayed(const Duration(seconds: 5), () {
      if (_isLoading && mounted) {
        setState(() {
          _isLoading = false;
          if (_pendingRequests.isEmpty) {
            // Add more context if we didn't get any response
            print("⚠️ No response received for chat requests after timeout");
          }
        });
      }
    });
  }

  void _setupSocketListeners() {
    // Clear any existing listeners to avoid duplicates
    _socketService.onChatRequestsList = null;
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;

    // Setup direct socket event listener for chatRequestsList
    _socketService.socket.on('chatRequestsList', (data) {
      print('📋 DIRECT EVENT - Received chat requests list: $data');

      try {
        if (data != null && mounted) {
          List<ChatRequest> requests = [];

          // Handle case where the server sends {requests: [...]}
          if (data is Map && data['requests'] != null) {
            final List<dynamic> requestsJson = data['requests'];

            for (var req in requestsJson) {
              try {
                final request = ChatRequest.fromJson(req);
                if (request.status == 'pending' &&
                    request.receiverId == widget.currentUserId) {
                  requests.add(request);
                  print(
                      '✓ Parsed request: ${request.requestId} - ${request.senderName}');
                }
              } catch (e) {
                print('⚠️ Error parsing chat request: $e');
              }
            }
          }
          // Handle case where the server sends direct array
          else if (data is List) {
            for (var req in data) {
              try {
                final request = ChatRequest.fromJson(req);
                if (request.status == 'pending' &&
                    request.receiverId == widget.currentUserId) {
                  requests.add(request);
                }
              } catch (e) {
                print('⚠️ Error parsing chat request from array: $e');
              }
            }
          }

          setState(() {
            _pendingRequests.clear();
            _pendingRequests.addAll(requests);
            _isLoading = false;
            _hasInitialized = true;
            _hasError = false;
          });

          print(
              '💡 Updated UI with ${_pendingRequests.length} pending requests');
        }
      } catch (e) {
        print('❌ Error processing direct chat requests list: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Error loading requests: $e';
          });
        }
      }
    });

    // Also use the regular callback mechanism as fallback
    _socketService.onChatRequestsList = (requests) {
      print('📋 Received ${requests.length} chat requests via callback');

      if (mounted) {
        setState(() {
          _pendingRequests.clear();
          // Only add pending requests for this user
          _pendingRequests.addAll(requests.where((req) =>
              req.status == 'pending' &&
              req.receiverId == widget.currentUserId));
          _isLoading = false;
          _hasInitialized = true;
          _hasError = false;
        });
        print(
            '💡 Updated UI with ${_pendingRequests.length} pending requests via callback');
      }
    };

    _socketService.onChatRequestUpdated = (request) {
      print(
          '🔄 Chat request updated: ${request.requestId}, status: ${request.status}');
      if (mounted) {
        setState(() {
          // Remove the request if it's no longer pending
          if (request.status != 'pending') {
            _pendingRequests
                .removeWhere((req) => req.requestId == request.requestId);
          } else {
            // Update existing request if it's still pending
            final index = _pendingRequests
                .indexWhere((req) => req.requestId == request.requestId);
            if (index != -1) {
              _pendingRequests[index] = request;
            } else if (request.receiverId == widget.currentUserId) {
              // Add if not found but is pending (new request)
              _pendingRequests.add(request);
            }
          }
        });
      }
    };

    _socketService.onChatRequestReceived = (request) {
      print(
          '📩 New chat request received: ${request.requestId}, for: ${request.receiverId}');
      // Add new request if it's for the current user and is pending
      if (request.receiverId == widget.currentUserId &&
          request.status == 'pending' &&
          mounted) {
        setState(() {
          // Check if request already exists to avoid duplicates
          final exists =
              _pendingRequests.any((req) => req.requestId == request.requestId);
          if (!exists) {
            _pendingRequests.add(request);
            print('💡 Added new request to UI: ${request.requestId}');
          }
        });
      }
    };

    // Listen for error events
    _socketService.socket.on('error', (data) {
      print('🔴 Socket error in chat request: $data');
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = data is Map
              ? (data['message'] ?? 'Unknown error')
              : 'Server error';
        });
      }
    });
  }

  void _loadPendingRequests() {
    print('🔍 Loading pending chat requests for: ${widget.currentUserId}');

    // Check if socket is connected first
    if (!_socketService.isConnected) {
      print('⚠️ Socket not connected, attempting to connect...');
      _socketService.connect(widget.currentUserId);

      // Try again after a short delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_socketService.isConnected) {
          print('✅ Socket connected, now requesting pending chat requests');
          _emitRequestEvents();

          // Set a backup timer to check if we received the requests
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _isLoading) {
              print('⏱️ Backup timer: Checking if requests were received');
              _emitRequestEvents();
            }
          });
        } else {
          print('❌ Failed to connect socket for chat requests');
          // Update UI to show error state
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = 'Failed to connect to server';
            });
          }
        }
      });
      return;
    }

    // Socket is connected, request chat requests
    _emitRequestEvents();

    // Set a backup timer
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isLoading) {
        print(
            '⏱️ Backup timer: Checking if requests were received while connected');
        _emitRequestEvents();
      }
    });
  }

  void _emitRequestEvents() {
    // Try both the standard format and alternative formats
    _socketService.getPendingChatRequests(widget.currentUserId);

    // Also send directly with the socket to bypass any middleware
    _socketService.socket.emit('getPendingChatRequests', {
      'userId': widget.currentUserId,
    });

    // Try alternative event name that the server might be using
    _socketService.socket.emit('getChatRequests',
        {'userId': widget.currentUserId, 'status': 'pending'});

    // Debug ping to verify server communication
    _socketService.socket.emit('ping_test', {
      'action': 'Requested pending chat requests',
      'userId': widget.currentUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    });
  }

  void _acceptRequest(ChatRequest request) {
    print('✓ Accepting chat request: ${request.requestId}');
    _socketService.respondToChatRequest(
      request.requestId,
      widget.currentUserId,
      request.senderId,
      true,
    );

    // Optimistically update UI
    setState(() {
      _pendingRequests.removeWhere((req) => req.requestId == request.requestId);
    });
  }

  void _rejectRequest(ChatRequest request) {
    print('✗ Rejecting chat request: ${request.requestId}');
    _socketService.respondToChatRequest(
      request.requestId,
      widget.currentUserId,
      request.senderId,
      false,
    );

    // Optimistically update UI
    setState(() {
      _pendingRequests.removeWhere((req) => req.requestId == request.requestId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Re-fetch requests when the screen becomes visible again
    if (!_isLoading && !_hasInitialized) {
      _loadPendingRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Requests'),
        actions: [
          // Debug button to force reconnect
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasInitialized = false;
                _hasError = false;
              });
              // Force reconnect the socket
              _socketService.disconnect();
              Future.delayed(const Duration(milliseconds: 500), () {
                _socketService.connect(widget.currentUserId);
                Future.delayed(const Duration(milliseconds: 500), () {
                  _loadPendingRequests();
                });
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading requests',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _hasError = false;
                            _errorMessage = '';
                          });
                          _loadPendingRequests();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _pendingRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.mail_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No pending chat requests',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                              });
                              _loadPendingRequests();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _pendingRequests.length,
                      itemBuilder: (context, index) {
                        final request = _pendingRequests[index];
                        return _buildRequestItem(request);
                      },
                    ),
    );
  }

  Widget _buildRequestItem(ChatRequest request) {
    print('Building request item for ${request.senderName}');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: request.senderAvatar != null
                      ? NetworkImage(request.senderAvatar!)
                      : null,
                  child: request.senderAvatar == null
                      ? Text(request.senderName.isNotEmpty
                          ? request.senderName.substring(0, 1).toUpperCase()
                          : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Wants to chat with you',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requested on ${_formatTimestamp(request.timestamp)}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _rejectRequest(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _acceptRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    // Remove direct event listeners
    _socketService.socket.off('chatRequestsList');

    // Clear callbacks to avoid memory leaks
    _socketService.onChatRequestsList = null;
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;
    super.dispose();
  }
}
