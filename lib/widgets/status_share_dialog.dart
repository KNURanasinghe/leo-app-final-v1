// Create a new file named status_share_dialog.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leo_app_01/HomeScreen.dart';
import 'package:leo_app_01/chat/chatting.dart';
import 'package:leo_app_01/widgets/status_create_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_helper;
import 'package:shared_preferences/shared_preferences.dart';

class StatusShareDialog extends StatelessWidget {
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

            Text(
              'Share $statusOwnerName\'s status as:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareToChat(BuildContext context) async {
    Navigator.of(context).pop(); // Close the dialog

    // Use the existing chat users dialog
    showDefaultNewPeerChatDialog(context).then((selectedUserId) {
      if (selectedUserId != null && selectedUserId.isNotEmpty) {
        _downloadAndShareMedia(context, selectedUserId, false);
      }
    });
  }

  void _shareAsStatus(BuildContext context) async {
    Navigator.of(context).pop(); // Close the dialog

    // Get current user ID
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId');

    if (currentUserId != null) {
      _downloadAndShareMedia(context, currentUserId, true);
    } else {
      // Show error if user ID couldn't be retrieved
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Could not identify current user')),
      );
    }
  }

  Future<void> _downloadAndShareMedia(
      BuildContext context, String userId, bool asStatus) async {
    // Capture the current context to ensure it's still valid
    BuildContext? savedContext = context;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Preparing media...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Only download if we have a media URL and it's not text-only status
      File? mediaFile;
      if (mediaUrl.isNotEmpty && mediaType != 'text') {
        // Download the media
        final response = await http.get(Uri.parse(mediaUrl));

        // Get temporary directory and create a file
        final directory = await getTemporaryDirectory();
        final fileName =
            'shared_status_${DateTime.now().millisecondsSinceEpoch}.${path_helper.extension(mediaUrl)}';
        final localPath = '${directory.path}/$fileName';

        // Write the file
        mediaFile = File(localPath);
        await mediaFile.writeAsBytes(response.bodyBytes);
      }

      // Use a post-frame callback to ensure we're in a stable state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Close loading dialog
        Navigator.of(savedContext ?? context).pop();

        if (asStatus) {
          // Navigate to status creation screen with the media
          Navigator.push(
            savedContext ?? context,
            MaterialPageRoute(
              builder: (context) => StatusCreateScreen(
                currentUserId: userId,
                sharedMedia: mediaFile,
                sharedMediaType: mediaType,
                sharedCaption: caption.isNotEmpty
                    ? 'Shared from $statusOwnerName: $caption'
                    : 'Shared from $statusOwnerName',
              ),
            ),
          );
        } else {
          // Navigate to chat screen with the pre-filled media
          _navigateToChat(
              savedContext ?? context, userId, mediaFile, mediaType);
        }
      });
    } catch (e) {
      // Use a post-frame callback to show error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Close loading dialog
        Navigator.of(savedContext ?? context).pop();

        // Show error
        ScaffoldMessenger.of(savedContext ?? context).showSnackBar(
          SnackBar(content: Text('Error preparing media: $e')),
        );
      });
    }
  }

  void _navigateToChat(BuildContext context, String receiverId, File? mediaFile,
      String mediaType) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId');

    if (currentUserId == null) return;

    // Get receiver details (you might need to fetch this from your database)
    // For now, we'll just pass the ID and get other details later

    // Set the bottom bar visibility to false
    try {
      HomeScreen.setBottomBarVisibility(false);
    } catch (e) {
      // Handle if the method isn't available
      print('Could not set bottom bar visibility: $e');
    }

    // Navigate to the chat page with media file pre-loaded
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => DemoChattingMessageListPage(
    //       receiverId: receiverId,
    //       currentUserId: currentUserId,
    //       receiverName: "User", // This would need to be fetched
    //       receiverProfileUrl: null,
    //       sharedMedia: mediaFile,
    //       sharedMediaType: mediaType,
    //       sharedCaption: caption.isNotEmpty
    //           ? 'Shared from ${statusOwnerName}: $caption'
    //           : 'Shared from ${statusOwnerName}',
    //     ),
    //   ),
    // ).then((_) {
    //   // Show bottom bar again when returning
    //   try {
    //     HomeScreen.setBottomBarVisibility(true);
    //   } catch (e) {
    //     print('Could not set bottom bar visibility: $e');
    //   }
    // });
  }

  // This is a proxy method that calls your existing dialog
  Future<String?> showDefaultNewPeerChatDialog(BuildContext context) async {
    // Use the existing dialog function to select a chat
    // We create a completer to convert it to a Future that returns a value
    Completer<String?> completer = Completer<String?>();

    // Call your existing function
    // Replace this with the actual call to your showDefaultNewPeerChatDialog function
    // This is just a placeholder
    showDialog<String>(
      context: context,
      builder: (context) => _UserSelectionDialogProxy(onUserSelected: (userId) {
        completer.complete(userId);
      }),
    );

    return completer.future;
  }
}

// This is a temporary proxy widget that should be replaced with your actual implementation
class _UserSelectionDialogProxy extends StatelessWidget {
  final Function(String?) onUserSelected;

  const _UserSelectionDialogProxy({required this.onUserSelected});

  @override
  Widget build(BuildContext context) {
    // In reality, this would be replaced with your actual dialog
    // This is just a placeholder to make the code compile
    return AlertDialog(
      title: const Text('Select User'),
      content: const Text(
          'This is a placeholder. Replace with your actual user selection dialog.'),
      actions: [
        TextButton(
          onPressed: () => onUserSelected(null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
