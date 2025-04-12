// Add this widget to your DemoChattingMessageListPage class
// This will be shown before users can chat, showing the request status

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
    Key? key,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
    this.receiverProfileUrl,
    required this.onRequestApproved,
  }) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
    _checkRequestStatus();
  }

  void _setupSocketListeners() {
    _socketService.onChatRequestUpdated = (request) {
      if ((request.senderId == widget.currentUserId &&
              request.receiverId == widget.receiverId) ||
          (request.receiverId == widget.currentUserId &&
              request.senderId == widget.receiverId)) {
        setState(() {
          _requestStatus = request.status;
          _requestData = request;

          if (request.status == 'approved') {
            // Notify parent widget that request is approved
            widget.onRequestApproved();
          }
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

    // Set up listener for the response
    _socketService.onChatRequestUpdated = (request) {
      if ((request.senderId == widget.currentUserId &&
              request.receiverId == widget.receiverId) ||
          (request.receiverId == widget.currentUserId &&
              request.senderId == widget.receiverId)) {
        setState(() {
          _requestStatus = request.status;
          _requestData = request;
          _isSender = request.senderId == widget.currentUserId;

          if (request.status == 'approved') {
            widget.onRequestApproved();
          }
        });
      }
    };

    // Check request status
    _socketService.checkChatRequestStatus(
      widget.currentUserId,
      widget.receiverId,
    );

    // Fallback timeout in case we don't get a response
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _requestStatus == 'checking') {
        setState(() {
          _requestStatus = 'none';
        });
      }
    });
  }

  void _sendChatRequest() {
    setState(() {
      _requestStatus = 'sending';
    });

    // Get current user name - in a real app you'd store this with the user
    final currentUserName = widget.currentUserId; // replace with actual name

    _socketService.sendChatRequest(
      widget.currentUserId,
      widget.receiverId,
      currentUserName, // Replace with actual name
      null, // Replace with avatar URL if available
    );
  }

  void _approveRequest() {
    if (_requestData != null) {
      _socketService.respondToChatRequest(
        _requestData!.requestId,
        widget.currentUserId,
        _requestData!.senderId,
        true,
      );
    }
  }

  void _rejectRequest() {
    if (_requestData != null) {
      _socketService.respondToChatRequest(
        _requestData!.requestId,
        widget.currentUserId,
        _requestData!.senderId,
        false,
      );

      // Navigate back after rejection
      Navigator.of(context).pop();
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
              onPressed: _sendChatRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Send Chat Request'),
            ),
          ],
        ),
      );
    }

    // Request is pending
    if (_requestStatus == 'pending') {
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
                    ? widget.receiverProfileUrl == null
                        ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                        : null
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
}
