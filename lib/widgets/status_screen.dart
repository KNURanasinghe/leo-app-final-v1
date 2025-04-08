import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/status_model.dart';
import '../services/socket_service.dart';
import '../constants/app_constants.dart';
import 'status_create_screen.dart';
import 'status_view_screen.dart';

// Custom blue color theme
class StatusTheme {
  static const Color primaryBlue = Color(0xFF2962FF);
  static const Color lightBlue = Color(0xFF82B1FF);
  static const Color darkBlue = Color(0xFF0039CB);
  static const Color accentBlue = Color(0xFF448AFF);
  static const Color backgroundBlue = Color(0xFFE3F2FD);
  static const Color cardBlue = Color(0xFFBBDEFB);
  static const Color textDark = Color(0xFF1A237E);
  static const Color textLight = Color(0xFF5C6BC0);
}

class StatusScreen extends StatefulWidget {
  final String currentUserId;

  const StatusScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  List<StatusUser> _statusUsers = [];
  Map<String, UserProfile> _userProfiles = {};
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final String _pocketbaseUrl = 'http://145.223.21.62:8090';
  String? username;
  String? profileImg;

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
    _loadStatuses();

    // Setup animation for status rings
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupSocketListeners() {
    _socketService.onActiveStatuses = (users) async {
      // Fetch user profiles for all status users
      await _fetchUserProfiles(users.map((user) => user.userId).toList());

      setState(() {
        _statusUsers = users;
        _isLoading = false;
      });
    };
  }

  Future<void> _fetchUserProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return;

    Map<String, UserProfile> profiles = {};

    for (final userId in userIds) {
      try {
        final response = await http.get(
          Uri.parse('$_pocketbaseUrl/api/collections/users/records/$userId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final userData = json.decode(response.body);
          profiles[userId] = UserProfile(
            id: userId,
            name: userData['firstname'] ?? 'Unknown User',
            avatarUrl: userData['avatar'] != null
                ? '$_pocketbaseUrl/api/files/users/$userId/${userData['avatar']}'
                : null,
          );
          setState(() {
            username = userData['firstname'] ?? 'Unknown User';
            profileImg = userData['avatar'] != null
                ? '$_pocketbaseUrl/api/files/users/$userId/${userData['avatar']}'
                : null;
          });
        } else {
          print(
              'Failed to fetch profile for user $userId: ${response.statusCode}');
          profiles[userId] = UserProfile(
            id: userId,
            name: 'User $userId',
          );
        }
      } catch (e) {
        print('Error fetching user profile $userId: $e');
        profiles[userId] = UserProfile(
          id: userId,
          name: 'User $userId',
        );
      }
    }

    setState(() {
      _userProfiles = profiles;
    });
  }

  void _loadStatuses() {
    print("Requesting active statuses...");
    setState(() {
      _isLoading = true;
    });
    _socketService.getActiveStatuses();
  }

