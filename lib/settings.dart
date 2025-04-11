// settings_page.dart
import 'package:flutter/material.dart';
import 'package:leo_app_01/policy.dart';
import 'package:leo_app_01/services/api_service.dart';
import 'package:leo_app_01/services/socket_service.dart';
import 'package:leo_app_01/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // Define dark theme colors
  static const Color backgroundColor = Colors.white;
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryTextColor = Colors.black;
  static const Color dangerColor = Color(0xFFCF6679);
  static const Color dividerColor = Color(0xFF2C2C2C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingTile(
            context,
            icon: Icons.person_outline,
            title: 'Profile Settings',
            onTap: () => _navigateToPage(context, 'Profile Settings'),
          ),
          _buildSettingTile(
            context,
            icon: Icons.lock_outline,
            title: 'Privacy Settings',
            onTap: () => _navigateToPage(context, 'Privacy Settings'),
          ),
          _buildSettingTile(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notification Settings',
            onTap: () =>
                _navigateToNotificationPage(context, 'Notification Settings'),
          ),

          const Divider(color: dividerColor),
          // Preferences Section
          _buildSectionHeader('Preferences'),
          _buildSettingTile(
            context,
            icon: Icons.language,
            title: 'Language',
            subtitle: 'English',
            onTap: () => _navigateToPage(context, 'Language Settings'),
          ),
          _buildSwitchTile(
            icon: Icons.location_on_outlined,
            title: 'Location Services',
            value: true,
            onChanged: (bool value) {
              // Implement location services toggle
            },
          ),

          const Divider(color: dividerColor),
          // Security Section
          _buildSectionHeader('Security'),
          _buildSettingTile(
            context,
            icon: Icons.security,
            title: 'Two-Factor Authentication',
            onTap: () => _navigateToPage(context, '2FA Settings'),
          ),
          _buildSettingTile(
            context,
            icon: Icons.block,
            title: 'Blocked Users',
            onTap: () => _navigateToBlockUsersPage(context, 'Blocked Users'),
          ),

          const Divider(color: dividerColor),
          // Legal Section
          _buildSectionHeader('Legal'),
          _buildSettingTile(
            context,
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            onTap: () => _navigateToprivacy(context),
          ),
          _buildSettingTile(
            context,
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () => _navigateToterms(context),
          ),
          _buildSettingTile(
            context,
            icon: Icons.copyright_outlined,
            title: 'Copyright Information',
            onTap: () => _navigateTocopyright(context),
          ),
          _buildSettingTile(
            context,
            icon: Icons.money_outlined,
            title: 'Refund Policy',
            onTap: () => _navigateTorefund(context),
          ),

          const Divider(color: dividerColor),
          // Support Section
          _buildSectionHeader('Support'),
          _buildSettingTile(
            context,
            icon: Icons.help_outline,
            title: 'Help Center',
            onTap: () => _navigateToPage(context, 'Help Center'),
          ),
          _buildSettingTile(
            context,
            icon: Icons.feedback_outlined,
            title: 'Send Feedback',
            onTap: () => _navigateToPage(context, 'Feedback'),
          ),

          const Divider(color: dividerColor),
          // Account Actions
          const SizedBox(height: 16),
          _buildDangerTile(
            context,
            icon: Icons.logout,
            title: 'Log Out',
            onTap: () async {
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.remove('userId'); // Corrected from removeS to remove

              // Optional: Add navigation to login screen or perform additional logout actions
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (context) =>
                        const SplashScreen()), // Replace with your login screen
              );
            },
          ),
          _buildDangerTile(
            context,
            icon: Icons.delete_forever,
            title: 'Delete Account',
            onTap: () async {
              // Show confirmation dialog
              final confirmDelete = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text(
                        'Are you sure you want to permanently delete your account? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );

              // If user doesn't confirm, exit
              if (confirmDelete != true) return;

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  );
                },
              );

              try {
                // Get current user ID from SharedPreferences
                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                final String? userId = prefs.getString('userId');

                if (userId == null) {
                  throw Exception('No user ID found');
                }
                UserApiService apiservice =
                    UserApiService(baseUrl: 'http://145.223.21.62:8090');
                // Delete user from database
                await apiservice.deleteUser(userId);

                // Remove user ID from SharedPreferences
                await prefs.remove('userId');

                // Close loading dialog
                Navigator.of(context, rootNavigator: true).pop();

                // Navigate to Splash screen
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const SplashScreen()),
                  (Route<dynamic> route) => false,
                );
              } catch (e) {
                // Close loading dialog
                Navigator.of(context, rootNavigator: true).pop();

                // Show error dialog
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Account Deletion Failed'),
                      content:
                          Text('Unable to delete account: ${e.toString()}'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );

                // Log the error
                print('Account deletion error: $e');
              }
            },
            isDestructive: true,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                color: secondaryTextColor,
                fontSize: 14,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: secondaryTextColor),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: primaryColor),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: primaryColor,
      inactiveThumbColor: secondaryTextColor,
      inactiveTrackColor: dividerColor,
    );
  }

  Widget _buildDangerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? dangerColor : secondaryTextColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? dangerColor : secondaryTextColor,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }

  void _navigateToPage(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IHaveToCreate(title: title),
      ),
    );
  }

  void _navigateToBlockUsersPage(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlockedUsersPage(title: title),
      ),
    );
  }

  void _navigateToNotificationPage(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Notification(title: title),
      ),
    );
  }

  _navigateToprivacy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyPage(),
      ),
    );
  }

  _navigateToterms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TermsAndConditionsPage(),
      ),
    );
  }

  _navigateTorefund(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RefundPolicyPage(),
      ),
    );
  }

  _navigateTocopyright(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CopyrightPolicyPage(),
      ),
    );
  }
}

