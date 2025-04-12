import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leo_app_01/HomeScreen.dart';
import 'package:leo_app_01/chat/chatting.dart';
import '../services/socket_service.dart';
import '../models/message.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/chat_request_screen.dart';

class ChatListScreenUser extends StatefulWidget {
  final String currentUserId;
  final Function onNavigation;
  const ChatListScreenUser(
      {super.key, required this.currentUserId, required this.onNavigation});

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreenUser>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final SocketService _socketService = SocketService();
  final Map<String, dynamic> _userStatus = {};
  final List<String> _chatUsers = []; // Combined list of all chat users
  final Map<String, Message> _latestMessages =
      {}; // Store latest messages per user
  // Add this near your other state variables
  final Map<String, dynamic> _userProfiles = {}; // Store user profile data
  bool _isLoading = true;
  final Map<String, int> _unreadCounts = {}; // Track unread messages per user

  // Add TabController
  late TabController _tabController;
  final FocusNode _focusNode = FocusNode();
  bool _isFirstLoad = true;
  Timer? _refreshTimer;
  bool _isOnChatListScreen = true;

  final List<String> _blockedUsers = [];
  bool _isLoadingBlockedUsers = true;

  void _startPeriodicRefresh() {
    // Cancel any existing timer first
    _stopPeriodicRefresh();

    // Start a new timer that refreshes every second
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isOnChatListScreen && mounted) {
        print('📊 Periodic refresh: Updating chat list');
        _socketService.getChattedUsers(widget.currentUserId);
        _socketService.getUnreadCounts(widget.currentUserId);
        _socketService
            .getUserStatus(); // Make sure to request user status updates
      }
    });

    print('⏰ Started periodic refresh timer');
  }

  void _stopPeriodicRefresh() {
    if (_refreshTimer != null && _refreshTimer!.isActive) {
      _refreshTimer!.cancel();
      print('⏰ Stopped periodic refresh timer');
    }
    _refreshTimer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_onFocusChange);
    _startPeriodicRefresh();

    // Initialize the TabController
    _tabController = TabController(length: 1, vsync: this);
    _socketService.onUserBlocked = (blockedUserId) {
      print("🔒 User blocked: $blockedUserId");
      setState(() {
        if (!_blockedUsers.contains(blockedUserId)) {
          _blockedUsers.add(blockedUserId);
        }
      });
    };

    _socketService.onUserUnblocked = (unblockedUserId) {
      print("🔓 User unblocked: $unblockedUserId");
      setState(() {
        _blockedUsers.remove(unblockedUserId);
      });
    };

    // Fetch blocked users initially
    _fetchBlockedUsers();
    _socketService.onChattedUsers = (List<String> userIds) {
      print('📦 RECEIVED chatted users: $userIds');
      setState(() {
        _chatUsers.clear();
        _chatUsers.addAll(userIds);
        _isLoading = false;
      });

      // Fetch user profiles for these IDs
      _fetchUserProfiles(userIds);
    };

    _socketService.onUnreadCounts = (Map<String, int> counts) {
      print('📊 Received unread counts: $counts');
      setState(() {
        _unreadCounts.clear();
        _unreadCounts.addAll(counts);
      });
    };

    _socketService.onUnreadCountUpdate = (Map<String, dynamic> data) {
      final fromUserId = data['fromUserId'];
      final count = data['count'] as int;

      print('📬 Unread count update from $fromUserId: $count');

      setState(() {
        _unreadCounts[fromUserId] = count;
      });
    };

    // Properly handle user status updates
    _socketService.onUserStatus = (Map<String, dynamic> statusMap) {
      print('👤 Received user status update: $statusMap');
      setState(() {
        // Update our local user status map
        _userStatus.addAll(statusMap);
      });
    };

    // Set up a socket listener for user status updates
    _socketService.getChattedUsers(widget.currentUserId);
    print('uid chat list: ${widget.currentUserId}');

    // Set up a single message listener for all types of messages
    _socketService.onNewMessage = (message) {
      setState(() {
        // Handle direct messages
        if (message.receiverId == widget.currentUserId ||
            message.senderId == widget.currentUserId) {
          String otherUserId = message.senderId == widget.currentUserId
              ? message.receiverId
              : message.senderId;

          // Add user to chat list if not already present
          if (!_chatUsers.contains(otherUserId)) {
            _chatUsers.add(otherUserId);
          }

          // Store latest message
          _latestMessages[otherUserId] = message;

          // Only increment unread count if we are the receiver (not the sender)
          if (message.receiverId == widget.currentUserId &&
              message.senderId != widget.currentUserId) {
            _unreadCounts[message.senderId] =
                (_unreadCounts[message.senderId] ?? 0) + 1;
            print(
                'Unread count for ${message.senderId}: ${_unreadCounts[message.senderId]}');
          }

          // Update timestamps to force re-sort of the chat list
          _sortChatUsers();
        }
      });
    };

    _socketService.onConnect = () {
      print("Socket connected, now requesting data");
      _socketService.getChattedUsers(widget.currentUserId);
      _socketService.getUnreadCounts(widget.currentUserId);
      _socketService.getUserStatus(); // Request user status right away
    };

    // Make sure we're connected and request unread counts
    if (!_socketService.isConnected) {
      print("Connecting socket for user: ${widget.currentUserId}");
      _socketService.connect(widget.currentUserId);
    } else {
      _socketService.getChattedUsers(widget.currentUserId);
      _socketService.getUnreadCounts(widget.currentUserId);
      _socketService.getUserStatus();
    }

    // Handle chat history response to build chat list
    _socketService.onChatHistory = (messages) {
      if (messages.isEmpty) {
        return; // No messages found for this chat
      }

      // Determine the other user ID by looking at first message
      final message = messages.first;
      final otherUserId = message.senderId == widget.currentUserId
          ? message.receiverId
          : message.senderId;

      print(
          '📱 Got chat history with: $otherUserId (${messages.length} messages)');

      // Add this user to our chat list if not already there
      if (!_chatUsers.contains(otherUserId)) {
        setState(() {
          _chatUsers.add(otherUserId);
        });
      }

      // Find the latest message for this user
      Message? latestMessage =
          messages.fold(null, (Message? latest, Message current) {
        if (latest == null || current.timestamp > latest.timestamp) {
          return current;
        }
        return latest;
      });

      if (latestMessage != null) {
        setState(() {
          _latestMessages[otherUserId] = latestMessage;
          _isLoading = false;

          // Re-sort the chat list when a new latest message arrives
          _sortChatUsers();
        });
      }
    };

    // Request user status
    _socketService.getUserStatus();

    // Load chat history for recent chats
    _socketService.getChattedUsers(widget.currentUserId);
    print("⭐ Requested chatted users for: ${widget.currentUserId}");
  }

  void _fetchBlockedUsers() {
    if (widget.currentUserId.isEmpty) return;

    setState(() {
      _isLoadingBlockedUsers = true;
    });

    _socketService.getBlockedUsers(widget.currentUserId, (blockedUsers) {
      print("🚫 Received blocked users: $blockedUsers");
      setState(() {
        _blockedUsers.clear();
        _blockedUsers.addAll(blockedUsers);
        _isLoadingBlockedUsers = false;
      });
    });
  }

  // Sort chat users based on latest message timestamp (newest first)
  void _sortChatUsers() {
    setState(() {
      _chatUsers.sort((a, b) {
        // Get timestamps for the latest messages from both users
        final aTimestamp = _latestMessages[a]?.timestamp ?? 0;
        final bTimestamp = _latestMessages[b]?.timestamp ?? 0;

        // Sort in descending order (newest first)
        return bTimestamp.compareTo(aTimestamp);
      });
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_isFirstLoad) {
      print('Screen got focus - refreshing data');
      _refreshData();
    }
    _isFirstLoad = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('App resumed - refreshing data');
      _refreshData();
    }
    if (_isOnChatListScreen) {
      _startPeriodicRefresh();
    } else if (state == AppLifecycleState.paused) {
      // Stop timer when app goes to background
      _stopPeriodicRefresh();
    }
  }

  void _refreshData() {
    // Refresh all data here
    _socketService.getChattedUsers(widget.currentUserId);
    _socketService.getUnreadCounts(widget.currentUserId);
    _socketService.getUserStatus();
    _fetchBlockedUsers();
    // Fetch user profiles
    if (_chatUsers.isNotEmpty) {
      _fetchUserProfiles(_chatUsers);
    }
  }

  void _fetchUserProfiles(List<String> userIds) async {
    for (final userId in userIds) {
      try {
        // Replace this with your actual PocketBase fetch code
        // This is a placeholder based on your data structure
        final userData = await fetchUserFromPocketBase(userId);

        if (userData != null) {
          setState(() {
            _userProfiles[userId] = userData;
          });
        }
      } catch (e) {
        print('Error fetching profile for user $userId: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> fetchUserFromPocketBase(String userId) async {
    try {
      // Replace with your actual PocketBase URL
      const baseUrl = 'http://145.223.21.62:8090';

      // Make HTTP request to fetch user data
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/users/records/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('👤 Fetched user data for user $userId: $data');
        // Process the profile image URL
        String? profileImageUrl;
        if (data['avatar'] != null && data['avatar'].toString().isNotEmpty) {
          // Construct the full URL for the profile image
          profileImageUrl =
              '$baseUrl/api/files/users/${data['id']}/${data['avatar']}';
        }

        // Return user data with the proper image URL
        return {
          "id": data['id'],
          "firstname": data['firstname'] ?? '',
          "lastname": data['lastname'] ?? '',
          "phonenumber": data['phonenumber'] ?? 0,
          "moto": data['moto'] ?? '',
          "bio": data['bio'] ?? '',
          "wallet": data['wallet'] ?? 0,
          "country": data['country'] ?? '',
          "gender": data['gender'] ?? '',
          "birthday": data['birthday'] ?? '',
          "avatar": profileImageUrl,
        };
      } else {
        print(
            'Failed to fetch user $userId. Status code: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception fetching user $userId: $e');
      return null;
    }
  }

  void _loadAllChatHistory() {
    print('🔍 Current user ID: ${widget.currentUserId}');

    // Make sure current user ID is valid before requesting
    if (widget.currentUserId.isEmpty) {
      print('❌ ERROR: Current user ID is empty!');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    print('📤 Loading chat history for: ${widget.currentUserId}');

    // Hardcoded list of potential users to check for chat history
    // This is a workaround for now - you can extend this list with known users
    // or implement a proper user discovery mechanism in the future
    final potentialUsers = [
      '8fq57hv3qkfidjt',
      'yxd2ekx4n54tfun',
      'user5',
      'user6',
      'user7',
      'user8',
      'user9',
      'user10',
      'user11',
      'user12'
    ];

    // Filter out current user
    final usersToCheck =
        potentialUsers.where((id) => id != widget.currentUserId).toList();

    print(
        '🔄 Checking chat history with ${usersToCheck.length} potential users');

    // Request chat history for all potential users
    for (final userId in usersToCheck) {
      _socketService.getChatHistory(widget.currentUserId, userId, limit: 10);
    }

    // If we don't hear back in 5 seconds or don't find any chats, stop showing loading state
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        if (_chatUsers.isEmpty) {
          print('⏱️ Timeout waiting for chat history - no conversations found');
        } else {
          print('✅ Found ${_chatUsers.length} conversations after timeout');
        }
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _socketService.onChattedUsers = null;
    _socketService.onUserBlocked = null;
    _socketService.onUserUnblocked = null;
    // Dispose the TabController
    _tabController.removeListener(() {});
    _tabController.dispose();
    // Don't disconnect here as we will reuse the connection
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: Scaffold(
        body: _buildChatsTab(),
        // floatingActionButton: FloatingActionButton(
        //   onPressed: () => _showNewChatDialog(),
        //   child: const Icon(Icons.chat),
        // ),
        appBar: AppBar(
          title: const Text('Chats'),
          actions: [
            ChatRequestIndicator(userId: widget.currentUserId),
            const SizedBox(width: 12),
            // Your other actions like search
          ],
          // rest of the AppBar properties
        ),
      ),
    );
  }

  void _showNewChatDialog() {
    // This would show a dialog with a list of users to start a new chat with
    // You'll need to implement a method to fetch all users from your backend
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new chat'),
        content: const Text(
            'This feature will be implemented to show all available users'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    if (_isLoading || _isLoadingBlockedUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter out blocked users from the chat list
    final filteredChatUsers =
        _chatUsers.where((userId) => !_blockedUsers.contains(userId)).toList();

    // Your existing chat list building code, but use filteredChatUsers instead of _chatUsers
    if (filteredChatUsers.isEmpty) {
      return const Center(
        child: Text('No conversations available'),
      );
    }

    // Sort the filtered list
    _sortFilteredChatUsers(filteredChatUsers);

    return ListView(
      children: [
        // Regular users section
        if (filteredChatUsers.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'CHATS',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          ...filteredChatUsers.map((userId) => _buildUserChatItem(userId)),
        ],
      ],
    );
  }

  void _sortFilteredChatUsers(List<String> users) {
    users.sort((a, b) {
      // Get timestamps for the latest messages from both users
      final aTimestamp = _latestMessages[a]?.timestamp ?? 0;
      final bTimestamp = _latestMessages[b]?.timestamp ?? 0;

      // Sort in descending order (newest first)
      return bTimestamp.compareTo(aTimestamp);
    });
  }

  Widget _buildUserChatItem(String userId) {
    final isOnline = _userStatus[userId]?['online'] ?? false;
    final unreadCount = _unreadCounts[userId] ?? 0;
    final hasLatestMessage = _latestMessages.containsKey(userId);
    final latestMessage = hasLatestMessage ? _latestMessages[userId]! : null;

    // Get profile data if available
    final hasProfile = _userProfiles.containsKey(userId);
    final profileData = hasProfile ? _userProfiles[userId] : null;

    // Get display name from profile or use userId as fallback
    final String displayName = hasProfile
        ? "${profileData['firstname']} ${profileData['lastname']}"
        : userId;

    // Get profile image URL if available
    final String? profileImageUrl = hasProfile ? profileData['avatar'] : null;

    return ListTile(
      leading: Stack(
        children: [
          // Use profile image if available, otherwise show initials
          profileImageUrl != null && profileImageUrl.isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(profileImageUrl),
                  backgroundColor: Colors.grey.shade300,
                )
              : CircleAvatar(
                  backgroundColor: Colors.grey.shade300,
                  child: Text(
                    displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: hasLatestMessage
          ? Text(
              latestMessage!.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight:
                    unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                color: unreadCount > 0 ? Colors.black : Colors.grey.shade700,
              ),
            )
          : Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                color: isOnline ? Colors.green : Colors.grey,
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show timestamp
          if (hasLatestMessage)
            Text(
              _formatTimestamp(latestMessage!.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: unreadCount > 0 ? Colors.green : Colors.grey.shade600,
                fontWeight:
                    unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          // Show unread count in WhatsApp style
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors
                      .white, // Standard WhatsApp uses white text on green
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        _socketService.markMessagesAsRead(widget.currentUserId, userId);
        setState(() {
          _unreadCounts[userId] = 0;
        });
        _isOnChatListScreen = false;
        _stopPeriodicRefresh();
        HomeScreen.setBottomBarVisibility(false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DemoChattingMessageListPage(
              currentUserId: widget.currentUserId,
              receiverId: userId,
              receiverName: displayName,
              receiverProfileUrl: profileImageUrl,
            ),
          ),
        ).then((_) {
          print('Returned from chat screen - refreshing data');
          setState(() {
            _isLoading = true; // Show loading indicator
          });
          HomeScreen.setBottomBarVisibility(true);
          _isOnChatListScreen = true;
          // Force widget rebuild and data refresh
          _socketService.getChattedUsers(widget.currentUserId);
          _socketService.getUnreadCounts(widget.currentUserId);
          _socketService.getUserStatus();
          _fetchBlockedUsers();
          _startPeriodicRefresh();
          // Also refresh the specific chat history
          _socketService.getChatHistory(widget.currentUserId, userId, limit: 1);
        });
      },
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}

class ChatRequestIndicator extends StatefulWidget {
  final String userId;

  const ChatRequestIndicator({
    super.key,
    required this.userId,
  });

  @override
  _ChatRequestIndicatorState createState() => _ChatRequestIndicatorState();
}

class _ChatRequestIndicatorState extends State<ChatRequestIndicator> {
  final SocketService _socketService = SocketService();
  int _pendingRequests = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
    _loadPendingRequests();
  }

  void _setupSocketListeners() {
    _socketService.onChatRequestsList = (requests) {
      setState(() {
        _pendingRequests = requests.length;
        _isLoading = false;
      });
    };

    _socketService.onChatRequestReceived = (request) {
      if (request.receiverId == widget.userId && request.status == 'pending') {
        setState(() {
          _pendingRequests++;
        });

        // Show a notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New chat request from ${request.senderName}'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRequestScreen(
                      currentUserId: widget.userId,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    };

    _socketService.onChatRequestUpdated = (request) {
      if (request.status != 'pending' && request.receiverId == widget.userId) {
        // Refresh the count when a request is approved/rejected
        _loadPendingRequests();
      }
    };
  }

  void _loadPendingRequests() {
    _socketService.getPendingChatRequests(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRequestScreen(
              currentUserId: widget.userId,
            ),
          ),
        ).then((_) {
          // Refresh count when returning from the requests screen
          _loadPendingRequests();
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.person_add),
          if (_pendingRequests > 0)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  _pendingRequests > 9 ? '9+' : _pendingRequests.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