  void _createStatus() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatusCreateScreen(
          currentUserId: widget.currentUserId,
        ),
      ),
    );

    if (result == true) {
      // Refresh statuses after creating a new one
      _loadStatuses();
    }
  }

  void _viewUserStatus(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatusViewScreen(
          currentUserId: widget.currentUserId,
          statusUserId: userId,
          userName: username,
          imageUrl: profileImg ?? '',
        ),
      ),
    );
  }

  bool _hasMyStatus() {
    return _statusUsers.any((user) => user.userId == widget.currentUserId);
  }

  StatusUser? _getMyStatusUser() {
    try {
      return _statusUsers
          .firstWhere((user) => user.userId == widget.currentUserId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: StatusTheme.backgroundBlue,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue[700],
        title: const Text(
          'Status Updates',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStatuses,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Status list
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(StatusTheme.primaryBlue),
                  ),
                )
              : ListView(
                  children: [
                    // Header
                    // Container(
                    //   padding: const EdgeInsets.symmetric(
                    //       vertical: 8, horizontal: 8),
                    //   decoration: const BoxDecoration(
                    //     color: StatusTheme.primaryBlue,
                    //     borderRadius: BorderRadius.only(
                    //       bottomLeft: Radius.circular(20),
                    //       bottomRight: Radius.circular(20),
                    //     ),
                    //   ),
                    //   child: const Text(
                    //     'Share moments with friends',
                    //     textAlign: TextAlign.center,
                    //     style: TextStyle(
                    //       color: Colors.white,
                    //       fontSize: 14,
                    //       fontWeight: FontWeight.w500,
                    //     ),
                    //   ),
                    // ),

                    const SizedBox(height: 16),

                    // My status
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      elevation: 2,
                      shadowColor: StatusTheme.lightBlue.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Stack(
                          children: [
                            _hasMyStatus()
                                ? AnimatedBuilder(
                                    animation: _animation,
                                    builder: (context, child) {
                                      return Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              StatusTheme.accentBlue,
                                              StatusTheme.lightBlue,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(50),
                                          boxShadow: [
                                            BoxShadow(
                                              color: StatusTheme.accentBlue
                                                  .withOpacity(0.5),
                                              spreadRadius: _animation.value,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 22,
                                          backgroundColor: Colors.white,
                                          child: _buildUserAvatar(
                                            widget.currentUserId,
                                            radius: 20,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : CircleAvatar(
                                    radius: 25,
                                    backgroundColor: StatusTheme.lightBlue,
                                    child: _buildUserAvatar(
                                      widget.currentUserId,
                                      radius: 23,
                                      showDefaultIcon: true,
                                    ),
                                  ),
                            if (!_hasMyStatus())
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: StatusTheme.accentBlue,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: StatusTheme.accentBlue
                                            .withOpacity(0.5),
                                        spreadRadius: 1,
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          _userProfiles[widget.currentUserId]?.name ??
                              'My Status',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: StatusTheme.textDark,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: _hasMyStatus()
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _getTimeAgo(_getMyStatusUser()!
                                      .latestStatus['timestamp']),
                                  style: const TextStyle(
                                    color: StatusTheme.textLight,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Tap to add status update',
                                  style: TextStyle(
                                    color: StatusTheme.textLight,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                        trailing: _hasMyStatus()
                            ? const Icon(
                                Icons.more_vert_outlined,
                                color: StatusTheme.accentBlue,
                              )
                            : const Icon(
                                Icons.add_circle_outline,
                                color: StatusTheme.accentBlue,
                              ),
                        onTap: () {
                          if (_hasMyStatus()) {
                            _viewUserStatus(widget.currentUserId);
                          } else {
                            _createStatus();
                          }
                        },
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Recent Updates',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: StatusTheme.textDark,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    // Other users' statuses
                    ..._statusUsers
                        .where((user) => user.userId != widget.currentUserId)
                        .map((user) => Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              elevation: 1,
                              shadowColor:
                                  StatusTheme.lightBlue.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: AnimatedBuilder(
                                  animation: _animation,
                                  builder: (context, child) {
                                    return Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            StatusTheme.accentBlue,
                                            StatusTheme.primaryBlue,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(50),
                                        boxShadow: [
                                          BoxShadow(
                                            color: StatusTheme.accentBlue
                                                .withOpacity(0.3),
                                            spreadRadius: _animation.value,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.white,
                                        child: _buildUserAvatar(
                                          user.userId,
                                          radius: 20,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                title: Text(
                                  _userProfiles[user.userId]?.name ??
                                      'User ${user.userId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: StatusTheme.textDark,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _getTimeAgo(user.latestStatus['timestamp']),
                                    style: const TextStyle(
                                      color: StatusTheme.textLight,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: StatusTheme.accentBlue,
                                  size: 16,
                                ),
                                onTap: () => _viewUserStatus(user.userId),
                              ),
                            )),

                    if (_statusUsers.isEmpty ||
                        (_statusUsers.length == 1 &&
                            _statusUsers[0].userId == widget.currentUserId))
                      Container(
                        margin: const EdgeInsets.all(32.0),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: StatusTheme.lightBlue.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: StatusTheme.textLight,
                              size: 40,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No status updates from other users',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: StatusTheme.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to share a status with your friends',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: StatusTheme.textLight.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 70), // Space for FAB
                  ],
                ),

          // FAB for creating status
          Positioned(
            right: 20,
            bottom: 20,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: StatusTheme.darkBlue.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
                borderRadius: BorderRadius.circular(30),
              ),
              child: FloatingActionButton(
                onPressed: _createStatus,
                backgroundColor: StatusTheme.darkBlue,
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String userId,
      {double radius = 20, bool showDefaultIcon = false}) {
    final userProfile = _userProfiles[userId];

    if (userProfile?.avatarUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: userProfile!.avatarUrl!,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          placeholder: (context, url) => Container(
            color: StatusTheme.textLight,
            child: Center(
              child: SizedBox(
                width: radius * 0.8,
                height: radius * 0.8,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            backgroundColor: StatusTheme.textLight,
            radius: radius,
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: radius * 1.2,
            ),
          ),
        ),
      );
    } else {
      return CircleAvatar(
        backgroundColor: showDefaultIcon ? StatusTheme.textLight : Colors.white,
        radius: radius,
        child: Icon(
          Icons.person,
          color: showDefaultIcon ? Colors.white : StatusTheme.textLight,
          size: radius * 1.2,
        ),
      );
    }
  }

  String _getTimeAgo(int timestamp) {
    final now = DateTime.now();
    final statusTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(statusTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return 'Yesterday';
    }
  }
}

// User profile model class
class UserProfile {
  final String id;
  final String name;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
  });
}
