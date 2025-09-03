import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leo_app_01/HomeScreen.dart';
import 'package:leo_app_01/chat/chatting.dart';
import '../services/socket_service.dart';
import '../models/message.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/chat_request_screen.dart';
import '../widgets/custom_call_button.dart';

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
  final List<String> _chatUsers = [];
  final Map<String, Message> _latestMessages = {};
  final Map<String, dynamic> _userProfiles = {};
  bool _isLoading = true;
  bool _hasInitialDataLoaded = false; // Add this flag
  final Map<String, int> _unreadCounts = {};

  late TabController _tabController;
  final FocusNode _focusNode = FocusNode();
  bool _isFirstLoad = true;
  Timer? _refreshTimer;
  bool _isOnChatListScreen = true;

  final List<String> _blockedUsers = [];
  bool _isLoadingBlockedUsers = true;

  // Add a timeout for initial data loading
  Timer? _initialLoadTimeout;

  void _startPeriodicRefresh() {
    _stopPeriodicRefresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isOnChatListScreen && mounted && _hasInitialDataLoaded) {
        print('📊 Periodic refresh: Updating chat list');
        _socketService.getChattedUsers(widget.currentUserId);
        _socketService.getUnreadCounts(widget.currentUserId);
        _socketService.getUserStatus();
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

  void _startInitialLoadTimeout() {
    _initialLoadTimeout = Timer(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        print('⏱️ Initial load timeout - showing current data');
        setState(() {
          _isLoading = false;
          _hasInitialDataLoaded = true;
        });
        _startPeriodicRefresh();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_onFocusChange);

    _tabController = TabController(length: 1, vsync: this);

    // Start the timeout for initial loading
    _startInitialLoadTimeout();

    _setupSocketListeners();
    _fetchBlockedUsers();
    _initializeData();
  }

  void _setupSocketListeners() {
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

    _socketService.onChattedUsers = (List<String> userIds) {
      print('📦 RECEIVED chatted users: $userIds');
      setState(() {
        _chatUsers.clear();
        _chatUsers.addAll(userIds);
        if (!_hasInitialDataLoaded) {
          _isLoading = false;
          _hasInitialDataLoaded = true;
          _startPeriodicRefresh();
        }
      });
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

    _socketService.onUserStatus = (Map<String, dynamic> statusMap) {
      print('👤 Received user status update: $statusMap');
      setState(() {
        _userStatus.addAll(statusMap);
      });
    };

    _socketService.onNewMessage = (message) {
      setState(() {
        if (message.receiverId == widget.currentUserId ||
            message.senderId == widget.currentUserId) {
          String otherUserId = message.senderId == widget.currentUserId
              ? message.receiverId
              : message.senderId;

          if (!_chatUsers.contains(otherUserId)) {
            _chatUsers.add(otherUserId);
          }

          _latestMessages[otherUserId] = message;

          if (message.receiverId == widget.currentUserId &&
              message.senderId != widget.currentUserId) {
            _unreadCounts[message.senderId] =
                (_unreadCounts[message.senderId] ?? 0) + 1;
            print(
                'Unread count for ${message.senderId}: ${_unreadCounts[message.senderId]}');
          }

          _sortChatUsers();
        }
      });
    };

    _socketService.onConnect = () {
      print("Socket connected, now requesting data");
      _requestInitialData();
    };

    _socketService.onChatHistory = (messages) {
      if (messages.isEmpty) {
        return;
      }

      final message = messages.first;
      final otherUserId = message.senderId == widget.currentUserId
          ? message.receiverId
          : message.senderId;

      print(
          '📱 Got chat history with: $otherUserId (${messages.length} messages)');

      if (!_chatUsers.contains(otherUserId)) {
        setState(() {
          _chatUsers.add(otherUserId);
        });
      }

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
          _sortChatUsers();
        });
      }
    };
  }

  void _initializeData() {
    if (!_socketService.isConnected) {
      print("Connecting socket for user: ${widget.currentUserId}");
      _socketService.connect(widget.currentUserId);
    } else {
      _requestInitialData();
    }
  }

  void _requestInitialData() {
    print("🚀 Requesting initial data for: ${widget.currentUserId}");
    _socketService.getChattedUsers(widget.currentUserId);
    _socketService.getUnreadCounts(widget.currentUserId);
    _socketService.getUserStatus();
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

  void _sortChatUsers() {
    setState(() {
      _chatUsers.sort((a, b) {
        final aTimestamp = _latestMessages[a]?.timestamp ?? 0;
        final bTimestamp = _latestMessages[b]?.timestamp ?? 0;
        return bTimestamp.compareTo(aTimestamp);
      });
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_isFirstLoad && _hasInitialDataLoaded) {
      print('Screen got focus - refreshing data');
      _refreshData();
    }
    _isFirstLoad = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasInitialDataLoaded) {
      print('App resumed - refreshing data');
      _refreshData();
    }
    if (_isOnChatListScreen && _hasInitialDataLoaded) {
      _startPeriodicRefresh();
    } else if (state == AppLifecycleState.paused) {
      _stopPeriodicRefresh();
    }
  }

  void _refreshData() {
    _socketService.getChattedUsers(widget.currentUserId);
    _socketService.getUnreadCounts(widget.currentUserId);
    _socketService.getUserStatus();
    _fetchBlockedUsers();
    if (_chatUsers.isNotEmpty) {
      _fetchUserProfiles(_chatUsers);
    }
  }

  void _fetchUserProfiles(List<String> userIds) async {
    for (final userId in userIds) {
      try {
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
      const baseUrl = 'http://145.223.21.62:8090';
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/users/records/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('👤 Fetched user data for user $userId: $data');
        String? profileImageUrl;
        if (data['avatar'] != null && data['avatar'].toString().isNotEmpty) {
          profileImageUrl =
              '$baseUrl/api/files/users/${data['id']}/${data['avatar']}';
        }

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
        return null;
      }
    } catch (e) {
      print('Exception fetching user $userId: $e');
      return null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _initialLoadTimeout?.cancel();
    _stopPeriodicRefresh();
    _socketService.onChattedUsers = null;
    _socketService.onUserBlocked = null;
    _socketService.onUserUnblocked = null;
    _tabController.removeListener(() {});
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: Scaffold(
        body: _buildChatsTab(),
      ),
    );
  }

  void _showNewChatDialog() {
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
    // Show loading only during initial load and if blocked users are still loading
    if (_isLoading && !_hasInitialDataLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // If still loading blocked users but have chat data, show chat list
    final filteredChatUsers = _isLoadingBlockedUsers
        ? _chatUsers // Show all users while loading blocked list
        : _chatUsers
            .where((userId) => !_blockedUsers.contains(userId))
            .toList();

    if (filteredChatUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start a conversation to see it here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    _sortFilteredChatUsers(filteredChatUsers);

    return ListView(
      children: [
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
      final aTimestamp = _latestMessages[a]?.timestamp ?? 0;
      final bTimestamp = _latestMessages[b]?.timestamp ?? 0;
      return bTimestamp.compareTo(aTimestamp);
    });
  }

  Widget _buildUserChatItem(String userId) {
    final isOnline = _userStatus[userId]?['online'] ?? false;
    final unreadCount = _unreadCounts[userId] ?? 0;
    final hasLatestMessage = _latestMessages.containsKey(userId);
    final latestMessage = hasLatestMessage ? _latestMessages[userId]! : null;

    final hasProfile = _userProfiles.containsKey(userId);
    final profileData = hasProfile ? _userProfiles[userId] : null;

    final String displayName = hasProfile
        ? "${profileData['firstname']} ${profileData['lastname']}"
        : userId;

    final String? profileImageUrl = hasProfile ? profileData['avatar'] : null;

    return ListTile(
      leading: Stack(
        children: [
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasLatestMessage)
                Text(
                  _formatTimestamp(latestMessage!.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        unreadCount > 0 ? Colors.green : Colors.grey.shade600,
                    fontWeight:
                        unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
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
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          CallButtons(
            currentUserId: widget.currentUserId,
            targetUserId: userId,
            name: displayName,
            image: profileImageUrl ?? '',
            showAudioOnly: true,
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
          HomeScreen.setBottomBarVisibility(true);
          _isOnChatListScreen = true;
          _refreshData();
          _startPeriodicRefresh();
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
