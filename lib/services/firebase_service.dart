// services/firebase_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:leo_app_01/services/rive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define your navigator key in a global scope - should match the one in main.dart
// If you already have a navigator key in main.dart, you can use that one
GlobalKey<NavigatorState>? globalNavigatorKey;

@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  // Handle background message here
  print('Handling a background message: ${message.messageId}');
  print('Title message: ${message.notification?.title}');
  print('Body message: ${message.notification?.body}');
  print('Payload message: ${message.data}');

  // For call notifications, we need to store them for handling when app opens
  if (message.data['type'] == 'call') {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_call_data', jsonEncode(message.data));
      print('Saved call data for when app opens: ${message.data}');
    } catch (e) {
      print('Error saving call data: $e');
    }
  }
}

class FirebaseService {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // API details for updating token on server
  final String _apiUrl = 'http://145.223.21.62:8090'; // Change to your API URL

  // Save the user ID for later use
  String? _userId;

  // Method to set the user ID when user logs in
  void setUserId(String userId) async {
    print('Setting user ID: $userId');
    _userId = userId;

    // Update token on server
    bool success = await updateUserFCMToken(userId);
    if (!success) {
      print('Failed to update FCM token, will retry later');
      // You could implement a retry mechanism here
    }
  }

  Future<void> initNotifications() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('User notification settings: ${settings.authorizationStatus}');

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get the token
    final fcmToken = await _firebaseMessaging.getToken();
    print('Firebase Messaging Token: $fcmToken');

    // Store token locally
    if (fcmToken != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', fcmToken);
    }

