import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'live_page.dart';
import 'setadmin.dart';
import 'dismissadmin.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MemberListScreen extends StatefulWidget {
  final String voiceRoomId;
  final String currentUserId;
  final bool isJoined;

  const MemberListScreen({
    super.key,
    required this.voiceRoomId,
    required this.currentUserId,
    required this.isJoined,
  });

  @override
  _MemberListScreenState createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> usersList = [];
  Map<String, dynamic>? roomData;
  Map<String, dynamic>? ownerData;
  bool isLoading = true;
  String? ownerId;
  List<String> adminIds = [];

  final String baseUrl = 'http://145.223.21.62:8090';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      setState(() => isLoading = true);

      // Fetch room data and joined users data in parallel
      final futures = await Future.wait([
        http.get(Uri.parse(
            '$baseUrl/api/collections/voiceRooms/records/${widget.voiceRoomId}')),
        http.get(Uri.parse(
            '$baseUrl/api/collections/joined_users/records?filter=(voice_room_id="${widget.voiceRoomId}")')),
      ]);

      final roomResponse = futures[0];
      final joinedUsersResponse = futures[1];

      // Process room data
      if (roomResponse.statusCode == 200) {
        roomData = json.decode(roomResponse.body);
        ownerId = roomData?['ownerId'];

        // Fetch owner details if available
        if (ownerId != null) {
          final ownerResponse = await http.get(
            Uri.parse('$baseUrl/api/collections/users/records/$ownerId'),
          );
          if (ownerResponse.statusCode == 200) {
            ownerData = json.decode(ownerResponse.body);
          }
        }
      }

      // Process joined users
      if (joinedUsersResponse.statusCode == 200) {
        final joinedUsersData = json.decode(joinedUsersResponse.body);
        final joinedUsers = joinedUsersData['items'] as List;

        // Get admin IDs
        adminIds = joinedUsers
            .where((user) => user['admin_or_not'] == true)
            .map((user) => user['userid'] as String)
            .toList();

        // Get unique user IDs (excluding owner)
        final userIds = joinedUsers
            .where((user) => user['userid'] != ownerId)
            .map((user) => user['userid'])
            .toSet()
            .toList();

        // Fetch all user details in parallel
        if (userIds.isNotEmpty) {
          final userFutures = userIds
              .map((userId) => http.get(
                  Uri.parse('$baseUrl/api/collections/users/records/$userId')))
              .toList();

          final userResponses = await Future.wait(userFutures);

          final users = List<Map<String, dynamic>>.empty(growable: true);

          for (var i = 0; i < userResponses.length; i++) {
            if (userResponses[i].statusCode == 200) {
              final userData = json.decode(userResponses[i].body);
              final joinedUser = joinedUsers.firstWhere(
                (user) => user['userid'] == userIds[i],
                orElse: () => null,
              );

              if (joinedUser != null) {
                users.add({
                  ...userData,
                  'isAdmin': joinedUser['admin_or_not'],
                  'joinedUserId': joinedUser['id'],
                });
              }
            }
          }

          // Sort users: admins first, then regular users
          users.sort((a, b) {
            if (a['isAdmin'] && !b['isAdmin']) return -1;
            if (!a['isAdmin'] && b['isAdmin']) return 1;
            return 0;
          });

          setState(() {
            usersList = users;
            isLoading = false;
          });
        } else {
          setState(() {
            usersList = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
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

  Future<void> _leaveRoom(String userId, String joinedUserId) async {
    try {
      // Delete from joined_users
      final response = await http.delete(
        Uri.parse(
            '$baseUrl/api/collections/joined_users/records/$joinedUserId'),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context); // Close the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully left the room')),
        );
      }
    } catch (e) {
      print('Error leaving room: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to leave room')),
      );
    }
  }

  Future<void> _leaving() async {
    try {
      Map<String, dynamic>? currentUser;
      try {
        currentUser = usersList.firstWhere(
          (user) => user['id'] == widget.currentUserId,
        );
      } catch (e) {
        currentUser = null;
      }

      if (currentUser != null) {
        final response = await http.delete(
          Uri.parse(
              '$baseUrl/api/collections/joined_users/records/${currentUser['joinedUserId']}'),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully left the room'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error leaving room: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to leave room'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> updateEndTime(String userId, String voiceRoomId) async {
    try {
      final filter = Uri.encodeComponent(
          'UserID="$userId" && voiceRoom_id="$voiceRoomId"');
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/collections/level_Timer/records?filter=$filter'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['items'] ?? [];
        final record = records.firstWhere(
          (r) => r['End_Time'] == null || r['End_Time'] == "",
          orElse: () => null,
        );

        if (record != null) {
          await http.patch(
            Uri.parse(
                '$baseUrl/api/collections/level_Timer/records/${record['id']}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'End_Time': DateTime.now().toIso8601String(),
            }),
          );
        }
      }
    } catch (e) {
      print('Error updating end time: $e');
    }
  }

  Future<void> _joinRoom(String roomId, String userId) async {
    try {
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

  Future<void> removeUser(String userId, String joinedUserId) async {
    // Check permissions
    if (widget.currentUserId != ownerId &&
        !adminIds.contains(widget.currentUserId)) return;

    if (userId == ownerId) return; // Can't remove owner
    if (adminIds.contains(userId) && widget.currentUserId != ownerId)
      return; // Admins can't remove other admins

    try {
      // Add to removed_users
      final removeResponse = await http.post(
        Uri.parse('$baseUrl/api/collections/removed_users/records'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'voice_room_id': widget.voiceRoomId,
          'user_id': userId,
        }),
      );

      if (removeResponse.statusCode == 200) {
        // Delete from joined_users
        await http.delete(
          Uri.parse(
              '$baseUrl/api/collections/joined_users/records/$joinedUserId'),
        );

        loadData(); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User removed successfully')),
        );
      }
    } catch (e) {
      print('Error removing user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove user')),
      );
    }
  }

  Widget _buildOwnerProfile() {
    if (ownerData == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: CachedNetworkImage(
            imageUrl:
                "$baseUrl/api/files/${ownerData!['collectionId']}/${ownerData!['id']}/${ownerData!['avatar']}",
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.person,
                color: Colors.grey[400],
              ),
            ),
          ),
        ),
        title: Text(
          ownerData!['firstname'] ?? "Unknown",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          ownerData!['bio'] ?? "No bio available",
          style: const TextStyle(fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.person,
          color: Colors.amber,
          size: 35,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUserAdmin = adminIds.contains(widget.currentUserId);
    final isCurrentUserOwner = widget.currentUserId == ownerId;

    return Column(
      children: [
        // Search and Settings Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or ID',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ),
              // Leave Room Text with Three Dots Menu
              if (widget.isJoined && !isCurrentUserAdmin && !isCurrentUserOwner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    // Replace the leave logic section with this corrected version
                    if (value == 'leave') {
                      // Show confirmation dialog
                      final shouldLeave = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Leave Room'),
                          content: const Text(
                              'Are you sure you want to leave this room?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                _deleteDuplicateOnlineUserRecords(
                                    widget.currentUserId, widget.voiceRoomId);
                                _leaving();
                                print('Leave button pressed'); // Debug log
                                Navigator.pop(
                                    context, true); // Close the dialog
                                // Try to get the parent context
                                final parentContext = context
                                    .findAncestorStateOfType<LivePageState>()
                                    ?.context;
                                if (parentContext != null) {
                                  print('Found parent context'); // Debug log
                                  LivePage.handleLogout(parentContext);
                                } else {
                                  print(
                                      'Parent context not found, using current context'); // Debug log
                                  LivePage.handleLogout(context);
                                }
                                Navigator.of(context, rootNavigator: true)
                                    .pop(); // Close member list sheet
                              },
                              child: const Text('Leave',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (shouldLeave == true) {}
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'leave',
                      child: Row(
                        children: [
                          SizedBox(width: 8),
                          Text('Leave Room',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              if (widget.currentUserId == ownerId)
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showSettingsDialog,
                ),
            ],
          ),
        ),

        // Members List with Owner Profile at top
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  children: [
                    _buildOwnerProfile(),
                    ...usersList.map((user) {
                      if (searchController.text.isNotEmpty &&
                          !user['firstname']
                              .toString()
                              .toLowerCase()
                              .contains(searchController.text.toLowerCase()) &&
                          !user['id']
                              .toString()
                              .toLowerCase()
                              .contains(searchController.text.toLowerCase())) {
                        return const SizedBox.shrink();
                      }

                      final isAdmin = user['isAdmin'] == true;
                      final isCurrentUser = widget.currentUserId == user['id'];
                      final isOwner = user['id'] == ownerId;

                      return Container(
                        height: 70,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAdmin)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      "$baseUrl/api/files/${user['collectionId']}/${user['id']}/${user['avatar']}",
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: Colors.grey[300],
                                    child: Icon(Icons.person,
                                        color: Colors.grey[400]),
                                  ),
                                ),
                              ),
                            ],
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((widget.currentUserId == ownerId ||
                                      (adminIds
                                              .contains(widget.currentUserId) &&
                                          !isAdmin)) &&
                                  widget.currentUserId != user['id'])
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red),
                                  onPressed: () => removeUser(
                                      user['id'], user['joinedUserId']),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),

        // Empty container at bottom (previously join button)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar at top
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            const Text(
              'Room Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Set Admin Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_add, color: Colors.blue),
              ),
              title: const Text('Set Admin'),
              subtitle: const Text('Promote a member to admin'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SetAdminScreen(
                      voiceRoomId: widget.voiceRoomId,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Dismiss Admin Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_remove, color: Colors.red),
              ),
              title: const Text('Dismiss Admin'),
              subtitle: const Text('Remove admin privileges'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DismissAdminScreen(
                      voiceRoomId: widget.voiceRoomId,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
