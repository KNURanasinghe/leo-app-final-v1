// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
// import '../voiceRoom/inroom_message.dart';
//
// class InlineMessageList extends StatefulWidget {
//   final List<ChatMessage> messages;
//   final String currentUserId;
//   final int maxVisibleMessages;
//   final Widget welcome;
//
//   const InlineMessageList({
//     super.key,
//     required this.messages,
//     required this.currentUserId,
//     this.maxVisibleMessages = 5,
//     required this.welcome,
//   });
//
//   @override
//   State<InlineMessageList> createState() => _InlineMessageListState();
// }
//
// class _InlineMessageListState extends State<InlineMessageList> {
//   final ScrollController _scrollController = ScrollController();
//
//   // [Keep existing code for scrolling]...
//
//
//   @override
//   Widget build(BuildContext context) {
//     // Calculate visible messages (most recent ones)
//     final visibleMessages = widget.messages.length <= widget.maxVisibleMessages
//         ? widget.messages
//         : widget.messages
//             .sublist(widget.messages.length - widget.maxVisibleMessages);
//
//     return Container(
//       constraints: const BoxConstraints(maxHeight: 300),
//       child: ListView(
//         controller: _scrollController,
//         children: [
//           // Include welcome widget as part of the scrollable content
//           widget.welcome,
//
//           // Messages list
//           ...visibleMessages.map((message) => _buildMessageItem(
//                 message,
//                 message.userId == widget.currentUserId,
//                 context,
//               )),
//
//           // Add a small space at the bottom to ensure messages aren't cut off
//           const SizedBox(height: 8),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageItem(
//       ChatMessage message, bool isCurrentUser, BuildContext context) {
//     // Handle different message types
//     // if (message.type == MessageType.entry) {
//     //   return _buildEntryMessageItem(message, isCurrentUser, context);
//     // }
//
//     // Regular message (existing code)
//     return Container(
//       alignment: Alignment.centerLeft,
//       margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//         width: MediaQuery.of(context).size.width * 0.6,
//         decoration: BoxDecoration(
//           color: Colors.black.withOpacity(0.6),
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: Colors.white24, width: 1),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               isCurrentUser ? "You" : message.userName,
//               style: TextStyle(
//                 color: isCurrentUser ? Colors.white : Colors.yellow,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 12,
//                 decoration: TextDecoration.none,
//                 fontFamily: 'poppins',
//               ),
//             ),
//             const SizedBox(height: 2),
//             Text(
//               message.message,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.normal,
//                 fontSize: 14,
//                 decoration: TextDecoration.none,
//                 fontFamily: 'poppins',
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Widget _buildEntryMessageItem(
//   //     ChatMessage message, bool isCurrentUser, BuildContext context) {
//   //   return Container(
//   //     margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//   //     child: Column(
//   //       children: [
//   //         // Entry animation if itemUrl is provided
//   //         if (message.itemUrl != null && message.itemUrl!.isNotEmpty)
//   //           Container(
//   //             height: 100, // Adjust height as needed
//   //             alignment: Alignment.center,
//   //             child: SVGASimpleImage(resUrl: message.itemUrl!),
//   //           ),
//
//   //         // Entry message with name
//   //         Container(
//   //           padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//   //           width: MediaQuery.of(context).size.width * 0.6,
//   //           decoration: BoxDecoration(
//   //             color: Colors.black.withOpacity(0.6),
//   //             borderRadius: BorderRadius.circular(16),
//   //             border:
//   //                 Border.all(color: Colors.purple.withOpacity(0.4), width: 1),
//   //           ),
//   //           child: Row(
//   //             children: [
//   //               if (message.avatarUrl != null && message.avatarUrl!.isNotEmpty)
//   //                 ClipRRect(
//   //                   borderRadius: BorderRadius.circular(15),
//   //                   child: CachedNetworkImage(
//   //                     imageUrl: message.avatarUrl!,
//   //                     width: 24,
//   //                     height: 24,
//   //                     fit: BoxFit.cover,
//   //                     placeholder: (context, url) => Container(
//   //                       color: Colors.grey.shade200,
//   //                       child: const Icon(Icons.person,
//   //                           size: 14, color: Colors.grey),
//   //                     ),
//   //                     errorWidget: (context, error, stackTrace) => const Icon(
//   //                         Icons.person,
//   //                         size: 14,
//   //                         color: Colors.white),
//   //                   ),
//   //                 ),
//   //               const SizedBox(width: 8),
//   //               Text(
//   //                 isCurrentUser ? "You" : message.userName,
//   //                 style: const TextStyle(
//   //                   color: Colors.yellow,
//   //                   fontWeight: FontWeight.bold,
//   //                   fontSize: 12,
//   //                   decoration: TextDecoration.none,
//   //                   fontFamily: 'poppins',
//   //                 ),
//   //               ),
//   //               const SizedBox(width: 4),
//   //               Expanded(
//   //                 child: Text(
//   //                   message.message,
//   //                   style: const TextStyle(
//   //                     color: Colors.white,
//   //                     fontSize: 12,
//   //                     decoration: TextDecoration.none,
//   //                     fontFamily: 'poppins',
//   //                   ),
//   //                   overflow: TextOverflow.ellipsis,
//   //                 ),
//   //               ),
//   //             ],
//   //           ),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }
//
//   @override
//   void didUpdateWidget(covariant InlineMessageList oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     if (widget.messages.length != oldWidget.messages.length) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (_scrollController.hasClients) {
//           _scrollController.animateTo(
//             _scrollController.position.maxScrollExtent,
//             duration: const Duration(milliseconds: 300),
//             curve: Curves.easeOut,
//           );
//         }
//       });
//     }
//   }
//
// }

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import '../voiceRoom/inroom_message.dart';

class InlineMessageList extends StatefulWidget {
  final List<ChatMessage> messages;
  final String currentUserId;
  final int maxVisibleMessages;
  final Widget welcome;

  const InlineMessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    this.maxVisibleMessages = 5,
    required this.welcome,
  });

  @override
  State<InlineMessageList> createState() => _InlineMessageListState();
}

class _InlineMessageListState extends State<InlineMessageList> {
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Initialize scroll to bottom
    _lastMessageCount = widget.messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(covariant InlineMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to bottom if new messages are added
    if (widget.messages.length > _lastMessageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    _lastMessageCount = widget.messages.length;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      // Retry if controller isn't attached
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _scrollToBottom();
      });
      return;
    }

    // Scroll to max extent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
        // Optional: Use animateTo for smooth scrolling
        // _scrollController.animateTo(
        //   _scrollController.position.maxScrollExtent,
        //   duration: const Duration(milliseconds: 300),
        //   curve: Curves.easeOut,
        // );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Select the most recent messages
    final visibleMessages = widget.messages.length <= widget.maxVisibleMessages
        ? widget.messages
        : widget.messages.sublist(
      widget.messages.length - widget.maxVisibleMessages,
      widget.messages.length,
    );

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: visibleMessages.length + 1, // +1 for welcome widget
        itemBuilder: (context, index) {
          if (index == 0) {
            return widget.welcome;
          }
          final message = visibleMessages[index - 1];
          return _buildMessageItem(
            message,
            message.userId == widget.currentUserId,
            context,
          );
        },
      ),
    );
  }

  Widget _buildMessageItem(
      ChatMessage message, bool isCurrentUser, BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        width: MediaQuery.of(context).size.width * 0.6,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCurrentUser ? "You" : message.userName,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                decoration: TextDecoration.none,
                fontFamily: 'poppins',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.normal,
                fontSize: 14,
                decoration: TextDecoration.none,
                fontFamily: 'poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