// detail_page.dart

class BlockedUsersPage extends StatefulWidget {
  final String title;

  const BlockedUsersPage({
    super.key,
    required this.title,
  });

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final SocketService _socketService = SocketService();
  List<String> _blockedUsers = [];
  Map<String, UserDetails> _userDetailsMap = {};
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeSocketListeners();
    _getCurrentUserAndFetchBlockedList();
  }

  void _initializeSocketListeners() {
    // Set up the callback for receiving blocked users list
    _socketService.onBlockedUsersList = (List<String> blockedUsers) {
      setState(() {
        _blockedUsers = blockedUsers;
        _fetchUserDetails(blockedUsers);
      });
      print('Received blocked users: $_blockedUsers');
    };

    // Set up the callback for when a user is unblocked successfully
    _socketService.onUserUnblocked = (String unblockedUserId) {
      setState(() {
        _blockedUsers.remove(unblockedUserId);
        _userDetailsMap.remove(unblockedUserId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User unblocked successfully'),
          backgroundColor: Colors.green,
        ),
      );
    };
  }

  Future<void> _getCurrentUserAndFetchBlockedList() async {
    // Replace this with your actual method to get current user ID
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? userId = prefs.getString('userId');
    _currentUserId = userId;

    if (_currentUserId != null) {
      _fetchBlockedUsers();
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to get current user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _fetchBlockedUsers() {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    // Request the blocked users list from the server with a callback
    _socketService.getBlockedUsers(_currentUserId!,
        (List<String> blockedUsers) {
      setState(() {
        _blockedUsers = blockedUsers;
        _fetchUserDetails(blockedUsers);
      });
      print('Received blocked users: $blockedUsers');
    });
  }

  // Fetch user details for all blocked users
  Future<void> _fetchUserDetails(List<String> userIds) async {
    if (userIds.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final Map<String, UserDetails> detailsMap = {};
    const String pocketbaseUrl =
        'http://145.223.21.62:8090'; // Replace with your PocketBase URL

    for (final userId in userIds) {
      try {
        final response = await http.get(
          Uri.parse('$pocketbaseUrl/api/collections/users/records/$userId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final userData = json.decode(response.body);
          detailsMap[userId] = UserDetails(
            id: userId,
            name: userData['firstname'] ?? 'Unknown User',
            avatarUrl: userData['avatar'] != null
                ? '$pocketbaseUrl/api/files/users/$userId/${userData['avatar']}'
                : null,
          );
        } else {
          print(
              'Failed to fetch details for user $userId: ${response.statusCode}');
          detailsMap[userId] = UserDetails(
            id: userId,
            name: 'User $userId',
          );
        }
      } catch (e) {
        print('Error fetching user $userId: $e');
        detailsMap[userId] = UserDetails(
          id: userId,
          name: 'User $userId',
        );
      }
    }

    setState(() {
      _userDetailsMap = detailsMap;
      _isLoading = false;
    });
  }

  void _unblockUser(String blockedUserId) {
    if (_currentUserId == null) return;

    // Call the unblock method
    _socketService.unblockUser(_currentUserId!, blockedUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsPage.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchBlockedUsers();
            },
            tooltip: 'Refresh List',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : _blockedUsers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block_flipped,
                        size: 50,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No Blocked Users',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You haven\'t blocked any users yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final blockedUserId = _blockedUsers[index];
                    return _buildBlockedUserCard(blockedUserId);
                  },
                ),
    );
  }

  Widget _buildBlockedUserCard(String blockedUserId) {
    final userDetails = _userDetailsMap[blockedUserId];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: SettingsPage.surfaceColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.grey[800],
          backgroundImage: userDetails?.avatarUrl != null
              ? NetworkImage(userDetails!.avatarUrl!)
              : null,
          child: userDetails?.avatarUrl == null
              ? Icon(
                  Icons.person,
                  color: Colors.grey[300],
                )
              : null,
        ),
        title: Text(
          userDetails?.name ?? 'User $blockedUserId',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'Blocked',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _unblockUser(blockedUserId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Unblock'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clear the callbacks to avoid memory leaks
    _socketService.onBlockedUsersList = null;
    _socketService.onUserUnblocked = null;
    super.dispose();
  }
}

// Model class to store user details
class UserDetails {
  final String id;
  final String name;

  final String? avatarUrl;

  UserDetails({
    required this.id,
    required this.name,
    this.avatarUrl,
  });
}

class Notification extends StatefulWidget {
  final String title;
  const Notification({super.key, required this.title});

  @override
  State<Notification> createState() => _NotificationState();
}

class _NotificationState extends State<Notification> {
  final String baseUrl = 'http://145.223.21.62:8090';
  bool _isSaving = false;
  String userId = ''; // Will be loaded from SharedPreferences
  String authToken = ''; // Will be loaded from SharedPreferences

  // Notification settings
  bool isAllNotificationsOff = false;
  bool isMessageNotificationsOff = false;
  bool isStatusNotificationsOff = false;
  bool isGroupNotificationsOff = false;
  bool isCallNotificationsOff = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userId = prefs.getString('userId') ?? '';
        authToken = prefs.getString('authToken') ?? '';
      });

      if (userId.isNotEmpty) {
        _fetchNotificationSettings();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load user data');
    }
  }

  Future<void> _fetchNotificationSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/users/records/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          // Set the toggle states based on the fetched settings
          isAllNotificationsOff = data['is_notification_off'] ?? false;

          // These would typically come from your database as well
          // For now they'll mirror the main setting or could be set individually
          isMessageNotificationsOff = isAllNotificationsOff;
          isStatusNotificationsOff = isAllNotificationsOff;
          isGroupNotificationsOff = isAllNotificationsOff;
          isCallNotificationsOff = isAllNotificationsOff;
        });
      } else {
        throw Exception('Failed to load notification settings');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load notification settings');
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving || userId.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final body = jsonEncode({
        'is_notification_off': isAllNotificationsOff,
        // You would typically save the individual settings as well if your database has fields for them
        // 'is_message_notification_off': isMessageNotificationsOff,
        // etc.
      });

      final response = await http.patch(
        Uri.parse('$baseUrl/api/collections/users/records/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Notification settings saved successfully');
      } else {
        throw Exception('Failed to save notification settings');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save notification settings');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isSaving
              ? Container(
                  margin: const EdgeInsets.all(8),
                  width: 40,
                  child: const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveSettings,
                  child: const Text(
                    'SAVE',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.withOpacity(0.05),
              child: const Text(
                'Control how and when you receive notifications',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
            _buildMainToggle(),
            const Divider(height: 1),
            // _buildSectionHeader('Message Notifications'),
            // _buildToggleItem(
            //   title: 'Message notifications',
            //   subtitle: 'Receive notifications for new messages',
            //   value: isMessageNotificationsOff,
            //   onChanged: (value) {
            //     setState(() {
            //       isMessageNotificationsOff = value;
            //     });
            //   },
            //   enabled: !isAllNotificationsOff,
            // ),
            // const Divider(height: 1, indent: 72),
            // _buildSectionHeader('Status Notifications'),
            // _buildToggleItem(
            //   title: 'Status updates',
            //   subtitle: 'Get notified when someone posts a new status',
            //   value: isStatusNotificationsOff,
            //   onChanged: (value) {
            //     setState(() {
            //       isStatusNotificationsOff = value;
            //     });
            //   },
            //   enabled: !isAllNotificationsOff,
            // ),
            // const Divider(height: 1, indent: 72),
            // _buildToggleItem(
            //   title: 'Status reactions',
            //   subtitle: 'Get notified when someone reacts to your status',
            //   value: isStatusNotificationsOff,
            //   onChanged: (value) {
            //     setState(() {
            //       isStatusNotificationsOff = value;
            //     });
            //   },
            //   enabled: !isAllNotificationsOff,
            // ),
            // const Divider(height: 1, indent: 72),
            // _buildSectionHeader('Group Notifications'),
            // _buildToggleItem(
            //   title: 'Group messages',
            //   subtitle: 'Receive notifications for group messages',
            //   value: isGroupNotificationsOff,
            //   onChanged: (value) {
            //     setState(() {
            //       isGroupNotificationsOff = value;
            //     });
            //   },
            //   enabled: !isAllNotificationsOff,
            // ),
            // const Divider(height: 1, indent: 72),
            // _buildToggleItem(
            //   title: 'Group invites',
            //   subtitle: 'Get notified about new group invitations',
            //   value: isGroupNotificationsOff,
            //   onChanged: (value) {
            //     setState(() {
            //       isGroupNotificationsOff = value;
            //     });
            //   },
            //   enabled: !isAllNotificationsOff,
            // ),
            // const Divider(height: 1, indent: 72),
            // _buildSectionHeader('Call Notifications'),
            // _buildToggleItem(
            //   title: 'Incoming calls',
            //   subtitle: 'Receive notifications for incoming calls',
            //   value: isCallNotificationsOff,
            //   onChanged: (value) {
            //     setState(() {
            //       isCallNotificationsOff = value;
            //     });
            //   },
            //   enabled: !isAllNotificationsOff,
            // ),
            // const Divider(height: 1, indent: 72),
            // _buildToggleItem(
            //   title: 'Missed calls',
            //   subtitle: 'Get notified about missed calls',
            //   value: isCallNotificationsOff,
            //   onChanged: (value) {
            //     setState(() {
            //       isCallNotificationsOff = value;
            //     });
            //   },
            //   enabled: !isAllNotificationsOff,
            // ),
            // const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMainToggle() {
    return Container(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: const Text(
          'All Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          isAllNotificationsOff
              ? 'All notifications are turned off'
              : 'You will receive notifications',
          style: TextStyle(
            color: isAllNotificationsOff ? Colors.red : Colors.green,
            fontSize: 14,
          ),
        ),
        trailing: Switch(
          value: !isAllNotificationsOff,
          onChanged: (value) {
            setState(() {
              isAllNotificationsOff = !value;

              // If turning all notifications off, also disable individual ones
              if (isAllNotificationsOff) {
                isMessageNotificationsOff = true;
                isStatusNotificationsOff = true;
                isGroupNotificationsOff = true;
                isCallNotificationsOff = true;
              }
            });
          },
          activeColor: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.blue[800],
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        color: Colors.white,
        child: ListTile(
          enabled: enabled,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          trailing: Switch(
            value: !value,
            onChanged: enabled ? (val) => onChanged(!val) : null,
            activeColor: Colors.blue,
          ),
        ),
      ),
    );
  }
}

class IHaveToCreate extends StatefulWidget {
  String title;
  IHaveToCreate({super.key, required this.title});

  @override
  State<IHaveToCreate> createState() => _IHaveToCreateState();
}

class _IHaveToCreateState extends State<IHaveToCreate> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: const Center(child: Text("I Have to Create")),
    );
  }
}
