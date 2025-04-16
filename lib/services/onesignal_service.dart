// // Add this to your main.dart or app initialization code
// import 'package:onesignal_flutter/onesignal_flutter.dart';

// void initOneSignal() async {
//   // Initialize OneSignal
//   OneSignal.initialize(
//       "285b1b8b-9ba7-4696-a660-62f0dc1ca908"); // Your OneSignal App ID

//   // Enable debug logs
//   OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

//   // Request permission - updated API
//   final deviceState = await OneSignal.getDeviceState();
//   final bool userOptedInToNotifications =
//       deviceState?.hasNotificationPermission ?? false;

//   if (!userOptedInToNotifications) {
//     await OneSignal.Notifications.requestPermission(true);
//     print("Notification permission requested");
//   }

//   // Set notification handlers
//   OneSignal.Notifications.addForegroundWillDisplayListener((event) {
//     print(
//         "Notification received in foreground: ${event.notification.additionalData}");

//     // For calls, show the call screen immediately instead of a notification
//     if (event.notification.additionalData != null &&
//         event.notification.additionalData!['type'] == 'incoming_call') {
//       // Don't show the notification
//       event.preventDefault();

//       // Handle the call directly
//       handleIncomingCallNotification(event.notification);
//     }
//   });

//   // Set opened handler
//   OneSignal.Notifications.addClickListener((event) {
//     print("Notification clicked: ${event.notification.additionalData}");
//     handlePushNotificationOpened(event);
//   });

//   // Get the device state to access the player ID
//   final deviceState2 = await OneSignal.getDeviceState();
//   final playerId = deviceState2?.userId;

//   print("OneSignal Player ID: $playerId");

//   // Store this playerId to use with your socket service
//   if (playerId != null) {
//     // You'll need to call this when a user logs in
//     // socketService.setPlayerIdForNotifications(userId, playerId);
//   }
// }

// // Handle notification open
// void handlePushNotificationOpened(OSNotificationClickEvent event) {
//   try {
//     final data = event.notification.additionalData;
//     if (data == null) return;

//     final notificationType = data['type'];

//     if (notificationType == 'incoming_call') {
//       handleIncomingCallNotification(event.notification);
//     } else if (notificationType == 'missed_call') {
//       // Navigate to call history or show missed call info
//       navigateToCallHistory();
//     } else if (notificationType == 'chat_message') {
//       // Navigate to chat
//       final senderId = data['senderId'];
//       if (senderId != null) {
//         navigateToChat(senderId);
//       }
//     }
//   } catch (e) {
//     print("Error handling notification: $e");
//   }
// }

// // Handle incoming call notification
// void handleIncomingCallNotification(OSNotification notification) {
//   try {
//     final data = notification.additionalData;
//     if (data == null) return;

//     final callerId = data['callerId'];
//     final receiverId = data['receiverId'];
//     final callId = data['callId'];
//     final roomId = data['roomId'] ?? 'room_${receiverId}_${callerId}';
//     final isVideoCall = data['isVideoCall'] ?? false;

//     if (callerId == null || receiverId == null) {
//       print("Missing required call data");
//       return;
//     }

//     // Create call data in the format expected by your UI
//     final callData = {
//       'caller': callerId,
//       'target': receiverId,
//       'roomId': roomId,
//       'isVideoCall': isVideoCall,
//       'callId': callId,
//       'timestamp': DateTime.now().millisecondsSinceEpoch,
//     };

//     // Show incoming call screen
//     showIncomingCallScreen(callData);
//   } catch (e) {
//     print("Error handling call notification: $e");
//   }
// }

// // Add this to your SocketService class
// void setPlayerIdForNotifications(String userId, String playerId) async {
//   // Send the player ID to your server for notifications
//   _socket.emit('register_player_id', {'userId': userId, 'playerId': playerId});

//   // Also set it in OneSignal
//   await OneSignal.login(userId);

//   // Add tags if needed
//   OneSignal.User.addTags({"userId": userId});
// }

// // Placeholder navigation methods - implement these based on your app's navigation system
// void navigateToCallHistory() {
//   // TODO: Implement navigation to call history screen
// }

// void navigateToChat(String userId) {
//   // TODO: Implement navigation to chat with specific user
// }

// void showIncomingCallScreen(Map<String, dynamic> callData) {
//   // TODO: Implement showing the incoming call screen
//   // This should be implemented based on your app's UI system
//   // For example, using Get.to() or Navigator.push() to show the call screen
// }
