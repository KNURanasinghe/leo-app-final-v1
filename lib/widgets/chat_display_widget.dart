// import 'package:flutter/material.dart';
// import '../voiceRoom/inroom_message.dart';
// import 'chat_message_widget.dart';

// class ChatDisplayWidget extends StatelessWidget {
//   final List<ChatMessage> messages;
//   final ScrollController scrollController;
//   final String currentUserId;

//   const ChatDisplayWidget({
//     Key? key,
//     required this.messages,
//     required this.scrollController,
//     required this.currentUserId,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 300, // Adjust height as needed
//       child: messages.isEmpty
//           ? const Center(
//               child: Text(
//                 'No messages yet',
//                 style: TextStyle(color: Colors.white70),
//               ),
//             )
//           : ListView.builder(
//               controller: scrollController,
//               padding: const EdgeInsets.symmetric(vertical: 10),
//               itemCount: messages.length,
//               itemBuilder: (context, index) {
//                 final message = messages[index];
//                 return ChatMessageWidget(
//                   message: message,
//                   isCurrentUser: message.userId == currentUserId,
//                 );
//               },
//             ),
//     );
//   }
// }