    // Update token on server if user is logged in
    if (_userId != null) {
      _updateTokenOnServer();
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed: $newToken');
      _updateTokenOnServer();
    });

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

    // Handle message when app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);

    // Handle message when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check for any pending call data when app starts
    await _checkPendingCallData();
  }

  Future<void> _initializeLocalNotifications() async {
    // Initialize settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize settings for iOS
    // const DarwinInitializationSettings initializationSettingsIOS =
    //     DarwinInitializationSettings(
    //   requestAlertPermission: true,
    //   requestBadgePermission: true,
    //   requestSoundPermission: true,
    // );

    // Initialize settings for both platforms
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      // iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        final payload = response.payload;
        if (payload != null) {
          try {
            final data = jsonDecode(payload);
            _handleNotificationTap(data);
          } catch (e) {
            print('Error parsing notification payload: $e');
          }
        }
      },
    );
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }

    // For calls, show a full-screen notification
    if (message.data['type'] == 'call') {
      await _showIncomingCallScreen(message.data);
    } else {
      // For normal chat messages, show a regular notification
      await _showLocalNotification(message);
    }
  }

  // Show a local notification for messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  // Handle initial message (app opened from terminated state)
  Future<void> _handleInitialMessage(RemoteMessage? message) async {
    if (message != null) {
      print('Handling initial message: ${message.data}');

      if (message.data['type'] == 'call') {
        // Wait for app to initialize before showing call screen
        await Future.delayed(const Duration(seconds: 1));
        await _showIncomingCallScreen(message.data);
      } else {
        _handleNotificationTap(message.data);
      }
    }
  }

  // Handle message opened app (app in background)
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.data}');

    if (message.data['type'] == 'call') {
      _showIncomingCallScreen(message.data);
    } else {
      _handleNotificationTap(message.data);
    }
  }

  // Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'];

    if (type == 'call') {
      _showIncomingCallScreen(data);
    } else if (type == 'chat_message') {
      // Navigate to chat screen
      if (globalNavigatorKey?.currentState != null) {
        // Add navigation to specific chat
        final senderId = data['senderId'];
        if (senderId != null) {
          // TODO: Navigate to chat screen with senderId
          // Example:
          // globalNavigatorKey?.currentState?.push(
          //   MaterialPageRoute(
          //     builder: (context) => ChatScreen(userId: senderId),
          //   ),
          // );
        }
      }
    }
  }

  // Show incoming call screen
  Future<void> _showIncomingCallScreen(Map<String, dynamic> callData) async {
    final callerId = callData['callerId'];
    final callerName = callData['callerName'] ?? 'Unknown Caller';
    final isVideoCall = callData['isVideoCall'] == 'true';
    final roomId = callData['roomId'];

    if (callerId == null || roomId == null) {
      print('Invalid call data received');
      return;
    }

    // Check if we can navigate
    if (globalNavigatorKey?.currentState != null) {
      // Show call screen
      // TODO: Implement your call screen here
      // Use your call screen implementation, example:
      // globalNavigatorKey?.currentState?.push(
      //   MaterialPageRoute(
      //     builder: (context) => IncomingCallScreen(
      //       callerId: callerId,
      //       callerName: callerName,
      //       isVideoCall: isVideoCall,
      //       roomId: roomId,
      //       onAccept: () => _acceptCall(callData),
      //       onDecline: () => _declineCall(callData),
      //     ),
      //   ),
      // );

      // For TENCENT_CALLS_UIKIT you can use:
      // Import your Tencent Calls UI Kit here
      // TUICallKit.instance.showCallWindow();

      print(
          'Would show call screen for caller: $callerName, roomId: $roomId, video: $isVideoCall');
    } else {
      print('Navigator not available for showing call screen');
      // Store call data for later handling
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_call_data', jsonEncode(callData));
    }
  }

  // Accept call
  Future<void> _acceptCall(Map<String, dynamic> callData) async {
    final callerId = callData['callerId'];
    final callId = callData['callId'];
    final roomId = callData['roomId'];

    // TODO: Implement your call acceptance logic here
    // Example: Connect to socket.io and emit accept_call event

    print('Accepting call from $callerId in room $roomId');

    // Clear pending call data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_call_data');
  }

  // Decline call
  Future<void> _declineCall(Map<String, dynamic> callData) async {
    final callerId = callData['callerId'];
    final callId = callData['callId'];

    // TODO: Implement your call decline logic here
    // Example: Connect to socket.io and emit reject_call event

    print('Declining call from $callerId');

    // Clear pending call data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_call_data');
  }

  // Check for pending call data when app starts
  Future<void> _checkPendingCallData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingCallDataStr = prefs.getString('pending_call_data');

      if (pendingCallDataStr != null) {
        final pendingCallData = jsonDecode(pendingCallDataStr);
        print('Found pending call data: $pendingCallData');

        // Check if call is still valid (not too old)
        final timestamp =
            int.tryParse(pendingCallData['timestamp'] ?? '0') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        // If call is less than 30 seconds old, show it
        if (now - timestamp < 30000) {
          await _showIncomingCallScreen(pendingCallData);
        } else {
          // Call is too old, clear it
          print('Pending call is too old, clearing');
          await prefs.remove('pending_call_data');
        }
      }
    } catch (e) {
      print('Error checking pending call data: $e');
    }
  }

  // Update FCM token on server
  Future<void> _updateTokenOnServer() async {
    if (_userId == null) {
      print('User ID not set, cannot update token on server');
      return;
    }

    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken == null) {
      print('FCM token is null, cannot update on server');
      return;
    }

    try {
      // Update user record with FCM token
      final response = await http.patch(
        Uri.parse('$_apiUrl/api/collections/users/records/$_userId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fcm_token': fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        print('FCM token updated on server successfully');
      } else {
        print(
            'Failed to update FCM token on server: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error updating FCM token on server: $e');
    }
  }

  Future<bool> updateUserFCMToken(String userId) async {
    try {
      // Get the current FCM token
      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken == null) {
        print('FCM token is null, cannot update on server');
        return false;
      }

      print('Updating FCM token for user $userId: $fcmToken');

      // Update user record with FCM token
      final response = await http.patch(
        Uri.parse('$_apiUrl/api/collections/users/records/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fcm_token': fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        print('FCM token updated on server successfully');

        // Store the updated user ID for future use
        _userId = userId;

        // Also store token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);

        return true;
      } else {
        print(
            'Failed to update FCM token on server: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating FCM token on server: $e');
      return false;
    }
  }
}
