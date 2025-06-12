import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:leo_app_01/widgets/status_view_screen.dart';
import '../constants/app_constants.dart';
import '../models/message.dart';
import 'file_preview_widget.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onLongPress;
  final String currentUserId;
  final bool isSelected;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onLongPress,
    required this.currentUserId,
    this.isSelected = false,
  });

  // In the MessageBubble class, update the build method to handle taps on status messages

  // Enhanced build method with better debugging for status taps

  @override
  Widget build(BuildContext context) {
    // Check if message is deleted
    final bool isDeletedForMe = message.isDeletedFor(currentUserId);
    final bool isDeletedForEveryone = message.deletedForEveryone == true;
    final bool isDeleted = isDeletedForMe || isDeletedForEveryone;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              // Force a debug statement to verify the tap is detected
              debugPrint("⚡ Message bubble tapped");
              debugPrint("Message type: ${message.messageType}");

              // Handle navigation for status messages
              if (message.messageType == 'status_share' ||
                  message.messageType == 'status_reply') {
                debugPrint("✓ Status message detected - navigating");

                // Remove the call to the old _openSharedStatus method and use only _navigateToStatus
                _navigateToStatus(context);
              }
            },
            onLongPress: isDeleted ? null : onLongPress,
            child: Container(
              // Rest of your container code remains the same
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: message.messageType == AppConstants.messageTypeText ||
                      message.messageType == 'status_reply' ||
                      message.messageType == 'status_share'
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                  : const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getBubbleColor(isDeleted),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: message.messageType == AppConstants.messageTypeText ||
                        message.messageType == 'status_reply' ||
                        message.messageType == 'status_share'
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                    : const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getBubbleColor(isDeleted),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                  border: isSelected
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
                child: isDeleted
                    ? _buildDeletedMessageContent(isDeletedForEveryone)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // For status reply messages
                          if (message.messageType == 'status_reply')
                            _buildStatusReplyContent(context),

                          // For status share messages
                          if (message.messageType == 'status_share')
                            _buildStatusShareContent(context),

                          // File preview for non-special messages
                          if (message.messageType !=
                                  AppConstants.messageTypeText &&
                              message.messageType != 'status_reply' &&
                              message.messageType != 'status_share' &&
                              message.fileUrl != null &&
                              message.fileUrl!.isNotEmpty)
                            _buildFilePreview(context),

                          // Text message or caption
                          if (message.message.isNotEmpty &&
                              message.messageType != 'status_reply' &&
                              message.messageType != 'status_share')
                            Padding(
                              padding: message.messageType !=
                                      AppConstants.messageTypeText
                                  ? const EdgeInsets.only(top: 8)
                                  : EdgeInsets.zero,
                              child: Text(message.message),
                            ),

                          // Add some spacing before timestamp
                          const SizedBox(height: 4),

                          // Timestamp and status in a row at the end
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _formatTimestamp(message.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  message.read
                                      ? Icons.done_all
                                      : (message.delivered
                                          ? Icons.done_all
                                          : Icons.done),
                                  size: 16,
                                  color: message.read
                                      ? Colors.blue
                                      : Colors.grey[400],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // Update the status share content builder to make it consistent

  Widget _buildStatusShareContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status icon and tap indicator on the same row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.share, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Shared Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              // Only show tap indicator if status ID is present
              if (message.statusId != null && message.statusId!.isNotEmpty)
                Text(
                  'Tap to view',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Status content preview based on type
          _buildStatusSharePreview(),
        ],
      ),
    );
  }

  Widget _buildStatusSharePreview() {
    // For text status
    if (message.statusType == AppConstants.messageTypeText) {
      return Text(
        message.statusContent ?? '',
        style: const TextStyle(fontSize: 14),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    // For image status
    else if (message.statusType == AppConstants.messageTypeImage) {
      return Row(
        children: [
          // Small image preview if URL is available
          if (message.statusFileUrl != null &&
              message.statusFileUrl!.isNotEmpty)
            Container(
              height: 50,
              width: 50,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: message.statusFileUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Text(
              message.statusContent?.isNotEmpty == true
                  ? message.statusContent!
                  : 'Photo',
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    // For video status
    else if (message.statusType == AppConstants.messageTypeVideo) {
      return Row(
        children: [
          // Video thumbnail if URL is available
          if (message.statusFileUrl != null &&
              message.statusFileUrl!.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 50,
                  width: 50,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: message.statusFileUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.videocam,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          Expanded(
            child: Text(
              message.statusContent?.isNotEmpty == true
                  ? message.statusContent!
                  : 'Video',
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    // Default fallback
    else {
      return Row(
        children: [
          const Icon(Icons.insert_drive_file, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message.statusContent ?? 'Status',
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }

  // And update the _openSharedStatus method to first check socket connection
  // void _openSharedStatus(BuildContext context) async {
  //   try {
  //     print("=== ATTEMPTING TO OPEN SHARED STATUS ===");
  //     print("Status Info - ID: ${message.statusId ?? 'NULL'}");
  //     print("Status Info - Type: ${message.statusType ?? 'NULL'}");
  //     print("Status Info - Content: ${message.statusContent ?? 'NULL'}");
  //     print("Status Info - FileURL: ${message.statusFileUrl ?? 'NULL'}");

  //     // Check if status information is complete
  //     final bool hasStatusId =
  //         message.statusId != null && message.statusId!.isNotEmpty;
  //     final bool hasStatusUrl =
  //         message.statusFileUrl != null && message.statusFileUrl!.isNotEmpty;

  //     if (!hasStatusId || !hasStatusUrl) {
  //       print("ERROR: Status information is incomplete");
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //             content: Text('Status details not available or incomplete')),
  //       );
  //       return;
  //     }

  //     // Get status owner information - extract from content or use default
  //     String statusOwnerName = "User"; // Default fallback
  //     if (message.statusContent != null &&
  //         message.statusContent!.contains("Shared from ")) {
  //       try {
  //         statusOwnerName = message.statusContent!
  //             .split("Shared from ")[1]
  //             .split(":")[0]
  //             .trim();
  //       } catch (e) {
  //         print("Could not extract owner name: $e");
  //       }
  //     }

  //     print("Opening status with owner name: $statusOwnerName");

  //     // Navigate to status viewer as a full screen page
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => StatusViewScreen(
  //           currentUserId: currentUserId,
  //           imageUrl: message.statusFileUrl!,
  //           statusUserId: message.statusId!,
  //           userName: statusOwnerName,
  //         ),
  //       ),
  //     );
  //   } catch (e) {
  //     print('Error opening status: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error opening status: ${e.toString()}')),
  //     );
  //   }
  // }

  // Replace your _navigateToStatus method with this improved version

  void _navigateToStatus(BuildContext context) {
    // Force debug logs to appear
    debugPrint("=== NAVIGATING TO STATUS ===");
    debugPrint("Message Type: ${message.messageType}");
    debugPrint("Message ID: ${message.messageId}");
    debugPrint("Sender ID: ${message.senderId}");
    debugPrint("Receiver ID: ${message.receiverId}");
    debugPrint("Status Info - statusId: '${message.statusId}'");
    debugPrint("Status Info - statusType: '${message.statusType}'");
    debugPrint("Status Info - statusContent: '${message.statusContent}'");
    debugPrint("Status Info - statusFileUrl: '${message.statusFileUrl}'");

    try {
      // In your system, statusId field contains the ID of the user who created the status
      String? statusOwnerId = message.statusId;
      String mediaUrl = '';
      String statusOwnerName = "User"; // Default name

      // Generate a unique identifier for the specific status based on available information
      String specificStatusIdentifier =
          "${message.statusFileUrl ?? ''}:${message.statusType ?? ''}";

      debugPrint("Initial statusOwnerId: $statusOwnerId");

      // Use status file URL if available
      if (message.statusFileUrl != null && message.statusFileUrl!.isNotEmpty) {
        mediaUrl = message.statusFileUrl!;
      } else if (message.fileUrl != null && message.fileUrl!.isNotEmpty) {
        // Fallback to message's own file URL if status URL not available
        mediaUrl = message.fileUrl!;
      }

      // Try to extract status owner name from the message content
      if (message.statusContent != null &&
          message.statusContent!.contains("Shared from ")) {
        try {
          statusOwnerName = message.statusContent!
              .split("Shared from ")[1]
              .split(":")[0]
              .trim();
          debugPrint("Extracted status owner name: $statusOwnerName");
        } catch (e) {
          debugPrint("Failed to extract owner name: $e");
        }
      }

      // Validation for status owner ID
      if ((statusOwnerId == null || statusOwnerId.isEmpty) &&
          message.messageType == 'status_share') {
        debugPrint(
            "⚠️ WARNING: Status ID is missing in a shared status message!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Cannot view status: Missing original status information'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // If we still don't have a valid status owner ID, show error
      if (statusOwnerId == null || statusOwnerId.isEmpty) {
        debugPrint("CRITICAL ERROR: Could not determine status owner ID");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status details not available - Missing owner ID'),
          ),
        );
        return;
      }

      // Debug what we're about to navigate to
      debugPrint("🚀 Navigating to status with:");
      debugPrint("- Owner ID: $statusOwnerId");
      debugPrint("- Owner name: $statusOwnerName");
      debugPrint("- Media URL: $mediaUrl");
      debugPrint("- Specific status identifier: $specificStatusIdentifier");
      debugPrint("- Current user ID: $currentUserId");

      // Navigate to status view screen with additional information
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StatusViewScreen(
            currentUserId: currentUserId,
            statusUserId: statusOwnerId,
            imageUrl: mediaUrl,
            userName: statusOwnerName,
            // Pass extra properties to help identify the specific status
            targetMediaUrl: mediaUrl,
            targetStatusType: message.statusType ?? 'unknown',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening status: ${e.toString()}')),
      );
    }
  }

  // Build file preview with error handling
  Widget _buildFilePreview(BuildContext context) {
    // Check if file URL is valid
    if (message.fileUrl == null || message.fileUrl!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Invalid file',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Wrap FilePreviewWidget in error boundary
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FilePreviewWidget(
          fileUrl: message.fileUrl!,
          messageType: message.messageType,
          fileName: message.fileName,
        ),
      ),
    );
  }

  // Get the appropriate bubble color based on deletion status
  Color _getBubbleColor(bool isDeleted) {
    if (isDeleted) {
      return isMe ? const Color(0xFFE6E6E6) : const Color(0xFFF0F0F0);
    }
    return isMe ? const Color(0xFFDCF8C6) : Colors.white;
  }

  // Build the content for deleted messages
  Widget _buildDeletedMessageContent(bool isDeletedForEveryone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.block,
            size: 16,
            color: Colors.grey,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isDeletedForEveryone
                  ? 'This message was deleted'
                  : 'You deleted this message',
              style: const TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Status reply specific content builder
  // Update the status reply content builder to indicate it's tappable

  Widget _buildStatusReplyContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status content preview container with tap indicator
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status reply header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Replied to status',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  // Add a tap indicator
                  if (message.statusId != null && message.statusId!.isNotEmpty)
                    Text(
                      'Tap to view',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                        overflow: TextOverflow.ellipsis,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Status content preview based on type
              _buildStatusContentPreview(),
            ],
          ),
        ),

        // The actual reply message
        Text(message.message),
      ],
    );
  }

  // Helper to build status content preview based on type
  Widget _buildStatusContentPreview() {
    // For text status
    if (message.statusType == AppConstants.messageTypeText) {
      return Text(
        message.statusContent ?? '',
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    // For image status
    else if (message.statusType == AppConstants.messageTypeImage) {
      return Row(
        children: [
          if (message.statusFileUrl == null ||
              message.statusFileUrl!.isEmpty) ...[
            const Icon(Icons.image, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              message.statusContent ?? 'Photo',
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: message.statusFileUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      );
    }
    // For video status
    else if (message.statusType == AppConstants.messageTypeVideo) {
      return Row(
        children: [
          const Icon(Icons.videocam, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message.statusContent?.isNotEmpty == true
                  ? message.statusContent!
                  : 'Video',
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    // Default fallback
    else {
      return Text(
        message.statusContent ?? 'Status',
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
