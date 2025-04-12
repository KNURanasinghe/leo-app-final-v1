// chat_request_screen.dart
import 'package:flutter/material.dart';
import 'package:leo_app_01/models/request_model.dart';
import '../services/socket_service.dart';

class ChatRequestScreen extends StatefulWidget {
  final String currentUserId;

  const ChatRequestScreen({
    Key? key,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _ChatRequestScreenState createState() => _ChatRequestScreenState();
}

class _ChatRequestScreenState extends State<ChatRequestScreen> {
  final SocketService _socketService = SocketService();
  final List<ChatRequest> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
    _loadPendingRequests();
  }

  void _setupSocketListeners() {
    _socketService.onChatRequestsList = (requests) {
      setState(() {
        _pendingRequests.clear();
        _pendingRequests.addAll(requests);
        _isLoading = false;
      });
    };

    _socketService.onChatRequestUpdated = (request) {
      if (request.status != 'pending') {
        // Remove the request if it's no longer pending
        setState(() {
          _pendingRequests
              .removeWhere((req) => req.requestId == request.requestId);
        });
      }
    };

    _socketService.onChatRequestReceived = (request) {
      // Add new request if it's for the current user and is pending
      if (request.receiverId == widget.currentUserId &&
          request.status == 'pending') {
        setState(() {
          _pendingRequests.add(request);
        });
      }
    };
  }

  void _loadPendingRequests() {
    _socketService.getPendingChatRequests(widget.currentUserId);
  }

  void _acceptRequest(ChatRequest request) {
    _socketService.respondToChatRequest(
      request.requestId,
      widget.currentUserId,
      request.senderId,
      true,
    );
  }

  void _rejectRequest(ChatRequest request) {
    _socketService.respondToChatRequest(
      request.requestId,
      widget.currentUserId,
      request.senderId,
      false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Requests'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? const Center(child: Text('No pending chat requests'))
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
                      ? Text(request.senderName.substring(0, 1).toUpperCase())
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
}
