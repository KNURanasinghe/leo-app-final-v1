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
  final bool showAudioOnly; // New parameter to show only audio button
  final bool showVideoOnly; // New parameter to show only video button

  const CallButtons({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.name,
    required this.image,
    this.showAudioOnly = false,
    this.showVideoOnly = false,
  });

  @override
  State<CallButtons> createState() => _CallButtonsState();
}

class _CallButtonsState extends State<CallButtons> {
  // Replace with your SDKAppID and SecretKey from Tencent Cloud console
  final int sdkAppID = 20024985;
  final String secretKey =
      "62ecfe8f93c06365c859dbaf7a0bb80b8e479b97755232137c5feaa32f1b677f";

  bool isInitialized = false;
  bool isInitializing = false;

  final Color kPrimaryColor = const Color(0xFF3DB6EB);

  @override
  void initState() {
    super.initState();
    _initializeTUICallKit();
  }

  // Initialize TUICallKit with the current user
  Future<void> _initializeTUICallKit() async {
    if (!isInitialized && !isInitializing) {
      setState(() => isInitializing = true);
      try {
        String userSig = GenerateTestUserSig.genTestSig(
            widget.currentUserId, sdkAppID, secretKey);

        print("Initializing TUICallKit...");
        TUIResult result = await TUICallKit.instance
            .login(sdkAppID, widget.currentUserId, userSig);
        print("Login result: ${result.code} - ${result.message}");

        if (result.code.isEmpty) {
          print("Setting self info after initialization...");

          print(
              "Setting self info after initialization... ${widget.name}, ${widget.image}");
          await TUICallKit.instance.setSelfInfo(widget.name, widget.image);
          setState(() {
            isInitialized = true;
            isInitializing = false;
          });
          print("TUICallKit initialized successfully!");
        } else {
          print("Initialization failed: ${result.code} - ${result.message}");
          setState(() => isInitializing = false);
        }
      } catch (e) {
        print("Initialization error: $e");
        setState(() => isInitializing = false);
      }
    }
  }

  // Generate a unique room ID based on user IDs
  String _generateRoomId() {
    final sortedIds = [widget.currentUserId, widget.targetUserId]..sort();
    return 'room_${sortedIds[0]}_${sortedIds[1]}';
  }

  // PUBLIC METHOD - Make this accessible from outside
  Future<void> startCall(BuildContext context, bool isVideoCall) async {
    await _startCall(context, isVideoCall);
  }

  Future<void> _startCall(BuildContext context, bool isVideoCall) async {
    // Show loading indicator
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Preparing call...")));

    // Wait for initialization if not already initialized
    if (!isInitialized) {
      await _initializeTUICallKit();
      if (!isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text("Failed to initialize call service. Please try again.")));
        return;
      }
    }

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

    // Save the history to storage
    CallHistoryService().saveHistory();

    // Check if user is online first
    socketService.debugCallFlow("START_CALL_ATTEMPT", {
      "caller": widget.currentUserId,
      "target": widget.targetUserId,
      "isVideoCall": isVideoCall
    });

    print("Initiating direct call to ${widget.targetUserId}");
    socketService.checkUserOnline(widget.targetUserId);

    // Set up online status callback with timeout
    Function originalOnlineStatusCallback =
        socketService.onUserStatus ?? (_) {};

    // Add timeout for status check
    bool receivedResponse = false;
    Future.delayed(const Duration(seconds: 2), () {
      if (!receivedResponse) {
        // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        //     content: Text("No response from server. Making direct call...")));
        _makeTencentCall(context, isVideoCall);
      }
    });

    socketService.onUserStatus = (statusData) {
      receivedResponse = true;
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
        // Use Tencent UIKit to make a call
        _makeTencentCall(context, isVideoCall);
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
  void _makeTencentCall(BuildContext context, bool isVideoCall) async {
    try {
      // Skip the re-login if already initialized
      if (!isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text("Call service not initialized. Initializing now...")));

        String userSig = GenerateTestUserSig.genTestSig(
            widget.currentUserId, sdkAppID, secretKey);

        print("Attempting login with fresh UserSig...");
        TUIResult loginResult = await TUICallKit.instance
            .login(sdkAppID, widget.currentUserId, userSig);

        print('Login result: ${loginResult.code} - ${loginResult.message}');
        if (loginResult.code.isNotEmpty) {
          print("Login failed: ${loginResult.code} - ${loginResult.message}");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text("Call initialization failed: ${loginResult.message}")));
          return;
        }

        print("Login successful, setting self info...");
        print(
            "Setting self info after initialization... ${widget.name}, ${widget.image}");
        await TUICallKit.instance.setSelfInfo(widget.name, widget.image);
        setState(() => isInitialized = true);
      }

      print("Making the call...");
      // Add explicit UI feedback that call is being initiated
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Initiating call...")));

      TUICallMediaType mediaType =
          isVideoCall ? TUICallMediaType.video : TUICallMediaType.audio;

      TUIResult callResult =
          await TUICallKit.instance.call(widget.targetUserId, mediaType);

      print("Call result: ${callResult.code} - ${callResult.message}");

      if (callResult.code.isNotEmpty) {
        print("Call failed: ${callResult.code} - ${callResult.message}");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Call failed: ${callResult.message}")));
      }
    } catch (e) {
      print("Exception in _makeTencentCall: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Call error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // If showAudioOnly is true, only show audio button
    if (widget.showAudioOnly) {
      return GestureDetector(
        onTap: isInitializing ? null : () => _startCall(context, false),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isInitializing ? Colors.grey : kPrimaryColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.phone,
            color: Colors.white,
            size: 20,
          ),
        ),
      );
    }

    // If showVideoOnly is true, only show video button
    if (widget.showVideoOnly) {
      return GestureDetector(
        onTap: isInitializing ? null : () => _startCall(context, true),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isInitializing ? Colors.grey : kPrimaryColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.videocam,
            color: Colors.white,
            size: 20,
          ),
        ),
      );
    }

    // Default: Show both buttons
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Audio call button
        IconButton(
          icon: const Icon(
            Icons.phone,
            color: AppConstants.iconColor,
          ),
          onPressed: isInitializing
              ? null // Disable button while initializing
              : () => _startCall(context, false),
          tooltip: 'Audio Call',
        ),
        // Video call button
        IconButton(
          icon: const Icon(
            Icons.videocam,
            color: AppConstants.iconColor,
          ),
          onPressed: isInitializing
              ? null // Disable button while initializing
              : () => _startCall(context, true),
          tooltip: 'Video Call',
        ),
      ],
    );
  }
}
