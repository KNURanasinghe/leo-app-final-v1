// chat_request_status.dart
import 'package:flutter/material.dart';
import 'package:leo_app_01/constants/app_constants.dart';
import 'package:leo_app_01/models/request_model.dart';
import 'package:leo_app_01/services/socket_service.dart';

class ChatRequestStatusWidget extends StatefulWidget {
  final String currentUserId;
  final String receiverId;
  final String receiverName;
  final String? receiverProfileUrl;
  final Function onRequestApproved;

  const ChatRequestStatusWidget({
    super.key,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
    this.receiverProfileUrl,
    required this.onRequestApproved,
  });

  @override
  _ChatRequestStatusWidgetState createState() =>
      _ChatRequestStatusWidgetState();
}

class _ChatRequestStatusWidgetState extends State<ChatRequestStatusWidget> {
  final SocketService _socketService = SocketService();
  String _requestStatus =
      'checking'; // 'checking', 'none', 'pending', 'approved', 'rejected'
  ChatRequest? _requestData;
  bool _isSender = false;
  bool _isSending = false;
  int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();

    // Add a short delay to ensure socket is connected
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkRequestStatus();
    });
  }

  void _setupSocketListeners() {
    print('⚙️ Setting up chat request status listeners');
    // Clear any existing listeners to avoid duplicates
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;
    _socketService.onError = null;

    _socketService.onChatRequestUpdated = (request) {
      print('🔄 Chat request status updated: ${request.status}');
      if ((request.senderId == widget.currentUserId &&
              request.receiverId == widget.receiverId) ||
          (request.receiverId == widget.currentUserId &&
              request.senderId == widget.receiverId)) {
        if (mounted) {
          setState(() {
            _requestStatus = request.status;
            _requestData = request;
            _isSender = request.senderId == widget.currentUserId;

            if (request.status == 'approved') {
              // Notify parent widget that request is approved
              widget.onRequestApproved();
            }
          });
        }
      }
    };

    // Listen for chat request received to handle user receiving a request while on this screen
    _socketService.onChatRequestReceived = (request) {
      if (request.receiverId == widget.currentUserId &&
          request.senderId == widget.receiverId) {
        if (mounted) {
          setState(() {
            _requestStatus = 'pending';
            _requestData = request;
            _isSender = false;
          });
        }
      }
    };

    // Add error handler
    _socketService.onError = (errorData) {
      print('❌ Error in chat request status: $errorData');
      if (mounted && _requestStatus == 'checking') {
        // Only update if still in checking state
        setState(() {
          _requestStatus = 'none'; // Default to no request on error
        });
      }
    };
  }

  void _checkRequestStatus() {
    // First check if this is an admin (admins don't need requests)
    if (AppConstants.adminUsers.contains(widget.currentUserId) ||
        AppConstants.adminUsers.contains(widget.receiverId)) {
      setState(() {
        _requestStatus = 'approved';
      });
      widget.onRequestApproved();
      return;
    }

    // Check socket connection first
    if (!_socketService.isConnected) {
      print(
          '⚠️ Socket not connected, connecting for chat request status check...');
      _socketService.connect(widget.currentUserId);

      // Retry after a delay to allow connection
      Future.delayed(const Duration(seconds: 1), () {
        if (_socketService.isConnected) {
          print('✅ Socket connected, now checking chat request status');
          _emitRequestStatusCheck();
        } else {
          print('❌ Failed to connect socket');
          _retryOrFallback();
        }
      });
    } else {
      // Socket is connected, proceed with request
      _emitRequestStatusCheck();
    }
  }

  void _retryOrFallback() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      print('🔄 Retry attempt $_retryCount of $_maxRetries');
      Future.delayed(Duration(seconds: 1 * _retryCount), () {
        _checkRequestStatus();
      });
    } else {
      // Fall back to default state
      if (mounted) {
        setState(() {
          _requestStatus = 'none';
        });
      }
    }
  }

  void _emitRequestStatusCheck() {
    // Check request status
    print(
        '🔍 Checking chat request status between ${widget.currentUserId} and ${widget.receiverId}');
    _socketService.checkChatRequestStatus(
      widget.currentUserId,
      widget.receiverId,
    );

    // Also try a direct request for all pending requests
    _socketService.getPendingChatRequests(widget.currentUserId);

    // Fallback timeout in case we don't get a response
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _requestStatus == 'checking') {
        print('⚠️ No response received for chat request status check');
        _retryOrFallback();
      }
    });
  }

  void _sendChatRequest() {
    if (_isSending) return; // Prevent multiple sends

    setState(() {
      _isSending = true;
      _requestStatus = 'sending';
    });

    // Get current user name - in a real app you'd store this with the user
    final currentUserName = widget.currentUserId; // replace with actual name

    print(
        '📤 Sending chat request from ${widget.currentUserId} to ${widget.receiverId}');

    _socketService.sendChatRequest(
      widget.currentUserId,
      widget.receiverId,
      currentUserName, // Replace with actual name
      null, // Replace with avatar URL if available
    );

    // Update UI after short delay assuming request was sent successfully
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isSending = false;
          _requestStatus = 'pending';
          _isSender = true; // Set as sender since we just sent a request

          // Create a temporary request object until we get server confirmation
          _requestData = ChatRequest(
            requestId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
            senderId: widget.currentUserId,
            receiverId: widget.receiverId,
            senderName: currentUserName,
            senderAvatar: null,
            status: 'pending',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
        });
      }
    });
  }

  void _approveRequest() {
    if (_requestData != null) {
      print('✓ Approving chat request: ${_requestData!.requestId}');
      _socketService.respondToChatRequest(
        _requestData!.requestId,
        widget.currentUserId,
        _requestData!.senderId,
        true,
      );

      // Optimistically update status
      setState(() {
        _requestStatus = 'approved';
      });

      // Notify parent that request is approved
      widget.onRequestApproved();
    }
  }

  void _rejectRequest() {
    if (_requestData != null) {
      print('✗ Rejecting chat request: ${_requestData!.requestId}');
      _socketService.respondToChatRequest(
        _requestData!.requestId,
        widget.currentUserId,
        _requestData!.senderId,
        false,
      );

      // Optimistically update status
      setState(() {
        _requestStatus = 'rejected';
      });

      // Navigate back after rejection
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking status
    if (_requestStatus == 'checking') {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking chat status...')
          ],
        ),
      );
    }

    // No request exists
    if (_requestStatus == 'none') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: widget.receiverProfileUrl != null
                  ? NetworkImage(widget.receiverProfileUrl!)
                  : null,
              child: widget.receiverProfileUrl == null
                  ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              widget.receiverName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You need to send a chat request before you can start a conversation',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSending ? null : _sendChatRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isSending
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )),
                        SizedBox(width: 8),
                        Text('Sending...'),
                      ],
                    )
                  : const Text('Send Chat Request'),
            ),
          ],
        ),
      );
    }

    // Request is pending
    if (_requestStatus == 'pending' || _requestStatus == 'sending') {
      // If current user is the sender
      if (_isSender ||
          (_requestData != null &&
              _requestData!.senderId == widget.currentUserId)) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: widget.receiverProfileUrl != null
                    ? NetworkImage(widget.receiverProfileUrl!)
                    : null,
                child: widget.receiverProfileUrl == null
                    ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                widget.receiverName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.hourglass_empty,
                      color: Colors.amber,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chat Request Pending',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for ${widget.receiverName} to accept your chat request',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              )
            ],
          ),
        );
      }
      // If current user is the receiver
      else {
        final senderName = _requestData?.senderName ?? 'User';

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: _requestData?.senderAvatar != null
                    ? NetworkImage(_requestData!.senderAvatar!)
                    : null,
                child: _requestData?.senderAvatar == null
                    ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                senderName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'wants to chat with you',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _rejectRequest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _approveRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    }

    // Request was rejected
    if (_requestStatus == 'rejected') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
                radius: 40,
                backgroundImage: widget.receiverProfileUrl != null
                    ? NetworkImage(widget.receiverProfileUrl!)
                    : null,
                child: widget.receiverProfileUrl == null
                    ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                    : null),
            const SizedBox(height: 16),
            Text(
              widget.receiverName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.block,
                    color: Colors.red,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chat Request Rejected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSender
                        ? '${widget.receiverName} has declined your chat request'
                        : 'You have declined the chat request',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            )
          ],
        ),
      );
    }

    // Request was approved - this should call onRequestApproved and not be seen
    return const SizedBox();
  }

  @override
  void dispose() {
    // Clean up listeners to avoid memory leaks
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;
    _socketService.onError = null;
    super.dispose();
  }
}
