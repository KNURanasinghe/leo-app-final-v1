// Flutter imports:
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rive/rive.dart' as rive;
import '../services/rive_service.dart';
import './gift/gift.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_image_carousel_slider/image_carousel_slider.dart';
import 'dart:math' show pi, cos, sin;
import 'package:flutter_image_carousel_slider/image_carousel_slider_left_right_show.dart';
// Package imports:
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'memberlist.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'Ranking/roomRanking.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/services.dart';
import '../Account Section/edit profile/FriendsProfileView.dart';

// Project imports:
import 'constants.dart';
import 'media.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class UserData {
  final String id;
  final String name;
  final String avatarUrl;
  final String? borderUrl;
  final String? riveFileUrl;

  UserData({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.borderUrl,
    this.riveFileUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'borderUrl': borderUrl,
      'riveFileUrl': riveFileUrl,
    };
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      borderUrl: json['borderUrl'],
      riveFileUrl: json['riveFileUrl'],
    );
  }
}

// Add this class outside your LivePageState class
class EmojiLayoutDelegate extends MultiChildLayoutDelegate {
  final List<String> users;
  final int itemCount;

  EmojiLayoutDelegate({
    required this.users,
    required this.itemCount,
  });

  @override
  void performLayout(Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 3; // Show in upper third of screen
    const double radius = 100.0; // Radius of the circular arrangement

    for (int i = 0; i < users.length; i++) {
      if (hasChild(users[i])) {
        final double angle = (2 * pi * i) / itemCount;
        final double x = centerX + radius * cos(angle);
        final double y = centerY + radius * sin(angle);

        // Position each emoji
        final Size childSize =
            layoutChild(users[i], BoxConstraints.loose(size));
        positionChild(
          users[i],
          Offset(
            x - childSize.width / 2,
            y - childSize.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRelayout(EmojiLayoutDelegate oldDelegate) {
    return users != oldDelegate.users || itemCount != oldDelegate.itemCount;
  }
}

class OnlineUser {
  final String id;
  final String name;
  final String avatarUrl;
  final String motto;
  final String firstName;
  final String lastName;

  OnlineUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.motto,
    this.firstName = '',
    this.lastName = '',
  });
}

class LivePage extends StatefulWidget {
  final String roomID;
  final bool isHost;
  final LayoutMode layoutMode;
  final String username1;
  final String userId;

  const LivePage(
      {super.key,
      required this.roomID,
      this.layoutMode = LayoutMode.defaultLayout,
      this.isHost = false,
      required this.username1,
      required this.userId});

  static void handleLogout(BuildContext context) {
    print('Attempting to find LivePageState...'); // Debug log
    final LivePageState? state =
        context.findAncestorStateOfType<LivePageState>();
    if (state != null) {
      print('LivePageState found, calling _handleLogout'); // Debug log
      state._handleLogout();
    } else {
      print('LivePageState not found!'); // Debug log
      // If state not found, find the navigator and pop
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  State<StatefulWidget> createState() => LivePageState();
}

class LivePageState extends State<LivePage>
    with SingleTickerProviderStateMixin {
  bool _hasShownInitialEntry = false;
  DateTime? _lastEntryTime;
  final Map<String, DateTime> _userLastEntryTimes = {};

  final pb = PocketBase('http://145.223.21.62:8090');
  late UnsubscribeFunc? _unsubscribe;
  int userCount = 0; // Add this to track user count
  final Map<String, Timer> _emojiTimers = {};
  final Map<String, String> _currentEmojis = {};
  final Map<String, Offset> _seatPositions = {};
  final bool _showEmoji = false;
  Offset? _emojiPosition;
  String? _currentEmoji;
  final Map<String, Widget> _activeEmojis = {};
  String? _previousRoomId;
  String? _announcement;
  bool _showWelcomeMessage = true;
  final String _welcomeMessage =
      "Welcome to Hapi! Please respect each other and talk politely. Abusing, third-party advertising, fake official information and politically sensitive topics are strictly prohibited. please report if you find these situations";
  final Map<String, UserData> _userData = {};

  // Add this to your LivePageState class variables
  Map<String, String> _userRiveFiles = {};
  bool _loadingRiveFiles = false;

  final Map<String, DateTime> _activeAnimationSeats = {};

  late IO.Socket socket;
  bool isConnecting = true;
  bool isReconnecting = false;
  Timer? reconnectionTimer;
  int reconnectAttempts = 0;
  static const maxReconnectAttempts = 5;

  bool isAdmin = false;
  List<OnlineUser> onlineUsers = [];
  bool isLoadingUsers = false;
  bool _isMinimized = false;
  bool _showCopySuccess = false;
  DateTime? _lastTapTime;
  DateTime? _lastBottomSheetTime;
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  String? _onlineUserRecordId;
  String? _groupPhotoUrl;
  String? _userAvatarUrl;
  String? _voiceRoomName;
  String? _backgroundImageUrl;
  String? _language;
  int? _voiceroomid;
  static const String POCKETBASE_URL =
      'http://145.223.21.62:8090'; // Replace with your actual PocketBase URL
  bool _isLoading = false;
  Timer? _riveRefreshTimer;
  bool _hasShownInitialAnimation = false;
  bool _hasJoinedRoom = false;

  File? _selectedRoomPhoto;
  File? _selectedBackgroundImage;
  bool _isRoomUpdating = false;
  final Map<String, String> _userBorders = {};
  final Map<int, Map<String, dynamic>> _seatOccupants = {};
  // Method to handle room photo selection
  Future<void> _pickRoomPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedRoomPhoto = File(pickedFile.path);
      });

      // Preview the selected image
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Preview Room Photo'),
          content: Image.file(_selectedRoomPhoto!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateRoomPhoto();
              },
              child: const Text('Use This Photo'),
            ),
          ],
        ),
      );
    }
  }

  // Method to handle background image selection
  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedBackgroundImage = File(pickedFile.path);
      });

      // Preview the selected image
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Preview Background Image'),
          content: Image.file(_selectedBackgroundImage!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateBackgroundImage();
              },
              child: const Text('Use This Background'),
            ),
          ],
        ),
      );
    }
  }

  // Update room name
  Future<void> _updateRoomName(String newName) async {
    if (newName.isEmpty) return;

    setState(() {
      _isRoomUpdating = true;
    });

    try {
      final success = await HttpService.updateRoomSettings(
        roomId: widget.roomID,
        roomName: newName,
      );

      if (success) {
        // Update local state
        setState(() {
          _voiceRoomName = newName;
        });

        // Notify other users via socket
        socket.emit('roomSettingsUpdate', {
          'roomId': widget.roomID,
          'userId': widget.userId,
          'settings': {'type': 'name', 'value': newName}
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room name updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update room name')),
        );
      }
    } catch (e) {
      print('Error updating room name: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isRoomUpdating = false;
      });
    }
  }

  // Update room photo
  Future<void> _updateRoomPhoto() async {
    if (_selectedRoomPhoto == null) return;

    setState(() {
      _isRoomUpdating = true;
    });

    try {
      final success = await HttpService.updateRoomSettings(
        roomId: widget.roomID,
        roomPhoto: _selectedRoomPhoto,
      );

      if (success) {
        // Update local state with new photo URL
        await _fetchVoiceRoomDetails(); // Re-fetch details including new URL

        // Notify other users via socket
        socket.emit('roomSettingsUpdate', {
          'roomId': widget.roomID,
          'userId': widget.userId,
          'settings': {'type': 'photo', 'updated': true}
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room photo updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update room photo')),
        );
      }
    } catch (e) {
      print('Error updating room photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _selectedRoomPhoto = null;
        _isRoomUpdating = false;
      });
    }
  }

  // Update background image
  Future<void> _updateBackgroundImage() async {
    if (_selectedBackgroundImage == null) return;

    setState(() {
      _isRoomUpdating = true;
    });

    try {
      final success = await HttpService.updateRoomSettings(
        roomId: widget.roomID,
        backgroundImage: _selectedBackgroundImage,
      );

      if (success) {
        // Update local state with new background URL
        await _fetchVoiceRoomDetails(); // Re-fetch details including new URL

        // Notify other users via socket
        socket.emit('roomSettingsUpdate', {
          'roomId': widget.roomID,
          'userId': widget.userId,
          'settings': {'type': 'background', 'updated': true}
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Background image updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update background image')),
        );
      }
    } catch (e) {
      print('Error updating background image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _selectedBackgroundImage = null;
        _isRoomUpdating = false;
      });
    }
  }

  Future<void> _loadUserBorders() async {
    try {
      // Request all borders from the socket server
      socket.emit('fetchUserBorders', {'roomId': widget.roomID});

      print('BORDER DEBUG: Requested user borders from server');

      // Additionally, fetch your own border directly
      await _fetchOwnBorder();

      // Log current border state
      _debugBorderState();

      // Fetch borders for all visible users directly via HTTP as a backup
      // final zegoUsers = ZegoUIKit().getUser().allUsers;
      // for (final user in zegoUsers) {
      //   // Skip if we already have this user's border
      //   if (_userBorders.containsKey(_normalizeUserId(user.id))) continue;

      //   _forceFetchBorder(_normalizeUserId(user.id));
      // }
    } catch (e) {
      print('Error loading user borders: $e');
    }
  }

  // Add a method to notify border change (to broadcast to others)
  // Helper to notify border change (to broadcast to others)
  void _notifyBorderChange(String borderUrl) {
    if (socket.connected) {
      print('BORDER DEBUG: Notifying border change: $borderUrl');
      socket.emit('borderChange', {
        'roomId': widget.roomID,
        'userId': widget.userId,
        'userName': widget.username1,
        'borderUrl': borderUrl
      });

      // Update local state
      setState(() {
        _userBorders[widget.userId] = borderUrl;

        // Also store with normalized ID
        final normalizedId = _normalizeUserId(widget.userId);
        if (normalizedId != widget.userId) {
          _userBorders[normalizedId] = borderUrl;
        }
      });
    } else {
      print('BORDER DEBUG: Socket not connected, cannot notify border change');
    }
  }

  Future<String?> _fetchOwnBorder() async {
    try {
      print('BORDER DEBUG: Fetching own border for user ${widget.userId}');

      final response = await http.get(
        Uri.parse('$POCKETBASE_URL/api/collections/myItems/records')
            .replace(queryParameters: {
          'filter': 'userId="${widget.userId}" && isborder_used=true',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = List<Map<String, dynamic>>.from(data['items']);

        if (items.isNotEmpty && items[0]['border'] != null) {
          final item = items[0];
          final borderUrl =
              '$POCKETBASE_URL/api/files/myItems/${item['id']}/${item['border']}';

          print('BORDER DEBUG: Found own border: $borderUrl');

          // Update local state
          setState(() {
            _userBorders[widget.userId] = borderUrl;

            // Also store with normalized ID to ensure it's found
            final normalizedId = _normalizeUserId(widget.userId);
            if (normalizedId != widget.userId) {
              _userBorders[normalizedId] = borderUrl;
            }
          });

          // Notify others about our border
          if (socket.connected) {
            socket.emit('borderChange', {
              'roomId': widget.roomID,
              'userId': widget.userId,
              'borderUrl': borderUrl
            });
            print('BORDER DEBUG: Notified others about our border');
          }

          return borderUrl;
        } else {
          print('BORDER DEBUG: No active border found for own user');
        }
      } else {
        print(
            'BORDER DEBUG: Failed to fetch own border: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error fetching own border: $e');
      return null;
    }
  }

  void _debugBorderState() {
    print('\n===== BORDER DEBUG INFO =====');
    print('Total borders tracked: ${_userBorders.length}');

    if (_userBorders.isEmpty) {
      print('No borders are currently tracked');
    } else {
      print('Borders by user:');
      _userBorders.forEach((userId, url) {
        print('User $userId: $url');
      });
    }

    // final zegoUsers = ZegoUIKit().getUser().allUsers;
    // print('\nCurrently visible Zego users (${zegoUsers.length}):');
    // for (final user in zegoUsers) {
    //   final hasBorder = _userBorders.containsKey(_normalizeUserId(user.id));
    //   print('User ${user.id} (${user.name}): ${hasBorder ? "Has border" : "No border"}');
    // }

    print('===== END BORDER DEBUG INFO =====\n');
  }

  // Add this method to manually fetch and set border for a specific user
  Future<void> _forceFetchBorder(String userId) async {
    try {
      print('BORDER DEBUG: Manually fetching border for user: $userId');

      final response = await http.get(
        Uri.parse('$POCKETBASE_URL/api/collections/myItems/records')
            .replace(queryParameters: {
          'filter': 'userId="$userId" AND isborder_used=true',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = List<Map<String, dynamic>>.from(data['items']);

        if (items.isNotEmpty && items[0]['border'] != null) {
          final item = items[0];
          final borderUrl =
              '$POCKETBASE_URL/api/files/myItems/${item['id']}/${item['border']}';

          print('BORDER DEBUG: Found border for user $userId: $borderUrl');

          // Update local state with both original and normalized IDs
          setState(() {
            _userBorders[userId] = borderUrl;

            // Also store with normalized ID to ensure it's found
            final normalizedId = _normalizeUserId(userId);
            if (normalizedId != userId) {
              _userBorders[normalizedId] = borderUrl;
            }
          });

          // Force UI refresh
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() {});
          });

          return;
        }

        print('BORDER DEBUG: No active border found for user $userId');
      } else {
        print('BORDER DEBUG: Failed to fetch border: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _forceFetchBorder: $e');
    }
  }

// 6. Add a method to force show an animation regardless of socket state:
  void _forceShowAnimation(String userId, String riveFileUrl) {
    // Cancel any existing timer
    _emojiTimers[userId]?.cancel();

    // Show the animation locally
    safeSetState(() {
      _activeAnimationSeats[userId] = DateTime.now();
      _userRiveFiles[userId] = riveFileUrl;
      _persistentRiveFiles[userId] = riveFileUrl;
    });

    // Auto-remove after 10 seconds
    _emojiTimers[userId] = Timer(const Duration(seconds: 10), () {
      safeSetState(() {
        _activeAnimationSeats.remove(userId);
      });
    });
  }

// 8. Add a declaration for the persistent Rive files map:
  Map<String, String> _persistentRiveFiles = {};
  @override
  void initState() {
    super.initState();
    _initializeSocket();
    _fetchOwnBorder();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_hasShownInitialAnimation) {
        _fetchOwnRiveFile().then((url) {
          if (url != null) {
            _forceShowAnimation(widget.userId, url);
            _hasShownInitialAnimation = true;
          }
        });
      }
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _debugBorderState();
        _forceFetchBorder(widget.userId);

        // Try to force fetch borders for all visible users
        // final zegoUsers = ZegoUIKit().getUser().allUsers;
        // for (final user in zegoUsers) {
        //   if (user.id != widget.userId) {
        //     _forceFetchBorder(user.id);
        //   }
        // }
      }
    });

    // Add periodic border debugging
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _debugBorderState();
      }
    });
    // Fetch borders periodically
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && socket.connected) {
        _loadUserBorders();
      }
    });
    print(
        'ROOM_CHANGE: initState - _previousRoomId: $_previousRoomId, current roomID: ${widget.roomID}');
    print(
        'ROOM_CHANGE: Room change detected? ${_previousRoomId != null && _previousRoomId != widget.roomID}');
    _hasJoinedRoom = false;
    _hasShownInitialEntry = false;
    final isRoomChange =
        _previousRoomId != null && _previousRoomId != widget.roomID;

    if (isRoomChange) {
      print('Room change detected: from $_previousRoomId to ${widget.roomID}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerRoomEntryAnimation();
      });
    }

    // Sync animations every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && socket.connected) {
        _syncRiveAnimations();
      }
    });

    _resetAnimationState();
    _hasShownInitialAnimation = false;
    _fetchOwnRiveFile().then((riveFileUrl) {
      print('room id from init -${widget.roomID}');
      // Only trigger entry animation when joining a room for the first time
      if (socket.connected) {
        socket.emit('joinRoom', {
          'roomId': widget.roomID,
          'userId': widget.userId,
          'userName': widget.username1,
          'userAvatar': _userAvatarUrl,
          'riveFileUrl': _userRiveFiles[widget.userId], // Include Rive URL
          'forceEntry': true,
        });
        _hasShownInitialAnimation = true;
        _fetchInitialUsers();
        _loadUserRiveFiles();
      }
    });
    // Add this to your initState
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _userRiveFiles.containsKey(widget.userId)) {
        // Resend our animation periodically
        _notifyRiveAnimationChange(_userRiveFiles[widget.userId]!);
      }
    });
    // Add this after socket initialization
    socket.on('riveAnimationChange', (data) {
      if (!mounted) return;

      final userId = data['userId'];
      final riveFileUrl = data['riveFileUrl'];

      print('Received riveAnimationChange: $userId - $riveFileUrl');

      if (userId != null && riveFileUrl != null) {
        setState(() {
          _userRiveFiles[userId] = riveFileUrl;
        });

        // Force UI refresh
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() {});
        });
      }
    });

    print('RIVE DEBUG: My user ID: ${widget.userId}');
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _dumpRiveFilesMap();
      }
    });
    print('RIVE DEBUG: My local user ID: $localUserID');
    _riveRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _loadUserRiveFiles();
      }
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showWelcomeMessage = false;
        });
      }
    });

    socket.on('gifReaction', (data) {
      print('Received emoji data: $data'); // Debug log

      if (mounted) {
        setState(() {
          _activeEmojis[data['userId']] = SizedBox(
            width: 50,
            height: 50,
            child: Image.asset(
              'assets/smile.gif',
              fit: BoxFit.cover,
            ),
          );
        });
        // Remove after 2 seconds
        _emojiTimers[data['userId']]?.cancel();
        _emojiTimers[data['userId']] = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _activeEmojis.remove(data['userId']);
            });
          }
        });
      }
    });

    //_createOnlineUserRecord().then((_) => _fetchInitialUsers());
    _checkAdminStatus();
    _fetchOnlineUsers();
    // ZegoGiftManager().cache.cacheAllFiles(giftItemList);
    // ZegoGiftManager().service.recvNotifier.addListener(onGiftReceived);
    _fetchAndSetUserAvatar();
    _fetchVoiceRoomDetails();
    _createOnlineUserRecord();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ZegoGiftManager().service.init(
            appID: 2069292420,
            liveID: widget.roomID,
            localUserID: localUserID,
            localUserName: widget.username1,
          );

      print("------------------------------------------");
      print(localUserID);
      // Fetch avatar URL when component mounts
      updateStartTime(widget.userId, widget.roomID);

      _fetchLanguageDetails(widget.roomID);
    });

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
      lowerBound: 0.5,
      upperBound: 1.2,
    )..repeat(reverse: true);
    //
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(_controller);
    //
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   // Get crown gift data
    //   final crownGift = giftItemList.firstWhere(
    //           (gift) => gift.name == 'crown',  // Adjust name to match your gift
    //       orElse: () => giftItemList.first
    //   );
    //
    //   // Auto play the gift
    //   ZegoGiftManager().playList.add(PlayData(
    //       giftItem: crownGift,
    //       count: 1
    //   ));
    // });
    socket.on('roomSettingsUpdated', (data) {
      if (!mounted) return;

      final settings = data['settings'];
      final type = settings['type'];

      switch (type) {
        case 'name':
          setState(() {
            _voiceRoomName = settings['value'];
          });
          break;

        case 'photo':
        case 'background':
          // Re-fetch room details to get updated URLs
          _fetchVoiceRoomDetails();
          break;
      }

      // Show notification of the update
      if (data['updatedBy'] != widget.userId) {
        final message = type == 'name'
            ? 'Room name has been updated'
            : type == 'photo'
                ? 'Room photo has been updated'
                : 'Room background has been updated';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  void _notifyRoomChange(String oldRoomId, String newRoomId) {
    if (socket.connected) {
      socket.emit('roomChange', {
        'userId': widget.userId,
        'userName': widget.username1,
        'oldRoomId': oldRoomId,
        'newRoomId': newRoomId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Force local UI update
      _triggerRoomEntryAnimation();
    }
  }

  void _syncRiveAnimations() {
    final animations = <String, String>{};
    _userRiveFiles.forEach((userId, url) {
      if (url.isNotEmpty) {
        animations[userId] = url;
      }
    });

    socket.emit('syncRiveAnimations',
        {'roomId': widget.roomID, 'animations': animations});
  }

  void _resetAnimationState() {
    // Cancel all existing timers
    _emojiTimers.forEach((key, timer) => timer.cancel());
    _emojiTimers.clear();

    // Clear active animations
    setState(() {
      _activeAnimationSeats.clear();
    });
  }

  // Add this debug helper method
  void _dumpRiveFilesMap() {
    print('==== RIVE FILES MAP DUMP ====');
    print('Total entries: ${_userRiveFiles.length}');
    _userRiveFiles.forEach((userId, url) {
      print('User $userId: $url');
    });
    print('===========================');
  }

  // Add this helper method to your LivePageState class to normalize user IDs
  String _normalizeUserId(String userId) {
    // Remove any prefixes/suffixes that might be added by Zego
    return userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  // Add this after fetching your own Rive file
  Future<String?> _fetchOwnRiveFile() async {
    try {
      print('RIVE DEBUG: About to fetch own Rive file');
      final riveFileUrl =
          await HttpService.getUserActiveRiveFile(widget.userId);
      print('Fetched own Rive file URL: $riveFileUrl');

      if (riveFileUrl != null && mounted) {
        print('RIVE DEBUG: Setting own Rive file in map');
        setState(() {
          _userRiveFiles[widget.userId] = riveFileUrl;
        });

        // Always trigger entry animation when we have a Rive file
        // We will rely on room transitions to control when to show it
        if (socket.connected) {
          // IMPORTANT: Always call this for entry animation
          _handleEntryAnimation(riveFileUrl);
        }

        return riveFileUrl;
      }
    } catch (e) {
      print('Error fetching own Rive file: $e');
    }
    return null;
  }

  void _triggerRoomEntryAnimation() {
    print('ROOM_CHANGE: Triggering room entry animation');

    // Make sure we have our Rive file URL
    String? riveFileUrl =
        _userRiveFiles[widget.userId] ?? _persistentRiveFiles[widget.userId];

    if (riveFileUrl == null || riveFileUrl.isEmpty) {
      // Try to fetch it if we don't have it yet
      _fetchOwnRiveFile().then((url) {
        if (url != null && url.isNotEmpty && mounted) {
          _forceRoomEntryAnimation(url);
        }
      });
    } else {
      _forceRoomEntryAnimation(riveFileUrl);
    }
  }

  void _forceRoomEntryAnimation(String riveFileUrl) {
    print('ROOM_CHANGE: In _forceRoomEntryAnimation');
    print('ROOM_CHANGE: Setting active animation for ${widget.userId}');
    print(
        'ROOM_CHANGE: Emitting socket event userEntryAnimation with isRoomChange=true');

    print('Forcing room entry animation for ${widget.userId}');

    // Update local state to show animation
    setState(() {
      _activeAnimationSeats[widget.userId] = DateTime.now();
    });

    // Tell the server this is specifically a room change animation
    if (socket.connected) {
      socket.emit('userEntryAnimation', {
        'roomId': widget.roomID,
        'userId': widget.userId,
        'userName': widget.username1,
        'riveFileUrl': riveFileUrl,
        'isEntry': true,
        'isRoomChange': true, // Add a specific flag for room changes
        'duration': 10000,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // Auto-remove after 10 seconds
    _emojiTimers[widget.userId] = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _activeAnimationSeats.remove(widget.userId);
        });
      }
    });
  }

  void _initializeRiveFiles() {
    // Store a persistent copy after loading
    _persistentRiveFiles = Map<String, String>.from(_userRiveFiles);

    // Set up a timer to refresh Rive files and check consistency
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _checkAndRestoreRiveFiles();
      }
    });
  }

  void _checkAndRestoreRiveFiles() {
    // Restore any files that were accidentally cleared
    if (_userRiveFiles.isEmpty && _persistentRiveFiles.isNotEmpty) {
      safeSetState(() {
        _userRiveFiles = Map<String, String>.from(_persistentRiveFiles);
      });
    }

    // Ensure current user's Rive file is always present
    if (!_userRiveFiles.containsKey(widget.userId) &&
        _persistentRiveFiles.containsKey(widget.userId)) {
      safeSetState(() {
        _userRiveFiles[widget.userId] = _persistentRiveFiles[widget.userId]!;
      });
    }
  }

  void _handleEntryAnimation(String? riveFileUrl, {bool isReconnect = false}) {
    if (riveFileUrl == null || riveFileUrl.isEmpty) return;

    _emojiTimers[widget.userId]?.cancel();
    print('Triggering entry animation for ${widget.userId}');

    // Update last entry time
    _lastEntryTime = DateTime.now();

    // Update local state with safety check
    safeSetState(() {
      _userRiveFiles[widget.userId] = riveFileUrl;
      _persistentRiveFiles[widget.userId] =
          riveFileUrl; // Store in persistent map
      _activeAnimationSeats[widget.userId] = DateTime.now();
    });

    // Broadcast to server only if connected
    if (socket.connected) {
      print('Broadcasting entry animation for ${widget.userId}');
      print('room id ${widget.roomID}');
      socket.emit('userEntryAnimation', {
        'roomId': widget.roomID,
        'userId': widget.userId,
        'userName': widget.username1,
        'riveFileUrl': riveFileUrl,
        'isEntry': true,
        'isReconnect': isReconnect,
        'duration': 10000,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // Remove after 10 seconds, with safety check
    _emojiTimers[widget.userId]?.cancel(); // Cancel any existing timer
    _emojiTimers[widget.userId] = Timer(const Duration(seconds: 10), () {
      safeSetState(() {
        _activeAnimationSeats.remove(widget.userId);
      });
    });
  }

  void _resetRoomState() {
    _hasJoinedRoom = false;
    _hasShownInitialEntry = false;
    _lastEntryTime = null;
    _resetAnimationState();
  }

// Add this to your LivePageState class
  void _handleSeatTaken(String userId, int seatIndex) {
    if (socket.connected) {
      // Get the user details from your existing data
      final userAvatar = _findUserAvatar(userId);
      final userBorder = _userBorders[userId];
      final userName = _findUserName(userId);

      // Emit the seat taken event
      socket.emit('seatTaken', {
        'roomId': widget.roomID,
        'userId': userId,
        'seatIndex': seatIndex,
        'userAvatar': userAvatar,
        'userName': userName,
        'borderUrl': userBorder
      });

      print('Emitted seatTaken event for user $userId in seat $seatIndex');
    }
  }

// Helper method to find a user's avatar URL
  String? _findUserAvatar(String userId) {
    // First check online users
    for (final user in onlineUsers) {
      if (user.id == userId) {
        return user.avatarUrl;
      }
    }

    // If current user
    if (userId == widget.userId) {
      return _userAvatarUrl;
    }

    return null;
  }

  Future<void> _loadUserRiveFiles() async {
    if (_loadingRiveFiles) return;

    setState(() {
      _loadingRiveFiles = true;
    });

    try {
      final riveFiles = await HttpService.fetchUsersRiveFiles(widget.roomID);

      setState(() {
        _userRiveFiles.clear();
        _userRiveFiles.addAll(riveFiles);
        _loadingRiveFiles = false;
      });

      logDebug('Loaded rive files for ${_userRiveFiles.length} users');
    } catch (e) {
      setState(() {
        _loadingRiveFiles = false;
      });
      print('Error loading user rive files: $e');
    }
  }

  // Helper method for logging
  void logDebug(String message) {
    print('[RIVE DEBUG] $message');
  }

  // 3. Add a method to update the announcement
  Future<void> _updateAnnouncement(String roomId, String announcement) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await http.patch(
        Uri.parse('$POCKETBASE_URL/api/collections/voiceRooms/records/$roomId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'announcement': announcement,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _announcement = announcement;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement updated successfully')),
          );
        }
      } else {
        print('Failed to update announcement: ${response.statusCode}');
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update announcement')),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error updating announcement: $e');
      setState(() {
        _isLoading = false;
      });

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // 4. Add a method to show announcement edit dialog
  void _showAnnouncementDialog(BuildContext context) {
    final TextEditingController announcementController =
        TextEditingController(text: _announcement ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.black.withOpacity(0.9),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Room Announcement',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: announcementController,
                  decoration: InputDecoration(
                    hintText: 'Enter room announcement',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 5,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateAnnouncement(
                            widget.roomID, announcementController.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 5. Add welcome and announcement widgets to the build method
  Widget _buildWelcomeAndAnnouncement() {
    // Calculate the position based on welcome message visibility
    double bottomPosition = _showWelcomeMessage
        ? MediaQuery.of(context).size.height *
            0.3 // Original position when welcome is visible
        : MediaQuery.of(context).size.height * 0.3 +
            16; // Move up when welcome is hidden

    return Positioned(
      bottom: bottomPosition,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message (visible for 5 seconds)
          if (_showWelcomeMessage)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.waving_hand,
                        color: Colors.lightGreen,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Welcome!',
                        style: TextStyle(
                          color: Colors.lightGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showWelcomeMessage = false;
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _welcomeMessage,
                    style: const TextStyle(
                      color: Colors.lightGreen,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),

          // Only add spacing if welcome message is visible
          if (_showWelcomeMessage) const SizedBox(height: 16),

          // Announcement - always shown but position depends on welcome message visibility
          if (_announcement != null && _announcement!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.campaign,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Announcement',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Spacer(),
                      if (isAdmin)
                        GestureDetector(
                          onTap: () {
                            _showAnnouncementDialog(context);
                          },
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _announcement!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _checkAdminStatus() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$POCKETBASE_URL/api/collections/voiceRooms/records/${widget.roomID}'),
      );

      if (response.statusCode == 200) {
        final roomData = json.decode(response.body);
        setState(() {
          isAdmin = roomData['ownerId'] == widget.userId;
        });
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  Future<void> _disbandGroup() async {
    try {
      // First, remove all joined users
      final joinedUsersResponse = await http.get(
        Uri.parse(
            '$POCKETBASE_URL/api/collections/joined_users/records?filter=(voice_room_id="${widget.roomID}")'),
      );

      if (joinedUsersResponse.statusCode == 200) {
        final joinedUsers =
            json.decode(joinedUsersResponse.body)['items'] as List;

        // Delete all joined user records
        for (var user in joinedUsers) {
          await http.delete(
            Uri.parse(
                '$POCKETBASE_URL/api/collections/joined_users/records/${user['id']}'),
          );
        }
      }

      // First, clean up all duplicate records
      await _deleteDuplicateOnlineUserRecords(widget.userId, widget.roomID);

      // Uninitialize ZEGO services
      ZegoGiftManager().service.uninit();
      await ZegoUIKit().leaveRoom();

      // Emit leave room event to socket
      socket.emit('leaveRoom', {
        'roomId': widget.roomID,
        'userId': widget.userId,
      });

      // Update end time for the session
      await updateEndTime(widget.userId, widget.roomID);

      // Disconnect socket
      socket.disconnect();

      // Then, delete the voice room
      final deleteResponse = await http.delete(
        Uri.parse(
            '$POCKETBASE_URL/api/collections/voiceRooms/records/${widget.roomID}'),
      );

      _handleLogout();

      //
      // // Finally, navigate back
      //
      //   Navigator.of(context).pop(); // Close current screen
      //   Navigator.of(context).pop(); // Pop back to groups screen
      //
      //   // Show success message
      //   if (context.mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: Text('Group disbanded successfully'),
      //         backgroundColor: Colors.green,
      //       ),
      //     );
      //   }
    } catch (e) {
      print('Error disbanding group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to disband group')),
        );
      }
    }
  }

  void _initializeSocket() {
    socket = IO.io('http://145.223.21.62:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
      'reconnectionAttempts': 5,
    });

    socket.onConnect((_) async {
      print('ROOM_CHANGE: Socket connected, checking for room change');
      print(
          'ROOM_CHANGE: previousRoomId=$_previousRoomId, currentRoomId=${widget.roomID}');
      print('Connected to Socket.IO server');

      // Reset connection state
      reconnectAttempts = 0;
      isReconnecting = false;

      if (mounted) {
        setState(() => isConnecting = false);
      }

      // Periodically refresh border data
      Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted && socket.connected) {
          _loadUserBorders();
        }
      });
      // Always fetch fresh Rive file on connection
      await _fetchOwnRiveFile();
      print('Fetched own 12: ${widget.roomID}');
      // Join room with forceEntry flag if it's a fresh connection
      if (!_hasShownInitialAnimation) {
        socket.emit('joinRoom', {
          'roomId': widget.roomID,
          'userId': widget.userId,
          'userName': widget.username1,
          'userAvatar': _userAvatarUrl,
          'riveFileUrl': _userRiveFiles[widget.userId],
          'forceEntry': true,
          'isRoomChange':
              _previousRoomId != null && _previousRoomId != widget.roomID,
        });
        _hasShownInitialAnimation = true;
      }
      _previousRoomId = widget.roomID;
      _hasShownInitialEntry = true;

      // Rest of your connection logic...

      // After joining the room, THEN fetch own Rive file
      await _fetchOwnRiveFile();
      _fetchInitialUsers();
      _loadUserRiveFiles();
      // Fetch your own Rive file URL
      String? riveFileUrl = _userRiveFiles[widget.userId];

      if (riveFileUrl != null) {
        print('RIVE DEBUG: Found active user Rive animation: $riveFileUrl');

        _handleEntryAnimation(riveFileUrl);
      }
      // Add this in your socket initialization
      socket.on('roomChange', (data) {
        if (!mounted) return;

        final userId = data['userId'];
        final oldRoomId = data['oldRoomId'];
        final newRoomId = data['newRoomId'];

        print('User $userId changed rooms from $oldRoomId to $newRoomId');

        // If this room is the new room, show the animation
        if (newRoomId == widget.roomID) {
          _fetchUserRiveFile(userId).then((riveFileUrl) {
            setState(() {
              _activeAnimationSeats[userId] = DateTime.now();
            });

            // Auto-remove after 10 seconds
            _emojiTimers[userId] = Timer(const Duration(seconds: 10), () {
              if (mounted) {
                setState(() {
                  _activeAnimationSeats.remove(userId);
                });
              }
            });
          });
        }
      });

// Add this in your _initializeSocket method
      socket.on('seatTaken', (data) {
        if (!mounted) return;

        final userId = data['userId'];
        final seatIndex = data['seatIndex'];
        final userAvatar = data['userAvatar'];
        final userName = data['userName'];
        final borderUrl = data['borderUrl'];

        setState(() {
          // Store this info in a map to track which user is in which seat
          _seatOccupants[seatIndex] = {
            'userId': userId,
            'userAvatar': userAvatar,
            'userName': userName,
            'borderUrl': borderUrl
          };
        });

        print('User $userId took seat $seatIndex');
      });

      // Add this in your socket initialization (in _initializeSocket method)
      socket.on('userBorders', (data) {
        if (!mounted) return;

        print('Received user borders: $data');
        if (data is Map) {
          setState(() {
            data.forEach((userId, borderUrl) {
              if (userId != null && borderUrl != null) {
                final normalizedId = _normalizeUserId(userId.toString());
                _userBorders[normalizedId] = borderUrl.toString();
                print('Added border for user $userId: $borderUrl');
              }
            });
          });

          // Force UI refresh
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() {});
          });
        }
      });

      // In your socket initialization
      socket.on('borderChange', (data) {
        if (!mounted) return;

        final userId = data['userId']?.toString();
        final borderUrl = data['borderUrl']?.toString();

        print('Received borderChange: $userId - $borderUrl');

        if (userId != null && borderUrl != null) {
          final normalizedId = _normalizeUserId(userId);
          setState(() {
            _userBorders[normalizedId] = borderUrl;
          });

          // Force UI refresh
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() {});
          });
        }
      });

      // In your socket.onConnect handler:
      socket.on('userEntryAnimation', (data) {
        if (!mounted) return;

        final userId = data['userId'];
        final riveFileUrl = data['riveFileUrl'];
        final isRoomChange = data['isRoomChange'] ?? false;

        print('ROOM_CHANGE: Received userEntryAnimation event');
        print(
            'ROOM_CHANGE: userId: $userId, isRoomChange: ${data['isRoomChange']}');
        print(
            'Received userEntryAnimation: $userId, isRoomChange: $isRoomChange');

        if (userId != null && riveFileUrl != null) {
          safeSetState(() {
            _activeAnimationSeats[userId] = DateTime.now();
            _userRiveFiles[userId] = riveFileUrl;
          });
        }

        // Set timer to remove animation
        _emojiTimers[userId]?.cancel(); // Cancel any existing timer
        _emojiTimers[userId] = Timer(const Duration(seconds: 10), () {
          safeSetState(() {
            _activeAnimationSeats.remove(userId);
          });
        });
      });

      socket.emit('fetchUserBorders', {'roomId': widget.roomID});
      socket.emit('fetchUserRiveFiles', {'roomId': widget.roomID});
      await _fetchOwnBorder();
      // Also broadcast your own Rive file to ensure everyone has it
      if (riveFileUrl != null) {
        // Use entry animation for first join
        _handleEntryAnimation(riveFileUrl);
      }
    });

    socket.onConnectError((error) {
      print('Socket connection error: $error');
    });

    socket.onError((error) {
      print('Socket error: $error');
    });

    // Better handler for receiving all Rive files at once
    socket.on('userRiveFiles', (data) {
      print('Received user Rive files: $data');
      if (data is Map) {
        if (mounted) {
          setState(() {
            data.forEach((userId, riveFileUrl) {
              if (userId != null && riveFileUrl != null) {
                // Store with both original and normalized ID to ensure we catch it
                final normalizedId = _normalizeUserId(userId.toString());
                _userRiveFiles[userId.toString()] = riveFileUrl.toString();
                if (normalizedId != userId.toString()) {
                  _userRiveFiles[normalizedId] = riveFileUrl.toString();
                }
                print('Added Rive file for user $userId: $riveFileUrl');
              }
            });
          });

          // Force UI refresh after updating data
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {});
              _dumpRiveFilesMap(); // Debug dump after update
            }
          });
        }
      }
    });

    // Improve riveAnimationChange handler
    socket.on('riveAnimationChange', (data) {
      if (!mounted) return;

      final userId = data['userId'];
      final riveFileUrl = data['riveFileUrl'];

      print('Received riveAnimationChange: $userId - $riveFileUrl');

      if (userId != null && riveFileUrl != null) {
        final normalizedId = _normalizeUserId(userId.toString());
        setState(() {
          _userRiveFiles[normalizedId] = riveFileUrl.toString();
        });
        print('Updated Rive file for user $normalizedId: $riveFileUrl');
        print('Current _userRiveFiles map: $_userRiveFiles');

        // Force UI refresh
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() {});
        });
      }
    });

    socket.on('roomUpdate', (data) {
      if (!mounted) return;

      try {
        final List<dynamic> usersList = data['users'] as List;
        final users = usersList
            .map((userData) => OnlineUser(
                  id: userData['id'] as String,
                  name: userData['name'] as String,
                  avatarUrl: userData['avatarUrl'] as String,
                  motto: userData['motto'] as String? ?? '',
                ))
            .toList();

        setState(() {
          onlineUsers = users;
          userCount = data['count'] as int;
          isLoadingUsers = false;
        });
      } catch (e) {
        print('Error processing room update: $e');
      }
    });

    // Handle individual user join/leave events
    // Handle individual user join/leave events
    socket.on('userJoined', (userData) {
      if (!mounted) return;

      try {
        final newUser = OnlineUser(
          id: userData['id'],
          name: userData['name'],
          avatarUrl: userData['avatarUrl'],
          motto: userData['motto'] ?? '',
        );

        // Store the user's Rive file URL if provided
        if (userData['riveFileUrl'] != null) {
          setState(() {
            _userRiveFiles[newUser.id] = userData['riveFileUrl'];
          });
          print(
              'Received Rive file for new user ${newUser.id}: ${userData['riveFileUrl']}');
        }

        setState(() {
          // Add user if not already in list
          if (!onlineUsers.any((user) => user.id == newUser.id)) {
            onlineUsers.add(newUser);
            userCount = onlineUsers.length;
          }
        });
      } catch (e) {
        print('Error processing user join: $e');
      }
    });

    socket.on('userLeft', (userData) {
      if (!mounted) return;

      setState(() {
        onlineUsers.removeWhere((user) => user.id == userData['id']);
        userCount = onlineUsers.length;
      });
    });

    socket.on('roomChanged', (data) {
      if (!mounted) return;

      final newRoomId = data['newRoomId'];
      final userId = data['userId'];

      if (userId == widget.userId) {
        print('Received room change notification for current user');
        _resetRoomState();
        _triggerRoomEntryAnimation();
      }
    });

    socket.connect();
  }

  void safeSetState(Function setState) {
    if (mounted) {
      setState();
    }
  }

  void _prepareForRoomChange() {
    print('ROOM_CHANGE: Preparing for room change');
    print('ROOM_CHANGE: Previous room ID being saved: ${widget.roomID}');
    // Reset all flags
    _hasJoinedRoom = false;
    _hasShownInitialEntry = false;
    _lastEntryTime = null;
    _previousRoomId = widget.roomID;

    // Clear animation state
    _resetAnimationState();

    // Reset other room-specific state
    _announcement = null;
    _showWelcomeMessage = true;
    _activeEmojis.clear();

    // Cancel any existing timers
    _emojiTimers.forEach((key, timer) => timer.cancel());
    _emojiTimers.clear();
  }

  void _notifyRiveAnimationChange(String riveFileUrl) {
    socket.emit('riveAnimationChange', {
      'roomId': widget.roomID,
      'userId': widget.userId,
      'riveFileUrl': riveFileUrl
    });
  }

  void _triggerRoomChangeAnimation() {
    print('triggered room change');
    print('ANIMATION DEBUG: Triggering room change animation');
    print(
        'ANIMATION DEBUG: _userRiveFiles for current user: ${_userRiveFiles[widget.userId]}');
    print('ANIMATION DEBUG: Socket connected: ${socket.connected}');
    // Get current Rive file URL
    String? riveFileUrl = _userRiveFiles[widget.userId];
    if (riveFileUrl == null || riveFileUrl.isEmpty) {
      // Try to fetch if not available
      _fetchOwnRiveFile().then((url) {
        if (url != null && url.isNotEmpty) {
          _emitRoomChangeEvent(url);
        }
      });
      print('triggered $riveFileUrl');
    } else {
      _emitRoomChangeEvent(riveFileUrl);
    }
  }

  void _emitRoomChangeEvent(String riveFileUrl) {
    print(
        'ROOM_CHANGE: Emitting roomChangeAnimation event for userId ${widget.userId}');
    // This is a specific event just for room changes
    if (socket.connected) {
      socket.emit('roomChangeAnimation', {
        'roomId': widget.roomID,
        'userId': widget.userId,
        'userName': widget.username1,
        'riveFileUrl': riveFileUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // Update local UI state to show animation
    setState(() {
      _activeAnimationSeats[widget.userId] = DateTime.now();
    });

    // Auto-remove after 10 seconds
    _emojiTimers[widget.userId] = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _activeAnimationSeats.remove(widget.userId);
        });
      }
    });
  }

  // void _handleReconnection() {
  //   reconnectionTimer?.cancel();

  //   if (reconnectAttempts >= maxReconnectAttempts) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: const Text(
  //               'Unable to reconnect. Please check your connection.'),
  //           duration: const Duration(seconds: 5),
  //           action: SnackBarAction(
  //             label: 'Retry',
  //             onPressed: () {
  //               reconnectAttempts = 0;
  //               socket.connect();
  //             },
  //           ),
  //         ),
  //       );
  //     }
  //     return;
  //   }

  //   reconnectionTimer = Timer(const Duration(seconds: 2), () {
  //     reconnectAttempts++;
  //     if (!socket.connected) {
  //       socket.connect();
  //     }
  //   });
  // }

  void _updateUserList(Map<String, dynamic> data) {
    if (data['users'] != null) {
      final List<dynamic> usersList = data['users'] as List;
      final users = usersList
          .map((userData) => OnlineUser(
                id: userData['id'] as String,
                name: userData['name'] as String,
                avatarUrl: userData['avatarUrl'] as String,
                motto: userData['motto'] as String? ?? '',
              ))
          .toList();

      setState(() {
        onlineUsers = users;
        userCount = data['count'] as int;
      });
    }
  }

  Future<void> markAsUsed(String itemId) async {
    try {
      await HttpService.markItemAsUsed(itemId);

      final response = await http.get(
        Uri.parse('$POCKETBASE_URL/api/collections/myItems/records/$itemId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final item = json.decode(response.body);
        if (item['rive_file'] != null) {
          final riveFileUrl =
              '$POCKETBASE_URL/api/files/${item['collectionId']}/${item['id']}/${item['rive_file']}';

          // Update local state
          setState(() {
            _userRiveFiles[widget.userId] = riveFileUrl;
          });

          // Trigger entry animation
          _handleEntryAnimation(riveFileUrl);

          print('Successfully activated Rive animation: $riveFileUrl');
        }
      }

      // Refresh online users to get updated animations
      _fetchOnlineUsers();
    } catch (e) {
      print('Error marking item as used: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to activate animation: $e')),
        );
      }
    }
  }

  // Add a method to fetch a single user's rive file
  Future<String> _fetchUserRiveFile(String userId) async {
    try {
      final itemsResponse = await http.get(
        Uri.parse(
            '$POCKETBASE_URL/api/collections/myItems/records?filter=(userId="$userId" && is_used=true)'),
        headers: {'Content-Type': 'application/json'},
      );

      if (itemsResponse.statusCode == 200) {
        final itemsData = json.decode(itemsResponse.body);
        final items = itemsData['items'] as List;

        if (items.isNotEmpty && items[0]['riveFile'] != null) {
          final item = items[0];
          setState(() {
            _userRiveFiles[userId] =
                '$POCKETBASE_URL/api/files/${item['collectionId']}/${item['id']}/${item['riveFile']}';
          });
        }
      }
      return _userRiveFiles[userId] ?? '';
    } catch (e) {
      print('Error fetching user rive file: $e');
      return '';
    }
  }

  Future<bool> checkAndRecordProfileView(
      String viewerUserId, String viewedUserId) async {
    const String baseUrl = 'http://145.223.21.62:8090';

    try {
      // 1. Early return if viewer and viewed are the same user
      if (viewerUserId == viewedUserId) {
        return false;
      }

      // 2. Check for existing view with proper URL encoding
      final queryFilter =
          '(viewer_user_id="${Uri.encodeComponent(viewerUserId)}" && viewed_users_id="${Uri.encodeComponent(viewedUserId)}")';
      final checkResponse = await http.get(
        Uri.parse('$baseUrl/api/collections/profileView/records')
            .replace(queryParameters: {'filter': queryFilter}),
      );

      if (checkResponse.statusCode != 200) {
        print('Error checking existing view: ${checkResponse.statusCode}');
        print('Response body: ${checkResponse.body}');
        return false;
      }

      final existingViews = json.decode(checkResponse.body)['items'] as List;
      if (existingViews.isNotEmpty) {
        return true; // View already exists
      }

      // 3. Create new profile view record with proper headers
      final createResponse = await http.post(
        Uri.parse('$baseUrl/api/collections/profileView/records'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'viewer_user_id': viewerUserId,
          'viewed_users_id': viewedUserId,
        }),
      );

      // 4. Detailed error logging
      print(
          'Create profile view response status: ${createResponse.statusCode}');
      print('Create profile view response body: ${createResponse.body}');

      if (createResponse.statusCode != 200) {
        final errorBody = json.decode(createResponse.body);
        print('Error creating profile view: $errorBody');
        return false;
      }

      return true;
    } catch (e, stackTrace) {
      print('Error in checkAndRecordProfileView: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> _fetchInitialUsers() async {
    if (!mounted) return;

    setState(() {
      isLoadingUsers = true;
    });

    try {
      // First try to get users from socket server
      socket.emitWithAck('fetchUsers', {'roomId': widget.roomID}, ack: (data) {
        if (data != null && mounted) {
          _updateUserList(data);
        }
      });

      // Fallback to HTTP if socket isn't connected
      if (!socket.connected) {
        final response = await http.get(
          Uri.parse(
              'http://145.223.21.62:3000/api/rooms/${widget.roomID}/users'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _updateUserList(data);
        }
      }
    } catch (e) {
      print('Error fetching initial users: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingUsers = false;
        });
      }
    }
  }

  Future<void> _handleNewOnlineUser(Map<String, dynamic> record) async {
    if (record['userId'] == widget.userId) return; // Skip current user

    try {
      final userResponse = await http.get(
        Uri.parse(
            '$POCKETBASE_URL/api/collections/users/records/${record['userId']}'),
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        final newUser = OnlineUser(
          id: userData['id'],
          name: '${userData['firstname']} ${userData['lastname']}'.trim(),
          avatarUrl:
              '$POCKETBASE_URL/api/files/${userData['collectionId']}/${userData['id']}/${userData['avatar']}',
          motto: userData['moto'] ?? '',
          firstName: userData['firstname'] ?? '',
          lastName: userData['lastname'] ?? '',
        );

        if (mounted) {
          setState(() {
            onlineUsers = [...onlineUsers, newUser];
          });
        }
      }
    } catch (e) {
      print('Error handling new online user: $e');
    }
  }

  void _handleUserLeft(Map<String, dynamic> record) {
    if (mounted) {
      setState(() {
        onlineUsers.removeWhere((user) => user.id == record['userId']);
      });
    }
  }

  Future<void> _fetchOnlineUsers() async {
    if (mounted) {
      setState(() => isLoadingUsers = true);
    }

    try {
      final onlineUsersResponse = await http.get(
        Uri.parse('$POCKETBASE_URL/api/collections/online_users/records')
            .replace(queryParameters: {
          'filter': 'voiceRoomId="${widget.roomID}"',
        }),
      );

      if (onlineUsersResponse.statusCode != 200)
        throw Exception('Failed to fetch online users');

      final onlineUsersData = json.decode(onlineUsersResponse.body);
      List<OnlineUser> users = [];

      for (var onlineUser in onlineUsersData['items']) {
        if (onlineUser['userId'] == widget.userId) continue;

        try {
          final userDetailsResponse = await http.get(
            Uri.parse(
                '$POCKETBASE_URL/api/collections/users/records/${onlineUser['userId']}'),
          );

          if (userDetailsResponse.statusCode == 200) {
            final userData = json.decode(userDetailsResponse.body);
            users.add(OnlineUser(
              id: userData['id'],
              name: '${userData['firstname']} ${userData['lastname']}'.trim(),
              avatarUrl:
                  '$POCKETBASE_URL/api/files/${userData['collectionId']}/${userData['id']}/${userData['avatar']}',
              motto: userData['moto'] ?? '',
              firstName: userData['firstname'] ?? '',
              lastName: userData['lastname'] ?? '',
            ));
          }
        } catch (e) {
          print('Error fetching user details: $e');
        }
      }

      if (mounted) {
        setState(() {
          onlineUsers = users;
          userCount = users.length; // Update the count
          isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('Error fetching online users: $e');
      if (mounted) {
        setState(() => isLoadingUsers = false);
      }
    }
  }

  Future<bool> _isUserJoined(String roomId, String userId) async {
    try {
      // Check both conditions in parallel using Future.wait
      final responses = await Future.wait([
        // Check joined_users
        http.get(
            Uri.parse('$POCKETBASE_URL/api/collections/joined_users/records')),
        // Check if user is owner
        http.get(Uri.parse(
            '$POCKETBASE_URL/api/collections/voiceRooms/records/$roomId')),
      ]);

      final joinedResponse = responses[0];
      final roomResponse = responses[1];

      // Check if user is joined
      if (joinedResponse.statusCode == 200) {
        final joinedData = json.decode(joinedResponse.body);
        if (joinedData['items'] != null) {
          final records = joinedData['items'] as List;
          if (records.any((record) =>
              record['userid'] == userId &&
              record['voice_room_id'] == roomId)) {
            return true;
          }
        }
      }

      // Check if user is owner
      if (roomResponse.statusCode == 200) {
        final roomData = json.decode(roomResponse.body);
        if (roomData['ownerId'] == userId) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking join status: $e');
      return false;
    }
  }

  Future<void> updateStartTime(String userId, String voiceRoomId) async {
    const String baseUrl =
        'http://145.223.21.62:8090/api/collections/level_Timer/records';

    try {
      // Step 1: Fetch existing records for the user and voice room
      final filter = Uri.encodeComponent(
          'UserID="$userId" && voiceRoom_id="$voiceRoomId"');
      final response = await http.get(Uri.parse('$baseUrl?filter=$filter'));

      print('GET Response status: ${response.statusCode}');
      print('GET Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> records = data['items'] ?? [];

        // Step 2: Check existing record conditions
        if (records.isNotEmpty) {
          final record = records.first;

          if (record['Start_Time'] != null && record['End_Time'] == null) {
            // Delete the existing record
            final deleteResponse =
                await http.delete(Uri.parse('$baseUrl/${record['id']}'));
            print('DELETE Response status: ${deleteResponse.statusCode}');
            print('DELETE Response body: ${deleteResponse.body}');

            if (deleteResponse.statusCode != 204) {
              throw Exception('Failed to delete record');
            }
          }
        }

        // Step 3: Insert a new record with the current start time
        final newRecord = {
          'UserID': userId,
          'voiceRoom_id': voiceRoomId,
          'Start_Time': DateTime.now().toIso8601String(),
          'End_Time': null,
        };

        final postResponse = await http.post(
          Uri.parse(baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(newRecord),
        );

        print('POST Response status: ${postResponse.statusCode}');
        print('POST Response body: ${postResponse.body}');

        if (postResponse.statusCode != 200 && postResponse.statusCode != 201) {
          throw Exception('Failed to create new record');
        }
      } else {
        print('Failed to fetch records: ${response.statusCode}');
        throw Exception('Failed to fetch records');
      }
    } catch (e) {
      print('Error occurred: $e');
      rethrow;
    }
  }

  Future<void> _createOnlineUserRecord() async {
    try {
      final response = await http.post(
        Uri.parse('$POCKETBASE_URL/api/collections/online_users/records'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': widget.userId,
          'voiceRoomId': widget.roomID,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _onlineUserRecordId =
            data['id']; // Store the record ID for later deletion
        print('Created online user record: $_onlineUserRecordId');
      } else {
        print('Failed to create online user record: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating online user record: $e');
    }
  }

  Future<void> _fetchAndSetUserAvatar() async {
    try {
      final uri = Uri.parse('$POCKETBASE_URL/api/collections/users/records')
          .replace(queryParameters: {
        'filter': 'id="${widget.userId}"',
        'fields': 'id,avatar,collectionId',
      });

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('------------------------');
        print(data);
        if (data['items'] != null && data['items'].isNotEmpty) {
          final userData = data['items'][0];
          if (userData['avatar'] != null) {
            setState(() {
              _userAvatarUrl =
                  '$POCKETBASE_URL/api/files/${userData['collectionId']}/${userData['id']}/${userData['avatar']}';
              print('------------------------');
              print(_userAvatarUrl);
            });
          }
        }
      } else {
        print('Failed to fetch user avatar: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user avatar: $e');
    }
  }

  Future<void> _joinRoom(String roomId, String userId) async {
    try {
      if (!_hasJoinedRoom && socket.connected) {
        _hasJoinedRoom = true;

        // Now trigger entry animation as we actually join the room
        if (_userRiveFiles.containsKey(widget.userId)) {
          _handleEntryAnimation(_userRiveFiles[widget.userId]!);
        }
      }
      final response = await http.post(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/joined_users/records'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'voice_room_id': roomId,
          'userid': userId,
          'admin_or_not': false,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the room')),
        );
      }
    } catch (e) {
      print('Error joining room: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join room')),
      );
    }
  }

  Future<void> _deleteDuplicateOnlineUserRecords(
      String userId, String roomId) async {
    const String baseUrl =
        'http://145.223.21.62:8090/api/collections/online_users/records';

    try {
      // Step 1: Fetch all records for this user and room
      final filter =
          Uri.encodeComponent('userId="$userId" && voiceRoomId="$roomId"');
      final response = await http.get(
        Uri.parse('$baseUrl?filter=$filter'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['items'] as List;

        if (records.isEmpty) {
          print('No records found for user $userId in room $roomId');
          return;
        }

        print('Found ${records.length} records to delete');

        // Step 2: Delete all records found
        for (var record in records) {
          final recordId = record['id'];
          final deleteResponse = await http.delete(
            Uri.parse('$baseUrl/$recordId'),
            headers: {'Content-Type': 'application/json'},
          );

          if (deleteResponse.statusCode == 204 ||
              deleteResponse.statusCode == 200) {
            print('Successfully deleted record: $recordId');
          } else {
            print(
                'Failed to delete record $recordId: ${deleteResponse.statusCode}');
          }
        }
      } else {
        print('Failed to fetch records: ${response.statusCode}');
        throw Exception('Failed to fetch online user records');
      }
    } catch (e) {
      print('Error in _deleteDuplicateOnlineUserRecords: $e');
      rethrow;
    }
  }

  // Modified _handleLogout function
  Future<void> _handleLogout() async {
    try {
      print(
          'ROOM_CHANGE: Starting _handleLogout, current room: ${widget.roomID}');
      print(
          'ROOM_CHANGE: Is this a room change? ${_previousRoomId != widget.roomID}');
      // First, clean up all duplicate records
      await _deleteDuplicateOnlineUserRecords(widget.userId, widget.roomID);
      final oldRoomId = widget.roomID;
      final isRoomChange =
          _previousRoomId != null && _previousRoomId != oldRoomId;
      _prepareForRoomChange();

      if (isRoomChange) {
        print('ROOM_CHANGE: Triggering room change animation');
        _triggerRoomChangeAnimation();
      }
      // Uninitialize ZEGO services
      ZegoGiftManager().service.uninit();
      await ZegoUIKit().leaveRoom();

      // Emit leave room event to socket
      socket.emit('leaveRoom', {
        'roomId': oldRoomId,
        'userId': widget.userId,
        'isRoomChange': true,
        'fullDisconnect':
            false, // Add this parameter to indicate it's a room change, not a full disconnect
      });

      // Update end time for the session
      await updateEndTime(widget.userId, oldRoomId);

      // Reset the join flag to allow entry animation on next room
      _hasJoinedRoom = false;
      _hasShownInitialEntry = false;

      // Finally, navigate back
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during logout: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _fetchVoiceRoomDetails() async {
    try {
      final uri = Uri.parse(
              '$POCKETBASE_URL/api/collections/voiceRooms/records/${widget.roomID}')
          .replace(queryParameters: {
        'fields':
            'voice_room_name,background_images,group_photo,voiceRoom_id,announcement'
      });

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _voiceRoomName = data['voice_room_name'];
          _voiceroomid = data['voiceRoom_id'];
          _announcement = data['announcement'];
          if (data['background_images'] != null) {
            _backgroundImageUrl =
                '$POCKETBASE_URL/api/files/voiceRooms/${widget.roomID}/${data['background_images']}';
            _groupPhotoUrl =
                '$POCKETBASE_URL/api/files/voiceRooms/${widget.roomID}/${data['group_photo']}';
          }

          if (data['group_photo'] != null) {}
          print(
              "-----------------------------------------------------------------");
          print(_groupPhotoUrl);
        });
      }
    } catch (e) {
      print('Error fetching voice room details: $e');
    }
  }

  Future<void> _shareToWhatsApp() async {
    final String shareText =
        'Join our voice room!\nRoom Name: ${_voiceRoomName ?? "Voice Room"}\nRoom ID: $_voiceroomid\nCome join us for an amazing conversation!';
    final Uri whatsappUrl =
        Uri.parse("whatsapp://send?text=${Uri.encodeComponent(shareText)}");

    try {
      await launchUrl(whatsappUrl);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp is not installed')),
      );
    }
  }

  Future<void> _shareToFacebook() async {
    final String shareText =
        'Join our voice room!\nRoom Name: ${_voiceRoomName ?? "Voice Room"}\nRoom ID: $_voiceroomid\nCome join us for an amazing conversation!';
    final Uri fbUrl = Uri.parse(
        "https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(shareText)}");

    try {
      await launchUrl(fbUrl, mode: LaunchMode.externalApplication);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Facebook')),
      );
    }
  }

  void _copyRoomLink() {
    final String shareText =
        'Join our voice room!\nRoom Name: ${_voiceRoomName ?? "Voice Room"}\nRoom ID: $_voiceroomid\nCome join us for an amazing conversation!';
    Clipboard.setData(ClipboardData(text: shareText)).then((_) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room link copied to clipboard')),
      );
    });
  }

  Future<void> _fetchLanguageDetails(String roomId) async {
    try {
      final uri = Uri.parse(
              '$POCKETBASE_URL/api/collections/voiceRooms/records/$roomId')
          .replace(queryParameters: {
        'fields': 'language', // Specify the fields you want to fetch
      });

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Assuming 'language' is the field you want to display
          _language = data['language'];
        });
      } else {
        print('Failed to fetch language details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching language details: $e');
    }
  }

  Future<void> updateEndTime(String userId, String voiceRoomId) async {
    const String baseUrl =
        'http://145.223.21.62:8090/api/collections/level_Timer/records';

    try {
      // Step 1: Fetch existing records for the given userId and voiceRoomId
      final filter = Uri.encodeComponent(
          'UserID="$userId" && voiceRoom_id="$voiceRoomId"');
      final response = await http.get(Uri.parse('$baseUrl?filter=$filter'));

      print('GET Response status: ${response.statusCode}');
      print('GET Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> records = data['items'] ?? [];

        // Step 2: Find the record with an empty End_Time
        final record = records.firstWhere(
          (r) => r['End_Time'] == null || r['End_Time'] == "",
          orElse: () => null,
        );

        if (record != null) {
          // Update the End_Time for the correct record
          final updatedRecord = {
            'End_Time': DateTime.now().toIso8601String(),
          };

          final patchResponse = await http.patch(
            Uri.parse('$baseUrl/${record['id']}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(updatedRecord),
          );

          print('PATCH Response status: ${patchResponse.statusCode}');
          print('PATCH Response body: ${patchResponse.body}');

          if (patchResponse.statusCode != 200) {
            throw Exception('Failed to update the record');
          }
        } else {
          print('No active session found for the given userId and voiceRoomId');
          throw Exception('No active session found');
        }
      } else {
        throw Exception('Failed to fetch records: ${response.statusCode}');
      }
    } catch (e) {
      print('Error occurred: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    reconnectionTimer?.cancel();
    _resetAnimationState();
    socket.emit('leaveRoom', {
      'roomId': widget.roomID,
      'userId': widget.userId,
    });
    _activeAnimationSeats.clear();
    socket.disconnect();
    socket.dispose();
    // Only cleanup if not minimized
    if (!_isMinimized) {
      ZegoGiftManager().service.recvNotifier.removeListener(onGiftReceived);
      ZegoGiftManager().service.uninit();
      _controller.dispose();

      if (_onlineUserRecordId != null) {
        http.delete(
          Uri.parse(
              '$POCKETBASE_URL/api/collections/online_users/records/$_onlineUserRecordId'),
          headers: {'Content-Type': 'application/json'},
        ).catchError((e) => print('Error cleaning up online user record: $e'));

        socket.emit('leaveRoom', {
          'roomId': widget.roomID,
          'userId': widget.userId,
        });
      }

      updateEndTime(widget.userId, widget.roomID);
    }

    _emojiTimers.forEach((userId, timer) => timer.cancel());
    _emojiTimers.clear();
    socket.disconnect();
    _riveRefreshTimer?.cancel();
    super.dispose();
  }

  bool isAttributeHost(Map<String, String>? userInRoomAttributes) {
    return (userInRoomAttributes?['role'] ?? "") ==
        ZegoLiveAudioRoomRole.host.index.toString();
  }

  Widget backgroundBuilder(
      BuildContext context, Size size, ZegoUIKitUser? user, Map extraInfo) {
    if (!isAttributeHost(user?.inRoomAttributes.value)) {
      return Container();
    }

    return Positioned(
      top: -6,
      left: 0,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images1/bac.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  void _debugUserIds(ZegoUIKitUser? user) {
    if (user == null) {
      print('RIVE DEBUG: User is null');
      return;
    }

    // Log all user properties to find the issue
    print('RIVE DEBUG: User details:');
    print('  - ID: "${user.id}"');
    print('  - Name: "${user.name}"');
    print('  - inRoomAttributes: ${user.inRoomAttributes.value}');

    // Test different ID extraction methods
    if (user.id.isNotEmpty) {
      final normalizedId = _normalizeUserId(user.id);
      print('RIVE DEBUG: Normalized ID: "$normalizedId"');

      // Check if ID exists in our map
      if (_userRiveFiles.containsKey(normalizedId)) {
        print(
            'RIVE DEBUG: Found Rive file for normalized ID: ${_userRiveFiles[normalizedId]}');
      } else if (_userRiveFiles.containsKey(user.id)) {
        print(
            'RIVE DEBUG: Found Rive file for original ID: ${_userRiveFiles[user.id]}');
      } else {
        print('RIVE DEBUG: No Rive file found for this user');
        // Print all keys for debugging
        print(
            'RIVE DEBUG: Available keys in _userRiveFiles: ${_userRiveFiles.keys.toList()}');
      }
    }
  }

  Widget foregroundBuilder(
      BuildContext context, Size size, ZegoUIKitUser? user, Map extraInfo) {
    if (user == null || user.id.isEmpty) {
      return Container();
    }
    final normalizedUserId = _normalizeUserId(user.id);
    final borderUrl = _userBorders[widget.userId];
    // Check for Rive file with this user ID
    final riveFileUrl = _userRiveFiles[user.id];
    final seatIndex = extraInfo['seatIndex'] as int?;
    final bool hasActiveAnimation = _activeAnimationSeats.containsKey(user.id);

    print(
        'SEAT DEBUG: Building foreground for user: ${user.id} in seat: $seatIndex');
    print('user from foreg $user');
    print('BORDER DEBUG: Building foreground for user: ${user.id}');
    print('BORDER DEBUG: Normalized ID: $normalizedUserId');
    print('BORDER DEBUG: Has border? ${borderUrl != null}');
    if (borderUrl != null) {
      print('BORDER DEBUG: Border URL: $borderUrl');
    }
    return Stack(
      children: [
        // Highlight effect for entry animation
        if (hasActiveAnimation)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.amber,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.7),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),

        if (borderUrl != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: CachedNetworkImageProvider(borderUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

        // Rive animation if available
        if (riveFileUrl != null)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size.width / 2),
              child: rive.RiveAnimation.network(
                riveFileUrl,
                fit: BoxFit.cover,
                artboard: 'Main',
                animations: const ['idle'],
              ),
            ),
          ),

        // Username text
        if (user.name.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                " ${user.name}  ",
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // First, add a method to fetch joined users count
  Future<int> _fetchJoinedUsersCount(String roomId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/joined_users/records?filter=(voice_room_id="$roomId")'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'];
        // Add 1 to include the owner
        return items.length + 1;
      }
      return 1; // Return 1 if only owner exists
    } catch (e) {
      print('Error fetching joined users: $e');
      return 1;
    }
  }

  // 6. Modify the _showSettingsDialog() method to include announcement editing option
  void _showSettingsDialog() {
    final roomNameController = TextEditingController(text: _voiceRoomName);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.black.withOpacity(0.95),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Room Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const Divider(color: Colors.white24, height: 32),

              // Room Photo Setting
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_camera, color: Colors.blue[300]),
                ),
                title: const Text(
                  'Change Room Photo',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                subtitle: const Text(
                  'Update room profile picture',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.pop(context);
                  _pickRoomPhoto();
                },
              ),

              const Divider(color: Colors.white12, indent: 56),

              // Room Name Setting
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit, color: Colors.green[300]),
                ),
                title: const Text(
                  'Edit Room Name',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                subtitle: const Text(
                  'Change room display name',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  // Show dialog to edit room name
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.black.withOpacity(0.9),
                      title: const Text(
                        'Edit Room Name',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: TextField(
                        controller: roomNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter new room name',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                            _updateRoomName(roomNameController.text);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Divider(color: Colors.white12, indent: 56),

              // Background Setting
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.wallpaper, color: Colors.purple[300]),
                ),
                title: const Text(
                  'Change Background',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                subtitle: const Text(
                  'Customize room background',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.pop(context);
                  _pickBackgroundImage();
                },
              ),

              const Divider(color: Colors.white12, indent: 56),

              // NEW: Announcement Setting
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.campaign, color: Colors.amber[300]),
                ),
                title: const Text(
                  'Room Announcement',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                subtitle: Text(
                  _announcement != null && _announcement!.isNotEmpty
                      ? 'Edit room announcement'
                      : 'Add room announcement',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.pop(context);
                  _showAnnouncementDialog(context);
                },
              ),

              const SizedBox(height: 20),

              // Danger Zone
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danger Zone',
                      style: TextStyle(
                        color: Colors.red[300],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showDisbandConfirmation();
                      },
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: Colors.red[400]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Disband Group',
                                  style: TextStyle(
                                    color: Colors.red[400],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Permanently delete this room',
                                  style: TextStyle(
                                    color: Colors.red[200],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Add this method to show disband confirmation
  void _showDisbandConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: Colors.black.withOpacity(0.9),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Disband Group',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to disband this group? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close dialog
                      await _disbandGroup(); // This will handle the navigation and refresh
                    },
                    child: const Text(
                      'Disband',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiButton(String emoji) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            print('Emitting emoji: $emoji'); // Debug log

            // Emit the emoji reaction event to socket with all needed data
            socket.emit('gifReaction', {
              'roomId': widget.roomID,
              'userId': widget.userId,
              'userName': widget.username1,
              'emoji': emoji,
              'timestamp': DateTime.now().millisecondsSinceEpoch
            });

            // Don't show locally - wait for socket response
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEmojiAnimation(String userId, String emoji) {
    print('Showing emoji for user: $userId');

    // Remove any existing emoji for this user
    _emojiTimers[userId]?.cancel();

    setState(() {
      // Add new emoji widget to the map
      _activeEmojis[userId] = SizedBox(
        width: 50,
        height: 50,
        child: Image.asset(
          'assets/smile.gif',
          fit: BoxFit.cover,
        ),
      );
    });

    // Remove after 2 seconds
    _emojiTimers[userId] = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _activeEmojis.remove(userId);
        });
      }
    });
  }

  Widget _buildLoadingOverlay() {
    return _isLoading
        ? Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    //SizedBox(height: 16),
                    // Text(
                    //   'Loading...',
                    //   style: TextStyle(
                    //     color: Colors.white,
                    //     fontSize: 16,
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    print(
        'ROOM_CHANGE: Building UI, activeAnimationSeats: ${_activeAnimationSeats.length}');
    print(
        'ROOM_CHANGE: Active animation keys: ${_activeAnimationSeats.keys.toList()}');
    print(
        'ROOM_CHANGE: User Rive file present? ${_userRiveFiles.containsKey(widget.userId)}');

    print(
        'Build called, activeAnimationSeats: ${_activeAnimationSeats.length}, keys: ${_activeAnimationSeats.keys.toList()}');
    // Add this before your return statement
    if (_userRiveFiles.containsKey(widget.userId)) {
      print(
          'RIVE DEBUG: Test widget - Will try to render Rive file: ${_userRiveFiles[widget.userId]}');
    } else {
      print(
          'RIVE DEBUG: Test widget - No Rive file found for user ${widget.userId}');
    }
    if (_activeAnimationSeats.isNotEmpty) {
      print('Build: Active animations: ${_activeAnimationSeats.keys.toList()}');
    }
    bool showOwnEntryAnimation =
        _activeAnimationSeats.containsKey(widget.userId);
    return WillPopScope(
      onWillPop: () async {
        if (ZegoUIKitPrebuiltLiveAudioRoomController().minimize.isMinimizing) {
          setState(() {
            _isMinimized = true;
          });
          ZegoUIKitPrebuiltLiveAudioRoomController()
              .minimize
              .minimize(navigatorKey.currentState!.context);
          return true;
        }

        bool? shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            backgroundColor: Colors.black.withOpacity(0.9),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      'Leave Room',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Message
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      'Would you like to leave the room?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.2),
                  ),

                  // Action Buttons
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        // Cancel Button
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(15),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ),

                        // Vertical Divider
                        VerticalDivider(
                          width: 1,
                          color: Colors.white.withOpacity(0.2),
                        ),

                        // Minimize Button
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              // setState(() {
                              //   _isMinimized = true;
                              // });
                              // ZegoUIKitPrebuiltLiveAudioRoomController()
                              //     .minimize
                              //     .minimize(navigatorKey.currentState!.context);
                              // Navigator.pop(context, false);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Minimize',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        // Vertical Divider
                        VerticalDivider(
                          width: 1,
                          color: Colors.white.withOpacity(0.2),
                        ),

                        // Leave Button
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              await _handleLogout();
                              Navigator.pop(context, true);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  bottomRight: Radius.circular(15),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Leave',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return shouldPop ?? false;
      },
      child: SafeArea(
        child: Stack(
          children: [
            // Main Zego UIKit widget
            ZegoUIKitPrebuiltLiveAudioRoom(
              appID: 1066732685,
              appSign:
                  '22efdc0ebc48810e8635ca83123f402060a251617123f310a63d6dcd52c25d1d',
              userID: localUserID,
              userName: widget.username1,
              roomID: widget.roomID,
              events: events,
              config: config,
            ),

            if (_activeAnimationSeats.isNotEmpty || showOwnEntryAnimation)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6), // Darken the background
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final entry in _activeAnimationSeats.entries)
                          if (_userRiveFiles.containsKey(entry.key))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Column(
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.7,
                                    height:
                                        MediaQuery.of(context).size.width * 0.7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: rive.RiveAnimation.network(
                                      _userRiveFiles[entry.key]!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.amber,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      "New entry! ${_findUserName(entry.key)}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),

            // Power/Logout button
            Positioned(
              top: MediaQuery.of(context).padding.top + 2,
              right: 10,
              child: GestureDetector(
                onTap: () => _showLogoutDialog(context),
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.power_settings_new,
                      color: Colors.white.withOpacity(0.9),
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
            _buildWelcomeAndAnnouncement(),

            if (_activeEmojis.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CustomMultiChildLayout(
                  delegate: EmojiLayoutDelegate(
                    users: _activeEmojis.keys.toList(),
                    itemCount: _activeEmojis.length,
                  ),
                  children: _activeEmojis.entries.map((entry) {
                    return LayoutId(
                      id: entry.key,
                      child: entry.value,
                    );
                  }).toList(),
                ),
              ),

            // if (isConnecting)
            //   Positioned(
            //     top: MediaQuery.of(context).padding.top + 10,
            //     right: 10,
            //     child: Container(
            //       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            //       decoration: BoxDecoration(
            //         color: Colors.black54,
            //         borderRadius: BorderRadius.circular(20),
            //       ),
            //       child: Row(
            //         mainAxisSize: MainAxisSize.min,
            //         children: [
            //           SizedBox(
            //             width: 12,
            //             height: 12,
            //             child: CircularProgressIndicator(
            //               strokeWidth: 2,
            //               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            //             ),
            //           ),
            //           SizedBox(width: 8),
            //           Text(
            //             'Connecting...',
            //             style: TextStyle(
            //               color: Colors.white,
            //               fontSize: 12,
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),

            // Add a user count display
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  _showOnlineUsersBottomSheet(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      if (isLoadingUsers)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else
                        Text(
                          '${onlineUsers.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Emoji bottom sheet
            Positioned(
              bottom:
                  MediaQuery.of(context).size.height * 0.02, // 2% from bottom
              left: MediaQuery.of(context).size.width * 0.32, // 35% from left
              child: Container(
                width: 35, // Reduced from 30
                height: 35, // Reduced from 30
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero, // Remove default padding
                  constraints:
                      const BoxConstraints(), // Remove default constraints
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (BuildContext context) {
                        return Container(
                          height: MediaQuery.of(context).size.height *
                              0.4, // Reduced from 0.5
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.9),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Handle bar
                              Container(
                                width: 40, // Reduced from 40
                                height: 4, // Reduced from 4
                                margin: const EdgeInsets.only(
                                    top: 8), // Reduced from 12
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),

                              // Close button
                              Align(
                                alignment: Alignment.topRight,
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white70, size: 20),
                                  padding: const EdgeInsets.all(12),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),

                              // Emoji grid
                              Expanded(
                                child: GridView.count(
                                  crossAxisCount: 5,
                                  mainAxisSpacing: 8, // Added spacing
                                  crossAxisSpacing: 8, // Added spacing
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  childAspectRatio:
                                      1.1, // Adjust aspect ratio for better fit
                                  children: [
                                    // Happy faces
                                    _buildEmojiButton('😊'),
                                    _buildEmojiButton('😄'),
                                    _buildEmojiButton('😃'),
                                    _buildEmojiButton('😁'),
                                    _buildEmojiButton('😅'),

                                    // Love faces
                                    _buildEmojiButton('😍'),
                                    _buildEmojiButton('🥰'),
                                    _buildEmojiButton('😘'),
                                    _buildEmojiButton('😗'),
                                    _buildEmojiButton('🤗'),

                                    // Fun faces
                                    _buildEmojiButton('😜'),
                                    _buildEmojiButton('😝'),
                                    _buildEmojiButton('😋'),
                                    _buildEmojiButton('😂'),
                                    _buildEmojiButton('🤣'),

                                    // Cool faces
                                    _buildEmojiButton('😎'),
                                    _buildEmojiButton('🤩'),
                                    _buildEmojiButton('🥳'),
                                    _buildEmojiButton('😏'),
                                    _buildEmojiButton('😌'),

                                    // Reaction faces
                                    _buildEmojiButton('😮'),
                                    _buildEmojiButton('🤔'),
                                    _buildEmojiButton('😳'),
                                    _buildEmojiButton('🥺'),
                                    _buildEmojiButton('😇'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  icon: const Icon(
                    Icons.emoji_emotions,
                    color: Colors.white,
                    size: 20, // Reduced from 24
                  ),
                ),
              ),
            ),

            if (isAdmin)
              Positioned(
                top: MediaQuery.of(context).padding.top + 2,
                right: MediaQuery.of(context).size.width *
                    0.132, // Responsive positioning
                child: GestureDetector(
                  onTap: _showSettingsDialog,
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.settings,
                        color: Colors.white.withOpacity(0.9),
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ),

            // Share button
            Positioned(
              top: MediaQuery.of(context).padding.top + 2,
              right: isAdmin ? 100 : 55, // Adjust based on admin status
              child: GestureDetector(
                onTap: () => _showShareOptions(context),
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.share,
                      color: Colors.white.withOpacity(0.9),
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),

            // Settings button (for admin)

            // Room Info Overlay
            Positioned(
              top: MediaQuery.of(context).padding.top - 15, // Moved higher up
              left: 10,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.5,
                      minHeight: 60,
                      maxHeight: 60,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.withOpacity(0.2),
                          Colors.grey.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Room Image
                        GestureDetector(
                          onTap: () async {
                            if (_isLoading) return; // Prevent tap if loading

                            final now = DateTime.now();
                            if (_lastTapTime != null &&
                                now.difference(_lastTapTime!) <
                                    const Duration(milliseconds: 500)) {
                              return;
                            }
                            _lastTapTime = now;

                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              await _showBottomSheet(context, widget.roomID);
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _groupPhotoUrl != null
                                  ? Image.network(
                                      _groupPhotoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                        child: Icon(
                                          Icons.image,
                                          size: 24,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.image,
                                        size: 24,
                                        color: Colors.white70,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Room Info Column
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Room Name
                              Text(
                                _voiceRoomName ?? "Voice Room",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 4),

                              // Room ID
                              Row(
                                children: [
                                  Text(
                                    "ID: ",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "$_voiceroomid",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Ranking Overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 65,
              left: 0,
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) =>
                        RankingBottomSheet(roomId: widget.roomID),
                  );
                },
                child: Container(
                  height: 26,
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.22,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(13),
                      bottomRight: Radius.circular(13),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      )
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          "Rank",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Icon(
                          Icons.emoji_events,
                          color: Colors.amber[100],
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  String _findUserName(String userId) {
    // First check online users
    for (final user in onlineUsers) {
      if (user.id == userId) {
        return user.name;
      }
    }

    // If current user
    if (userId == widget.userId) {
      return widget.username1;
    }

    return "User";
  }

  void _showOnlineUsersBottomSheet(BuildContext context) {
    // Remove duplicates by user ID, excluding current user
    final uniqueUsers = <String, OnlineUser>{};
    for (var user in onlineUsers) {
      if (user.id != widget.userId && !uniqueUsers.containsKey(user.id)) {
        uniqueUsers[user.id] = user;
      }
    }
    final deduplicatedUsers = uniqueUsers.values.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header with user count
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Online Users (${deduplicatedUsers.length + 1})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isConnecting) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // User list
            Expanded(
              child: isLoadingUsers
                  ? _buildLoadingIndicator()
                  : RefreshIndicator(
                      onRefresh: _fetchOnlineUsers,
                      color: Colors.white,
                      backgroundColor: Colors.blue,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          // Current user (always first)
                          if (_userAvatarUrl != null) ...[
                            _buildUserListItem(
                              OnlineUser(
                                id: widget.userId,
                                name: widget.username1,
                                avatarUrl: _userAvatarUrl!,
                                motto: '',
                              ),
                              isCurrentUser: true,
                              index: 1,
                            ),
                            Divider(
                              color: Colors.white.withOpacity(0.1),
                              height: 1,
                            ),
                          ],

                          // Other users
                          ...deduplicatedUsers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final user = entry.value;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildUserListItem(
                                  user,
                                  isCurrentUser: false,
                                  index: index + 2,
                                ),
                                if (index < deduplicatedUsers.length - 1)
                                  Divider(
                                    color: Colors.white.withOpacity(0.1),
                                    height: 1,
                                  ),
                              ],
                            );
                          }),

                          // Empty state
                          if (deduplicatedUsers.isEmpty) _buildEmptyState(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            'Loading users...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              color: Colors.grey,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No other users online',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserListItem(OnlineUser user,
      {required bool isCurrentUser, required int index}) {
    return GestureDetector(
      onTap: () => _handleUserTap(user, isCurrentUser),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Index/Star column
            SizedBox(
              width: 30,
              child: isCurrentUser
                  ? const Icon(Icons.star, color: Colors.amber, size: 20)
                  : Text(
                      '$index',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
            ),
            // Avatar
            GestureDetector(
              onTap: () => _handleUserTap(user, isCurrentUser),
              child: CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(user.avatarUrl),
                onBackgroundImageError: (e, s) =>
                    const AssetImage('assets/default_avatar.png'),
              ),
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (user.motto.isNotEmpty)
                    Text(
                      user.motto,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            // Chevron icon for non-current users
            if (!isCurrentUser)
              GestureDetector(
                onTap: () => _handleUserTap(user, isCurrentUser),
                child: const Icon(Icons.chevron_right,
                    color: Colors.white54, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUserTap(OnlineUser user, bool isCurrentUser) async {
    if (!isCurrentUser) {
      try {
        final canView = await checkAndRecordProfileView(widget.userId, user.id);

        if (canView && mounted) {
          Navigator.pop(context); // Close bottom sheet

          showDialog(
            context: context,
            barrierDismissible: true,
            barrierColor: Colors.black.withOpacity(0.85),
            builder: (BuildContext context) {
              return ProfileScreenView(
                viewedUserId: user.id,
                viewerUserId: widget.userId,
              );
            },
          );
        }
      } catch (e) {
        print('Error showing profile: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load profile')),
          );
        }
      }
    }
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share via',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareButton(
                    imageUrl:
                        'https://logodownload.org/wp-content/uploads/2015/04/whatsapp-logo-1.png',
                    label: 'WhatsApp',
                    onTap: () => _shareToWhatsApp(),
                    color: const Color(0xFF25D366),
                  ),
                  _buildShareButton(
                    imageUrl:
                        'https://brandpalettes.com/wp-content/uploads/2018/05/Facebook-Logo-JPG.jpg',
                    label: 'Facebook',
                    onTap: () => _shareToFacebook(),
                    color: const Color(0xFF1877F2),
                  ),
                  _buildShareButton(
                    icon: Icons.copy,
                    label: 'Copy Link',
                    onTap: () => _copyRoomLink(),
                    color: Colors.grey[700]!,
                    isIconButton: true,
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareButton({
    String? imageUrl,
    IconData? icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isIconButton = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: isIconButton
                  ? Icon(icon, color: Colors.white, size: 30)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        imageUrl!,
                        width: 45,
                        height: 45,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 30,
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // screen eka kalu wela logout wena kalla
  void _showFullBlackLogoutContainer() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8), // Semi-transparent black
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context).pop();
            return false;
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logout Button
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _handleLogout();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Colors.lightBlue, Colors.lightBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.power_settings_new,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Leave',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30), // Space between buttons

                // Keep Button
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Colors.lightBlue,
                              Colors.lightBlue,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'keep',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Modify the _showLogoutDialog method to use the new full black container
  void _showLogoutDialog(BuildContext context) {
    _showFullBlackLogoutContainer(); // Replace the existing alert dialog
  }

  // void _showLogoutDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Leave Room'),
  //       content: const Text('Are you sure you want to leave this room?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         TextButton(
  //           onPressed: () async {
  //             Navigator.pop(context); // Close dialog
  //             await _handleLogout();
  //           },
  //           child: const Text(
  //             'Leave',
  //             style: TextStyle(color: Colors.red),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _showBottomSheet(BuildContext context, String roomId) async {
    // Prevent multiple bottom sheets
    final now = DateTime.now();
    if (_lastBottomSheetTime != null &&
        now.difference(_lastBottomSheetTime!) <
            const Duration(milliseconds: 50)) {
      return;
    }
    _lastBottomSheetTime = now;

    if (!mounted) return;

    try {
      // Fetch the current userId from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('userId') ??
          ''; // Default to an empty string if not found

      bool isUserJoined = await _isUserJoined(roomId, currentUserId);
      print("----------------------joining____________________");
      print(isUserJoined);

      if (currentUserId.isEmpty) {
        print('Error: User ID not found in SharedPreferences');
        return;
      }

      // Fetch room data
      final roomResponse = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/voiceRooms/records/$roomId'),
      );

      if (roomResponse.statusCode != 200) return;

      final roomData = json.decode(roomResponse.body);
      final joinedUsersCount = await _fetchJoinedUsersCount(roomId);

      // Determine if the current user is joined or the room owner
      //bool isUserJoined = false;
      bool isRoomOwner = false;

      // Check if the user has joined the room
      final joinedCheckResponse = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/joined_users/records?filter=(voice_room_id="$roomId" && userid="$currentUserId")'),
      );
      if (joinedCheckResponse.statusCode == 200) {
        final joinedData = json.decode(joinedCheckResponse.body);
        isUserJoined = (joinedData['items'] as List).isNotEmpty;
      }

      // Check if the user is the room owner
      isRoomOwner = roomData['ownerId'] == currentUserId;

      if (!mounted) return;

      // Show the bottom sheet
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        builder: (context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Header with close and settings buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Center(
                          child: Text(
                            "Room Information",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isRoomOwner)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                  ),

                  // Tab Bar
                  const TabBar(
                    tabs: [Tab(text: 'Profile'), Tab(text: 'Member')],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                  ),

                  // Tab View Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Profile Tab
                        // Inside your _showBottomSheet method, modify the Profile Tab content:
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              // Room Profile Image
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.grey[200]!, width: 2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(60),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        'http://145.223.21.62:8090/api/files/voiceRooms/${roomData['id']}/${roomData['group_photo']}',
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const CircularProgressIndicator(),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Room Name
                              Text(
                                roomData['voice_room_name'] ??
                                    'Welcome Everyone',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              // Room ID with copy icon
                              StatefulBuilder(
                                builder: (BuildContext context,
                                    StateSetter setModalState) {
                                  return Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Room ID: ',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(
                                                  text: roomData['voiceRoom_id']
                                                      .toString()));
                                              setModalState(() {
                                                _showCopySuccess = true;
                                              });
                                              Future.delayed(
                                                  const Duration(seconds: 2),
                                                  () {
                                                if (mounted) {
                                                  setModalState(() {
                                                    _showCopySuccess = false;
                                                  });
                                                }
                                              });
                                            },
                                            child: Row(
                                              children: [
                                                Text(
                                                  '${roomData['voiceRoom_id']}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.copy,
                                                  size: 16,
                                                  color: Colors.blue,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_showCopySuccess)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Copied to clipboard',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              // Room Details Container
                              Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _buildDetailRow('Country:',
                                        roomData['voiceRoom_country'] ?? ''),
                                    _buildLevelRow(),
                                    _buildDetailRow(
                                        'Members:', '$joinedUsersCount/500'),
                                    _buildRoomModeTags(roomData),
                                    _buildLanguageRow(),
                                    // Add Join Button here
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 24),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isUserJoined
                                              ? Colors.grey[400]
                                              : Colors.lightBlue,
                                          minimumSize:
                                              const Size(double.infinity, 50),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(25),
                                          ),
                                          elevation: isUserJoined ? 0 : 2,
                                        ),
                                        onPressed: isUserJoined
                                            ? null
                                            : () => _joinRoom(
                                                roomId, currentUserId),
                                        child: Text(
                                          isUserJoined
                                              ? 'Already Joined'
                                              : 'Join Room',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Member Tab
                        Stack(
                          children: [
                            MemberListScreen(
                              voiceRoomId: roomId,
                              currentUserId: currentUserId,
                              isJoined: isUserJoined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Error in _showBottomSheet: $e');
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageRow() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Language:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            _language ??
                'Not specified', // Display the language or a default message
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Level:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Text(
                'LV.4',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 100,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[300]!],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LV.5',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomModeTags(Map<String, dynamic> roomData) {
    final tags = (roomData['tags'] ?? '')
        .toString()
        .split(',')
        .where((tag) => tag.trim().isNotEmpty)
        .join(', '); // Join all tags with comma and space

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Room mode:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            tags.isEmpty ? 'Not specified' : tags,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build member list item
  Widget _buildMemberListItem(Map<String, dynamic> user) {
    return Container(
      height: 70,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: CachedNetworkImage(
            imageUrl:
                "http://145.223.21.62:8090/api/files/${user['collectionId']}/${user['id']}/${user['avatar']}",
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue[300],
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: Icon(Icons.person, color: Colors.grey[400]),
            ),
          ),
        ),
        title: Text(
          user['firstname'] ?? "Unknown",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          user['bio'] ?? "No bio available",
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  // Header Section
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Text(
            "Room Information",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Updated helper method for room tags
  Widget _buildRoomTags(String tags) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: tags.split(',').map((tag) {
        final trimmedTag = tag.trim();
        if (trimmedTag.isEmpty) return const SizedBox();
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              trimmedTag,
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Helper Widgets

  Widget _buildLevelProgress() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'LV.4',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 100,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              Container(
                width: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[300]!],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'LV.5',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRoomUserDetails(
      String roomId) async {
    const String url =
        "http://145.223.21.62:8090/api/collections/users/records"; // Replace with the actual API endpoint
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['items']);
      } else {
        print("Failed to fetch data: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching user details: $e");
      return [];
    }
  }

  ZegoUIKitPrebuiltLiveAudioRoomConfig get config {
    return (widget.isHost
        ? ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
        : ZegoUIKitPrebuiltLiveAudioRoomConfig.audience())
      ..seat = (getSeatConfig()
        ..takeIndexWhenJoining = widget.isHost ? getHostSeatIndex() : -1
        ..hostIndexes = getLockSeatIndex()
        ..layout = getLayoutConfig())
      ..background = background()
      ..mediaPlayer.supportTransparent = true
      ..foreground = giftForeground()
      ..emptyAreaBuilder = mediaPlayer
      // ..topMenuBar.buttons = [
      //   ZegoLiveAudioRoomMenuBarButtonName.minimizingButton, // Keep only this button
      // ]
      ..userAvatarUrl = _userAvatarUrl;
  }

  ZegoUIKitPrebuiltLiveAudioRoomEvents get events {
    return ZegoUIKitPrebuiltLiveAudioRoomEvents(
      user: ZegoLiveAudioRoomUserEvents(
          onCountOrPropertyChanged: (List<ZegoUIKitUser> users) {
        debugPrint(
          'onUserCountOrPropertyChanged:${users.map((e) => e.toString())}',
        );
      }, onEnter: (user) async {
        print('new entered user: $user');
        String? rivefile = await _fetchOwnRiveFile();
        print('new entered rivefile: $rivefile');
        _handleEntryAnimation(rivefile!);
      }),

      seat: ZegoLiveAudioRoomSeatEvents(
        onClosed: () {
          debugPrint('on seat closed');
        },
        onOpened: () {
          debugPrint('on seat opened');
        },
        onChanged: (
          Map<int, ZegoUIKitUser> takenSeats,
          List<int> untakenSeats,
        ) {
          debugPrint(
            'on seats changed, taken seats:$takenSeats, untaken seats:$untakenSeats',
          );
// Process taken seats
          takenSeats.forEach((seatIndex, user) {
            _handleSeatTaken(user.id, seatIndex);
          });

          // Process empty seats
          for (var seatIndex in untakenSeats) {
            setState(() {
              _seatOccupants.remove(seatIndex);
            });
          }
        },

        /// WARNING: will override prebuilt logic
        // onClicked:(int index, ZegoUIKitUser? user) {
        //   debugPrint(
        //       'on seat clicked, index:$index, user:${user.toString()}');
        // },
        host: ZegoLiveAudioRoomSeatHostEvents(
          onTakingRequested: (ZegoUIKitUser audience) {
            debugPrint('on seat taking requested, audience:$audience');
          },
          onTakingRequestCanceled: (ZegoUIKitUser audience) {
            debugPrint('on seat taking request canceled, audience:$audience');
          },
          onTakingInvitationFailed: () {
            debugPrint('on invite audience to take seat failed');
          },
          onTakingInvitationRejected: (ZegoUIKitUser audience) {
            debugPrint('on seat taking invite rejected');
          },
        ),
        audience: ZegoLiveAudioRoomSeatAudienceEvents(
          onTakingRequestFailed: () {
            debugPrint('on seat taking request failed');
          },
          onTakingRequestRejected: () {
            debugPrint('on seat taking request rejected');
          },
          onTakingInvitationReceived: () {
            debugPrint('on host seat taking invite sent');
          },
        ),
      ),

      /// WARNING: will override prebuilt logic
      memberList: ZegoLiveAudioRoomMemberListEvents(
        onMoreButtonPressed: onMemberListMoreButtonPressed,
      ),
    );
  }

  Widget mediaPlayer(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container();

        return simpleMediaPlayer(
          canControl: widget.isHost,
        );

        return advanceMediaPlayer(
          constraints: constraints,
          canControl: widget.isHost,
        );
      },
    );
  }

  Widget background() {
    List<String> imageList = [
      "https://th.bing.com/th/id/OIP.XBvFTQ9AFT56EbqP60aKVwHaFj?rs=1&pid=ImgDetMain",
      "https://ids13.com/wp-content/uploads/2021/04/gem-saviour-conquest.jpg",
      "https://play-lh.googleusercontent.com/uMCSwJnIKCemiAIc7xNTGBkOxlSu_e6xzZb29cqqV6bKU8Qz0m4ZQ5pmGhBNxE-vBrA",
    ];

    /// how to replace background view
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              fit: BoxFit.fill,
              image: _backgroundImageUrl != null
                  ? NetworkImage(_backgroundImageUrl!)
                  : const AssetImage('assets/images1/back.jpg')
                      as ImageProvider,
            ),
          ),
        ),
        // Positioned(
        //   top: 35,
        //   left: 30,
        //   right: 30,
        //   // Add right and left to create space
        //   bottom: 30,
        //   // Add bottom if you want to create a border for the center
        //   child: Align(
        //     alignment: Alignment.topCenter, // This will center the text
        //     child: Text(
        //       '$_voiceRoomName',
        //       overflow: TextOverflow.ellipsis,
        //       style: TextStyle(
        //         color: Colors.blueAccent,
        //         fontSize: 20,
        //         fontWeight: FontWeight.bold,
        //       ),
        //     ),
        //   ),
        // ),
        Positioned(
          bottom: 165, // Adjusted position
          right: 16, // Adjusted position
          child: SizedBox(
            width: 70, // Vertical rectangle width
            height: 190, // Vertical rectangle height
            child: ImageCarouselSlider(
              items: imageList,
              imageHeight: 180, // Matches the container height
              dotColor: Colors.black, // Dot color for indicators
            ),
          ),
        ),
        Positioned(
          bottom: 70,
          right: 16,
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return InkWell(
                onTap: () {
                  showGiftListSheet(context, widget.roomID);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape
                        .circle, // Makes the glow round around the image
                    boxShadow: [
                      BoxShadow(
                        color: Colors.yellowAccent
                            .withOpacity(0.7), // Glow color (you can change it)
                        spreadRadius: 6 *
                            _glowAnimation
                                .value, // Animated spread size of the glow
                        blurRadius: 15 *
                            _glowAnimation
                                .value, // Animated blur size of the glow
                        offset: const Offset(0,
                            0), // Position of the glow (centered around the image)
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/gift.png',
                    width: 48,
                    height: 48,
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  // ZegoLiveAudioRoomSeatConfig getSeatConfig() {
  //   if (widget.layoutMode == LayoutMode.hostTopCenter) {
  //     return ZegoLiveAudioRoomSeatConfig(
  //       backgroundBuilder: (
  //         BuildContext context,
  //         Size size,
  //         ZegoUIKitUser? user,
  //         Map<String, dynamic> extraInfo,
  //       ) {
  //         return Container(color: Colors.grey);
  //       },
  //     );
  //   }
  //
  //   return ZegoLiveAudioRoomSeatConfig(
  //       avatarBuilder: avatarBuilder,
  //       );
  // }

  ZegoLiveAudioRoomSeatConfig getSeatConfig() {
    return ZegoLiveAudioRoomSeatConfig(
      backgroundBuilder: backgroundBuilder,
      foregroundBuilder: foregroundBuilder,
      avatarBuilder: avatarBuilder,
      showSoundWaveInAudioMode: true,
    );
  }

  Widget avatarBuilder(
    BuildContext context,
    Size size,
    ZegoUIKitUser? user,
    Map<String, dynamic> extraInfo,
  ) {
    if (user == null) return Container();

    final userId = widget.userId;
    final normalizedUserId = _normalizeUserId(userId);
    final borderUrl = _userBorders[userId];
    final seatIndex = extraInfo['seatIndex'] as int?;
    String? avatarUrl;
    if (seatIndex != null && _seatOccupants.containsKey(seatIndex)) {
      avatarUrl = _seatOccupants[seatIndex]!['userAvatar'];
    }
    if (avatarUrl == null) {
      for (final onlineUser in onlineUsers) {
        if (onlineUser.id == userId || onlineUser.id == normalizedUserId) {
          avatarUrl = onlineUser.avatarUrl;
          break;
        }
      }
    }

    // If still not found and this is the current user, use current user's avatar
    if (avatarUrl == null &&
        (userId == widget.userId || normalizedUserId == widget.userId)) {
      avatarUrl = _userAvatarUrl;
    }

    // Debug log
    print('AVATAR_DEBUG: Building avatar for $userId in seat $seatIndex');
    print('AVATAR DEBUG: Border URL: ${borderUrl ?? "none"}');

    return ClipRRect(
      borderRadius: BorderRadius.circular(size.width / 2),
      child: SizedBox(
        width: size.width,
        height: size.width,
        child: Stack(
          children: [
            // Base avatar container
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: size.width,
                      height: size.width,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.group, color: Colors.grey[400]),
                    ),
            ),
            // Border overlay
            // if (borderUrl != null)
            //   Container(
            //     width: size.width + 40,
            //     height: size.width + 40,
            //     decoration: BoxDecoration(
            //       shape: BoxShape.circle,
            //       image: DecorationImage(
            //         image: CachedNetworkImageProvider(borderUrl),
            //         fit: BoxFit.cover,
            //       ),
            //     ),
            //   ),
            // Emoji overlay
          ],
        ),
      ),
    );
  }

  int getHostSeatIndex() {
    if (widget.layoutMode == LayoutMode.hostCenter) {
      return 4;
    }

    return 0;
  }

  List<int> getLockSeatIndex() {
    if (widget.layoutMode == LayoutMode.hostCenter) {
      return [4];
    }

    return [0];
  }

  ZegoLiveAudioRoomLayoutConfig getLayoutConfig() {
    final config = ZegoLiveAudioRoomLayoutConfig();
    LayoutMode lm = widget.layoutMode;
    lm = LayoutMode.hostTopCenter;
    switch (lm) {
      case LayoutMode.defaultLayout:
        break;
      case LayoutMode.full:
        config.rowSpacing = 5;
        config.rowConfigs = List.generate(
          4,
          (index) => ZegoLiveAudioRoomLayoutRowConfig(
            count: 4,
            alignment: ZegoLiveAudioRoomLayoutAlignment.spaceBetween,
          ),
        );
        break;
      case LayoutMode.horizontal:
        config.rowSpacing = 5;
        config.rowConfigs = [
          ZegoLiveAudioRoomLayoutRowConfig(
            count: 8,
            alignment: ZegoLiveAudioRoomLayoutAlignment.spaceBetween,
          ),
        ];
        break;
      case LayoutMode.vertical:
        config.rowSpacing = 5;
        config.rowConfigs = List.generate(
          8,
          (index) => ZegoLiveAudioRoomLayoutRowConfig(
            count: 1,
            alignment: ZegoLiveAudioRoomLayoutAlignment.spaceBetween,
          ),
        );
        break;
      case LayoutMode.hostTopCenter:
        config.rowConfigs = [
          ZegoLiveAudioRoomLayoutRowConfig(
            count: 1,
            alignment: ZegoLiveAudioRoomLayoutAlignment.center,
          ),
          ZegoLiveAudioRoomLayoutRowConfig(
            count: 4,
            alignment: ZegoLiveAudioRoomLayoutAlignment.spaceBetween,
          ),
          ZegoLiveAudioRoomLayoutRowConfig(
            count: 4,
            alignment: ZegoLiveAudioRoomLayoutAlignment.spaceBetween,
          ),
        ];
        break;
      case LayoutMode.hostCenter:
        config.rowSpacing = 5;
        config.rowConfigs = [
          ZegoLiveAudioRoomLayoutRowConfig(
            count: 4,
            alignment: ZegoLiveAudioRoomLayoutAlignment.spaceBetween,
          ),
          ZegoLiveAudioRoomLayoutRowConfig(
            count: 4,
            alignment: ZegoLiveAudioRoomLayoutAlignment.spaceBetween,
          ),
        ];
        break;
      case LayoutMode.fourPeoples:
        config.rowConfigs = [
          ZegoLiveAudioRoomLayoutRowConfig(
            count: 4,
            alignment: ZegoLiveAudioRoomLayoutAlignment.spaceBetween,
          ),
        ];
        break;
    }
    return config;
  }

  void onMemberListMoreButtonPressed(ZegoUIKitUser user) {
    showModalBottomSheet(
      backgroundColor: const Color(0xff111014),
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32.0),
          topRight: Radius.circular(32.0),
        ),
      ),
      isDismissible: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        const textStyle = TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
        final listMenu = ZegoUIKitPrebuiltLiveAudioRoomController()
                .seat
                .localHasHostPermissions
            ? [
                GestureDetector(
                  onTap: () async {
                    Navigator.of(context).pop();

                    ZegoUIKit().removeUserFromRoom(
                      [user.id],
                    ).then((result) {
                      debugPrint('kick out result:$result');
                    });
                  },
                  child: Text(
                    'Kick Out ${user.name}',
                    style: textStyle,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    Navigator.of(context).pop();

                    ZegoUIKitPrebuiltLiveAudioRoomController()
                        .seat
                        .host
                        .inviteToTake(user.id)
                        .then((result) {
                      debugPrint('invite audience to take seat result:$result');
                    });
                  },
                  child: Text(
                    'Invite ${user.name} to take seat',
                    style: textStyle,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: textStyle,
                  ),
                ),
              ]
            : [];
        return AnimatedPadding(
          padding: MediaQuery.of(context).viewInsets,
          duration: const Duration(milliseconds: 50),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 10,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: listMenu.length,
              itemBuilder: (BuildContext context, int index) {
                return SizedBox(
                  height: 60,
                  child: Center(child: listMenu[index]),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget giftForeground() {
    return ValueListenableBuilder<PlayData?>(
      valueListenable: ZegoGiftManager().playList.playingDataNotifier,
      builder: (context, playData, _) {
        if (null == playData) {
          return const SizedBox.shrink();
        }

        if (playData.giftItem.type == ZegoGiftType.svga) {
          return svgaWidget(playData);
        } else {
          return mp4Widget(playData);
        }
      },
    );
  }

  Widget svgaWidget(PlayData playData) {
    if (playData.giftItem.type != ZegoGiftType.svga) {
      return const SizedBox.shrink();
    }

    /// you can define the area and size for displaying your own
    /// animations here
    int level = 1;
    if (playData.giftItem.weight < 10) {
      level = 1;
    } else if (playData.giftItem.weight < 100) {
      level = 2;
    } else {
      level = 3;
    }
    switch (level) {
      case 2:
        return Positioned(
          top: 100,
          bottom: 100,
          left: 10,
          right: 10,
          child: ZegoSvgaPlayerWidget(
            key: UniqueKey(),
            playData: playData,
            onPlayEnd: () {
              ZegoGiftManager().playList.next();
            },
          ),
        );
      case 3:
        return ZegoSvgaPlayerWidget(
          key: UniqueKey(),
          playData: playData,
          onPlayEnd: () {
            ZegoGiftManager().playList.next();
          },
        );
    }
    // level 1
    return Positioned(
      bottom: 200,
      left: 10,
      child: ZegoSvgaPlayerWidget(
        key: UniqueKey(),
        size: const Size(100, 100),
        playData: playData,
        onPlayEnd: () {
          /// if there is another gift animation, then play
          ZegoGiftManager().playList.next();
        },
      ),
    );
  }

  Widget mp4Widget(PlayData playData) {
    if (playData.giftItem.type != ZegoGiftType.mp4) {
      return const SizedBox.shrink();
    }

    /// you can define the area and size for displaying your own
    /// animations here
    int level = 1;
    if (playData.giftItem.weight < 10) {
      level = 1;
    } else if (playData.giftItem.weight < 100) {
      level = 2;
    } else {
      level = 3;
    }
    switch (level) {
      case 2:
        return Positioned(
          top: 100,
          bottom: 100,
          left: 10,
          right: 10,
          child: ZegoMp4PlayerWidget(
            key: UniqueKey(),
            playData: playData,
            onPlayEnd: () {
              ZegoGiftManager().playList.next();
            },
          ),
        );
      case 3:
        return ZegoMp4PlayerWidget(
          key: UniqueKey(),
          playData: playData,
          onPlayEnd: () {
            ZegoGiftManager().playList.next();
          },
        );
    }
    // level 1
    return Positioned(
      bottom: 200,
      left: 10,
      child: ZegoMp4PlayerWidget(
        key: UniqueKey(),
        size: const Size(100, 100),
        playData: playData,
        onPlayEnd: () {
          /// if there is another gift animation, then play
          ZegoGiftManager().playList.next();
        },
      ),
    );
  }

  void onGiftReceived() {
    final receivedGift = ZegoGiftManager().service.recvNotifier.value ??
        ZegoGiftProtocolItem.empty();
    final giftData = queryGiftInItemList(receivedGift.name);
    if (null == giftData) {
      debugPrint('not ${receivedGift.name} exist');
      return;
    }

    ZegoGiftManager().playList.add(PlayData(
          giftItem: giftData,
          count: receivedGift.count,
        ));
  }
}
