import 'package:flutter/material.dart';
import 'package:leo_app_01/Provider/call_history_provider.dart';
import 'package:leo_app_01/constants/app_constants.dart';
import 'package:leo_app_01/models/call_istory_model.dart';
import '../services/socket_service.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';
import 'package:tencent_calls_uikit/debug/generate_test_user_sig.dart';

class CallButtons extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final String name;
  final String image;

  const CallButtons({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.name,
    required this.image,
  });

  @override
  State<CallButtons> createState() => _CallButtonsState();
}

class _CallButtonsState extends State<CallButtons> {
  // Replace with your SDKAppID and SecretKey from Tencent Cloud console
  final int sdkAppID = 20021237; // TODO: Replace with your SDK App ID
  final String secretKey =
      "d4e7ab430a4755b8f58cf636a065b2aba9567a77a9db916689f811a87d418c23"; // TODO: Replace with your Secret Key

  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTUICallKit();
  }

  // Initialize TUICallKit with the current user
  Future<void> _initializeTUICallKit() async {
    if (!isInitialized) {
      // Import this if not already imported

      // Generate UserSig
      String userSig = GenerateTestUserSig.genTestSig(
          widget.currentUserId, sdkAppID, secretKey);

      // Login to TUICallKit
      TUIResult result = await TUICallKit.instance
          .login(sdkAppID, widget.currentUserId, userSig);

      if (result.code.isEmpty) {
        setState(() {
          isInitialized = true;
        });
        print('TUICallKit initialized for user: ${widget.currentUserId}');
      } else {
        print(
            'TUICallKit initialization failed: ${result.code} ${result.message}');
      }
    }
  }

  // Generate a unique room ID based on user IDs
  String _generateRoomId() {
    final sortedIds = [widget.currentUserId, widget.targetUserId]..sort();
    return 'room_${sortedIds[0]}_${sortedIds[1]}';
  }

  void _startCall(BuildContext context, bool isVideoCall) {
    final roomId = _generateRoomId();
    final SocketService socketService = SocketService();
    final callId = "call_${DateTime.now().millisecondsSinceEpoch}";
    CallHistoryService().addCall(CallHistoryEntry(
      callId: callId,
      callerId: widget.currentUserId,
      receiverId: widget.targetUserId,
      isOutgoing: true,
      isVideoCall: isVideoCall,
      isMissed: false, // We don't know yet if it will be missed
      timestamp: DateTime.now().millisecondsSinceEpoch,
      roomId: roomId,
    ));

    // ✨ ADD THIS: Save the history to storage
    CallHistoryService().saveHistory();
    // Check if user is online first
    socketService.debugCallFlow("START_CALL_ATTEMPT", {
      "caller": widget.currentUserId,
      "target": widget.targetUserId,
      "isVideoCall": isVideoCall
    });
    print("Initiating direct call to ${widget.targetUserId}");
    socketService.checkUserOnline(widget.targetUserId);

    // Set up online status callback
    Function originalOnlineStatusCallback =
        socketService.onUserStatus ?? (_) {};

    socketService.onUserStatus = (statusData) {
      originalOnlineStatusCallback(statusData);

      if (statusData['targetId'] == widget.targetUserId) {
        if (statusData['isOnline']) {
          _proceedWithCall(context, socketService, roomId, isVideoCall);
        } else {
          // Show user not available message
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("User is not available for a call right now")));
        }
      }
    };

    // Set up the call requested callback
    socketService.onCallRequested = (callData) {
      print("Call request sent: ${callData.toString()}");
      socketService.debugCallFlow("CALL_REQUESTED_RECEIVED", callData);

      if (callData['status'] == 'sent') {
        // Instead of navigating to VideoCallScreen, use Tencent UIKit to make a call
        _makeTencentCall(isVideoCall);
      } else if (callData['status'] == 'target_not_available') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("User is not available for a call right now")));
      }
    };

    // Signal call request to the other user
    socketService.requestCall(
        widget.currentUserId, widget.targetUserId, roomId, isVideoCall);
  }

  void _proceedWithCall(BuildContext context, SocketService socketService,
      String roomId, bool isVideoCall) {
    socketService.debugCallFlow("PROCEEDING_WITH_CALL", {
      "caller": widget.currentUserId,
      "target": widget.targetUserId,
      "room": roomId,
      "isVideoCall": isVideoCall
    });

    // Signal call request to the other user
    socketService.requestCall(
        widget.currentUserId, widget.targetUserId, roomId, isVideoCall);
  }

  // Make a call using Tencent UIKit
  void _makeTencentCall(bool isVideoCall) async {
    try {
      // Check if we're initialized and logged in
      print("Checking TUICallKit initialization and login state");

      // Re-login to ensure we're logged in
      String userSig = GenerateTestUserSig.genTestSig(
          widget.currentUserId, sdkAppID, secretKey);

      print("Re-logging in before making the call...");
      TUIResult loginResult = await TUICallKit.instance
          .login(sdkAppID, widget.currentUserId, userSig);

      if (loginResult.code.isNotEmpty) {
        print(
            "Login failed with code: ${loginResult.code}, message: ${loginResult.message}");
        return; // Don't proceed with the call if login fails
      }

      print("Successfully logged in, now making the call");

      // Determine media type based on isVideoCall
      TUICallMediaType mediaType =
          isVideoCall ? TUICallMediaType.video : TUICallMediaType.audio;

      await TUICallKit.instance.setSelfInfo(
        widget.name, // Your display name
        widget.image, // Your profile image URL
      );
      // Make the call using Tencent UIKit
      TUIResult callResult =
          await TUICallKit.instance.call(widget.targetUserId, mediaType);

      print(
          "Call result: code=${callResult.code}, message=${callResult.message}");
    } catch (e) {
      print("Exception in _makeTencentCall: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Audio call button
        IconButton(
          icon: const Icon(
            Icons.phone,
            color: AppConstants.iconColor,
          ),
          onPressed: () => _startCall(context, false),
          tooltip: 'Audio Call',
        ),
        // Video call button
        IconButton(
          icon: const Icon(
            Icons.videocam,
            color: AppConstants.iconColor,
          ),
          onPressed: () => _startCall(context, true),
          tooltip: 'Video Call',
        ),
      ],
    );
  }
}
