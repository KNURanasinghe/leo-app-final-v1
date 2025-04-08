import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:leo_app_01/HomeScreen.dart';
import 'package:leo_app_01/chat/chatting.dart';
import 'package:leo_app_01/models/message.dart';
import 'package:leo_app_01/services/socket_service.dart';
import 'package:leo_app_01/widgets/status_create_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_helper;
import 'package:shared_preferences/shared_preferences.dart';

// Create a simple class to hold media information
class StatusMediaInfo {
  final File? mediaFile;
  final String mediaType;
  final String caption;

  StatusMediaInfo({
    this.mediaFile,
    required this.mediaType,
    required this.caption,
  });
}

class StatusShareDialog extends StatefulWidget {
  final String statusId;
  final String mediaUrl;
  final String mediaType;
  final String caption;
  final String statusOwnerName;

  const StatusShareDialog({
    super.key,
    required this.statusId,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.statusOwnerName,
  });

  @override
  State<StatusShareDialog> createState() => _StatusShareDialogState();
}

class _StatusShareDialogState extends State<StatusShareDialog> {
  bool _isDownloading = false;
  StatusMediaInfo? _downloadedMedia;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Download media immediately when dialog opens
    if (widget.mediaUrl.isNotEmpty && widget.mediaType != 'text') {
      _downloadMedia();
    } else {
      // For text-only statuses, create media info without file
      _downloadedMedia = StatusMediaInfo(
        mediaType: widget.mediaType,
        caption: widget.caption.isNotEmpty
            ? 'Shared from ${widget.statusOwnerName}: ${widget.caption}'
            : 'Shared from ${widget.statusOwnerName}',
      );
    }
  }

  Future<void> _downloadMedia() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(widget.mediaUrl));
      final directory = await getTemporaryDirectory();
      final fileName =
          'shared_status_${DateTime.now().millisecondsSinceEpoch}.${path_helper.extension(widget.mediaUrl)}';
      final localPath = '${directory.path}/$fileName';
      final mediaFile = File(localPath);
      await mediaFile.writeAsBytes(response.bodyBytes);

      print("Media file downloaded: ${mediaFile.path}");

      // Create media info with downloaded file
      _downloadedMedia = StatusMediaInfo(
        mediaFile: mediaFile,
        mediaType: widget.mediaType,
        caption: widget.caption.isNotEmpty
            ? 'Shared from ${widget.statusOwnerName}: ${widget.caption}'
            : 'Shared from ${widget.statusOwnerName}',
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    } catch (e) {
      print("Error downloading media: $e");
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = "Error downloading media: $e";
        });
      }
    }
  }

  void _shareAsStatus(BuildContext context) async {
    // If media is still downloading, show message and return
    if (_isDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please wait while media is preparing...')),
      );
      return;
    }

    // If there was an error downloading, show message and return
    if (_errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
      return;
    }

    // Get current user ID
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId');

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Could not identify current user')),
      );
      return;
    }

    // Close the dialog and navigate
    Navigator.of(context).pop();

    // Now navigate directly to StatusCreateScreen with the already downloaded media
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatusCreateScreen(
          currentUserId: currentUserId,
          sharedMedia: _downloadedMedia?.mediaFile,
          sharedMediaType: _downloadedMedia?.mediaType,
          sharedCaption: _downloadedMedia?.caption,
        ),
      ),
    );
  }

  void _shareToChat(BuildContext context) async {
    print("_shareToChat method called");

    // If media is still downloading, show message and return
    if (_isDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please wait while media is preparing...')),
      );
      return;
    }

    // If there was an error downloading, show message and return
    if (_errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
      return;
    }

    // Get current user ID first
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId');

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Could not identify current user')),
      );
      return;
    }

    // Print debug information about the status being shared
    print("DEBUG: Sharing status with the following information:");
    print("Status ID: ${widget.statusId}");
    print("Media Type: ${widget.mediaType}");
    print("Caption: ${widget.caption}");
    print("Media URL: ${widget.mediaUrl}");
    print("Owner Name: ${widget.statusOwnerName}");

    // Fetch users before closing the dialog
    try {
      final response = await http.get(
        Uri.parse('http://145.223.21.62:8090/api/collections/users/records'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> userItems = data['items'] as List;

        // Filter out current user
        final List<_UserListItem> users = userItems
            .where((item) => item['id'] != currentUserId)
            .map((item) => _UserListItem(
                  id: item['id'],
                  name: '${item['firstname'] ?? ''} ${item['lastname'] ?? ''}'
                      .trim(),
                  avatar: item['avatar'],
                  bio: item['bio'],
                ))
            .toList();

        // Now that we have all the data, close the first dialog
        Navigator.of(context).pop();

        // Use a delayed call to show the new dialog
        Future.delayed(Duration.zero, () {
          // Get a fresh BuildContext by pushing a new page instead of showing a dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => ContactSelectionPage(
                users: users,
                currentUserId: currentUserId,
                statusId: widget.statusId,
                mediaUrl: widget.mediaUrl,
                mediaType: widget.mediaType,
                caption: widget.caption,
                statusOwnerName: widget.statusOwnerName,
              ),
            ),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching users: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _sendStatusToUser(String receiverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('userId');
      // Debug log for status information
      print("*** STATUS SHARE DATA VERIFICATION ***");
      print("statusId: '${widget.statusId}'");
      print("mediaType: '${widget.mediaType}'");
      print("caption: '${widget.caption}'");
      print("mediaUrl: '${widget.mediaUrl}'");

      // Verify that we have required status information
      if (widget.statusId.isEmpty) {
        print("WARNING: Status ID is empty!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Status ID is missing')),
        );
        return;
      }

      if (widget.mediaUrl.isEmpty) {
        print("WARNING: Media URL is empty!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Media URL is missing')),
        );
        return;
      }

      // Create a message that references the status - using a Map first to ensure all fields are properly set
      final Map<String, dynamic> messageData = {
        'messageId':
            "msg_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(10)}",
        'senderId': currentUserId,
        'receiverId': receiverId,
        'message': 'Shared a status with you',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'delivered': false,
        'read': false,
        'messageType': 'status_share',
        // Explicitly set status fields
        'statusId': widget.statusId,
        'statusType': widget.mediaType,
        'statusContent': widget.caption,
        'statusFileUrl': widget.mediaUrl,
      };

      print("Creating message with status data: $messageData");

      // Create message object from the data
      final message = Message.fromJson(messageData);

      // Verify that status fields were properly set in the Message object
      print("Verifying message object:");
      print("message.statusId: '${message.statusId}'");
      print("message.statusType: '${message.statusType}'");
      print("message.statusContent: '${message.statusContent}'");
      print("message.statusFileUrl: '${message.statusFileUrl}'");

      // Using SocketService to send the message
      final socketService = SocketService();

      // Ensure socket is connected
      if (!socketService.isConnected) {
        print("Socket not connected, connecting...");
        socketService.connect(currentUserId!);
        // Give some time for connection to establish
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      print("Sending message via socket...");

      // Send using the regular message method instead of status-specific one
      socketService.sendMessage(message);

      // Show confirmation and close
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status shared successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error sending status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Add this helper method to the ContactSelectionPage class
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Share Status',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Loading indicator while downloading
            if (_isDownloading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text(
                    'Preparing media...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                'Share ${widget.statusOwnerName}\'s status as:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),

              // Error message if any
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),

              // Share options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Share to Chat Option
                  _buildShareOption(
                    context,
                    Icons.chat_bubble,
                    'Share to Chat',
                    Colors.green[400]!,
                    () => _shareToChat(context),
                  ),

                  // Share as Own Status Option
                  _buildShareOption(
                    context,
                    Icons.add_circle,
                    'Post as My Status',
                    Colors.blue[400]!,
                    () => _shareAsStatus(context),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  backgroundColor: Colors.blue[50],
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    // Disable the option if still downloading
    final bool isEnabled = !_isDownloading;

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: (isEnabled ? color : Colors.grey).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isEnabled ? color : Colors.grey).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isEnabled ? color : Colors.grey,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isEnabled ? color : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserListItem {
  final String id;
  final String name;
  final String? avatar;
  final String? bio;

  _UserListItem({
    required this.id,
    required this.name,
    this.avatar,
    this.bio,
  });
}

class ContactSelectionPage extends StatefulWidget {
  final List<_UserListItem> users;
  final String currentUserId;
  final String statusId;
  final String mediaUrl;
  final String mediaType;
  final String caption;
  final String statusOwnerName;

  const ContactSelectionPage({
    super.key,
    required this.users,
    required this.currentUserId,
    required this.statusId,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.statusOwnerName,
  });

  @override
  _ContactSelectionPageState createState() => _ContactSelectionPageState();
}

class _ContactSelectionPageState extends State<ContactSelectionPage> {
  late List<_UserListItem> filteredUsers;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredUsers = widget.users;
  }

  void _filterUsers(String query) {
    setState(() {
      filteredUsers = widget.users
          .where(
              (user) => user.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _sendStatusToUser(String receiverId) async {
    print("Creating message with status - ID: ${widget.statusId}");
    print("Creating message with status - Type: ${widget.mediaType}");
    print("Creating message with status - Content: ${widget.caption}");
    print("Creating message with status - URL: ${widget.mediaUrl}");
    try {
      // Create a message that references the status
      final message = Message(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: widget.currentUserId,
        message: 'Shared a status with you', // Default message text
        timestamp: DateTime.now().millisecondsSinceEpoch,
        delivered: false,
        read: false,
        messageType: 'status_share', // Special type for shared statuses
        receiverId: receiverId,
        // Status information
        statusId: widget.statusId,
        statusType: widget.mediaType,
        statusContent: widget.caption,
        statusFileUrl: widget.mediaUrl,
      );
      print("Message created with status - ID: ${message.statusId}");
      print("Message created with status - Type: ${message.statusType}");
      print("Message created with status - Content: ${message.statusContent}");
      print("Message created with status - URL: ${message.statusFileUrl}");
      final json = message.toJson();
      print("Message JSON: $json");
      print("JSON contains statusId: ${json.containsKey('statusId')}");
      print("JSON contains statusType: ${json.containsKey('statusType')}");
      print(
          "JSON contains statusContent: ${json.containsKey('statusContent')}");
      print(
          "JSON contains statusFileUrl: ${json.containsKey('statusFileUrl')}");
      // Using SocketService to send the message
      final socketService = SocketService();

      // Ensure socket is connected
      if (!socketService.isConnected) {
        socketService.connect(widget.currentUserId);
        // Give some time for connection to establish
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Send the message
      socketService.sendMessage(message);

      // Show confirmation and close
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status shared successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error sending status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share to Chat'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: TextStyle(color: Colors.blue[200]),
                prefixIcon: Icon(Icons.search, color: Colors.blue[300]),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              onChanged: _filterUsers,
            ),
          ),

          // Users List
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.blue[200],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No contacts found',
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.blue[100]!,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: user.avatar != null
                                ? CachedNetworkImage(
                                    imageUrl:
                                        'http://145.223.21.62:8090/api/files/users/${user.id}/${user.avatar}',
                                    imageBuilder: (context, imageProvider) =>
                                        CircleAvatar(
                                      backgroundImage: imageProvider,
                                      radius: 25,
                                    ),
                                    placeholder: (context, url) => CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Colors.blue[50],
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blue[300],
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Colors.blue[50],
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.blue[300],
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Colors.blue[50],
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.blue[300],
                                    ),
                                  ),
                          ),
                          title: Text(
                            user.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue[900],
                            ),
                          ),
                          subtitle: Text(
                            user.bio?.isNotEmpty == true
                                ? user.bio!
                                : "Hey I'm using Leo Chat",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.blue[300],
                              fontSize: 14,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.blue[200],
                          ),
                          onTap: () => _sendStatusToUser(user.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
