// new_peer_chat_dialog.dart
part of 'default_dialogs.dart';

// Make sure to import flutter_contacts in your imports section
// import 'package:flutter_contacts/flutter_contacts.dart';

class _UserListItem {
  final String id;
  final String name;
  final String? avatar;
  final String? bio;

  _UserListItem({
    required this.id,
    required this.name,
    this.avatar,
    this.bio,
  });
}

// Update your showDefaultNewPeerChatDialog function to use the chat request flow

void showDefaultNewPeerChatDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    },
  );

  Timer.run(() async {
    try {
      // Request contacts permission using flutter_contacts
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) {
        print('permission not granted');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Contacts permission is required to find your contacts'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get current user ID
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('userId');

      // Fetch users
      final response = await http.get(
        Uri.parse('http://145.223.21.62:8090/api/collections/users/records'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> userItems = data['items'] as List;
        print('Total users from DB: ${userItems.length}');

        // Get contacts from device using flutter_contacts
        List<Contact> contacts = await FlutterContacts.getContacts(
            withProperties: true, withThumbnail: false);
        print('Total contacts found: ${contacts.length}');

        Set<String> contactPhoneNumbers = {};

        // Extract phone numbers from contacts and normalize them
        for (var contact in contacts) {
          for (var phone in contact.phones) {
            if (phone.number.isNotEmpty) {
              // Normalize phone number (remove spaces, dashes, etc.)
              String normalizedNumber =
                  phone.number.replaceAll(RegExp(r'[^\d+]'), '');
              contactPhoneNumbers.add(normalizedNumber);

              // Debug log for phone numbers
              print(
                  'Contact: ${contact.displayName}, Normalized Number: $normalizedNumber');
            }
          }
        }

        print(
            'Total unique phone numbers from contacts: ${contactPhoneNumbers.length}');

        // Filter users whose phone numbers are in contacts
        final List<_UserListItem> filteredUsers = [];

        for (var item in userItems) {
          if (item['id'] == currentUserId) continue;

          // Get the phone number from user data - using the correct field name "phonenumber"
          String? phoneNumber = item['phonenumber']?.toString();

          if (phoneNumber != null && phoneNumber.isNotEmpty) {
            // Sri Lankan numbers may start with "94" instead of "+94", so add the "+" if needed
            if (phoneNumber.startsWith('94') &&
                !phoneNumber.startsWith('+94')) {
              phoneNumber = '+$phoneNumber';
            }

            // Normalize the phone number for comparison
            String normalizedNumber =
                phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
            print(
                'User: ${item['firstname']} ${item['lastname']}, Phone: $normalizedNumber');

            // Check if this number is in contacts with various matching strategies
            bool isInContacts = false;

            for (String contactNumber in contactPhoneNumbers) {
              // Strategy 1: Exact match
              if (normalizedNumber == contactNumber) {
                isInContacts = true;
                print('MATCH FOUND - Exact match: $normalizedNumber');
                break;
              }

              // Strategy 2: Last digits match (for handling country code differences)
              // For Sri Lankan numbers, compare last 9 digits (typical mobile number length)
              final lastDigitsUser = normalizedNumber.length >= 9
                  ? normalizedNumber.substring(normalizedNumber.length - 9)
                  : normalizedNumber;
              final lastDigitsContact = contactNumber.length >= 9
                  ? contactNumber.substring(contactNumber.length - 9)
                  : contactNumber;

              if (lastDigitsUser == lastDigitsContact &&
                  lastDigitsUser.length >= 9) {
                isInContacts = true;
                print(
                    'MATCH FOUND - Last digits match: User=$normalizedNumber, Contact=$contactNumber');
                break;
              }

              // Strategy 3: One ends with the other (original logic)
              if (normalizedNumber.endsWith(contactNumber) ||
                  contactNumber.endsWith(normalizedNumber)) {
                isInContacts = true;
                print(
                    'MATCH FOUND - One ends with other: User=$normalizedNumber, Contact=$contactNumber');
                break;
              }
            }

            if (isInContacts) {
              filteredUsers.add(_UserListItem(
                id: item['id'],
                name: '${item['firstname'] ?? ''} ${item['lastname'] ?? ''}'
                    .trim(),
                avatar: item['avatar'],
                bio: item['bio'],
              ));
              print(
                  'Added ${item['firstname']} ${item['lastname']} to filtered users');
            }
          } else {
            print(
                'User has no phone number: ${item['firstname']} ${item['lastname']}');
          }
        }

        print('Filtered users count: ${filteredUsers.length}');
        Navigator.of(context, rootNavigator: true).pop();

        // Show dialog with filtered users or all users if filter is empty
        if (context.mounted) {
          if (filteredUsers.isEmpty) {
            print('No matches found between contacts and users.');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('No contacts found in your app. Showing all users.'),
                backgroundColor: Colors.orange,
              ),
            );

            // Show all users if no matches found
            final allUsers = userItems
                .where((item) => item['id'] != currentUserId)
                .map((item) => _UserListItem(
                      id: item['id'],
                      name:
                          '${item['firstname'] ?? ''} ${item['lastname'] ?? ''}'
                              .trim(),
                      avatar: item['avatar'],
                      bio: item['bio'],
                    ))
                .toList();

            showDialog<String>(
              useRootNavigator: false,
              context: context,
              builder: (BuildContext context) {
                return _UserSelectionDialog(users: allUsers);
              },
            );
          } else {
            // Show filtered users if matches found
            showDialog<String>(
              useRootNavigator: false,
              context: context,
              builder: (BuildContext context) {
                return _UserSelectionDialog(users: filteredUsers);
              },
            );
          }
        }
      }
    } catch (e) {
      print('Error loading users or contacts: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  });
}

// Complete _UserSelectionDialog implementation
class _UserSelectionDialog extends StatefulWidget {
  final List<_UserListItem> users;
  final bool showingAllUsers;

  const _UserSelectionDialog({
    required this.users,
    this.showingAllUsers = false,
  });

  @override
  _UserSelectionDialogState createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  late List<_UserListItem> filteredUsers;
  final TextEditingController searchController = TextEditingController();
  final SocketService _socketService = SocketService();
  bool isLoading = false;
  String _currentUserId = '';
  String _currentUserName = '';
  // Add a map to track request status per user
  final Map<String, bool> _requestInProgress = {};

  @override
  void initState() {
    super.initState();
    filteredUsers = widget.users;
    _loadCurrentUserData();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // Clear any existing listeners first
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;

    // Set up new listener
    _socketService.onChatRequestUpdated = (request) {
      print('📋 Chat request updated in dialog: ${request.status}');

      // Update the request status and loading state
      setState(() {
        isLoading = false;
        // Clear the in-progress flag for this user
        _requestInProgress[request.receiverId] = false;
      });

      if (request.status == 'pending') {
        // Show success dialog
        _showRequestSentDialog(request.receiverId, request.senderName);
      } else if (request.status == 'approved') {
        // Request was already approved or auto-approved
        final user = widget.users.firstWhere(
          (u) => u.id == request.receiverId,
          orElse: () => _UserListItem(id: request.receiverId, name: "User"),
        );
        _navigateToChat(user);
      } else if (request.status == 'rejected') {
        // Show rejection message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat request was rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };

    // Also listen for errors
    _socketService.onError = (errorData) {
      print('❌ Socket error in chat request: $errorData');
      setState(() {
        isLoading = false;
        // Clear all in-progress flags
        _requestInProgress.clear();
      });

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error: ${errorData['message'] ?? 'Failed to send chat request'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentUserId = prefs.getString('userId') ?? '';
        _currentUserName = prefs.getString('name') ?? '';
      });

      // Make sure socket is connected
      if (!_socketService.isConnected) {
        print('⚠️ Socket not connected in user dialog, connecting...');
        _socketService.connect(_currentUserId);
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Helper method to normalize phone numbers
  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except '+'
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<void> _filterUsers(String query) async {
    // If query is empty, reset to original list
    if (query.isEmpty) {
      setState(() {
        filteredUsers = widget.users;
        isLoading = false;
      });
      return;
    }
    setState(() {
      isLoading = true;
    });
    // First, filter by name as before
    List<_UserListItem> nameFilteredUsers = widget.users
        .where((user) => user.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    // If name filtering yields results, use those
    if (nameFilteredUsers.isNotEmpty) {
      setState(() {
        filteredUsers = nameFilteredUsers;
        isLoading = false;
      });
      return;
    }

    // If no name match, try phone number search
    try {
      // Fetch users from the database
      final response = await http.get(
        Uri.parse('http://145.223.21.62:8090/api/collections/users/records'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> userItems = data['items'] as List;

        // Normalize the query for phone number search
        final normalizedQuery = _normalizePhoneNumber(query);

        // Filter users by phone number
        final phoneFilteredUsers = userItems
            .where((item) {
              // Get the phone number from user data
              String? phoneNumber = item['phonenumber']?.toString();

              if (phoneNumber != null && phoneNumber.isNotEmpty) {
                // Normalize the phone number for comparison
                String normalizedNumber = _normalizePhoneNumber(phoneNumber);

                // Check if the normalized phone number contains or matches the query
                return normalizedNumber.contains(normalizedQuery) ||
                    normalizedNumber == normalizedQuery;
              }
              return false;
            })
            .map((item) => _UserListItem(
                  id: item['id'],
                  name: '${item['firstname'] ?? ''} ${item['lastname'] ?? ''}'
                      .trim(),
                  avatar: item['avatar'],
                  bio: item['bio'],
                ))
            .toList();

        setState(() {
          filteredUsers = phoneFilteredUsers;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error searching users by phone number: $e');
      // Optionally show a snackbar or handle the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching users: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  void _sendChatRequest(_UserListItem user) async {
    // Prevent multiple requests for the same user
    if (_requestInProgress[user.id] == true) {
      print('Request already in progress for user: ${user.id}');
      return;
    }

    // Check if we have current user data
    if (_currentUserId.isEmpty) {
      await _loadCurrentUserData();
    }

    // Show sending indicator
    setState(() {
      isLoading = true;
      _requestInProgress[user.id] = true;
    });

    // Ensure socket is connected
    if (!_socketService.isConnected) {
      print('⚠️ Socket not connected, attempting to connect...');
      _socketService.connect(_currentUserId);

      // Wait a moment for connection to establish
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!_socketService.isConnected) {
        print('❌ Failed to connect socket');
        setState(() {
          isLoading = false;
          _requestInProgress[user.id] = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to server. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Get user avatar URL
    String? currentUserAvatar;
    try {
      final prefs = await SharedPreferences.getInstance();
      final avatar = prefs.getString('avatar');
      if (avatar != null && avatar.isNotEmpty) {
        currentUserAvatar =
            'http://145.223.21.62:8090/api/files/users/$_currentUserId/$avatar';
      }
    } catch (e) {
      print('Error getting avatar: $e');
    }

    // Send the chat request
    print('📤 Sending chat request to user: ${user.id}');
    _socketService.sendChatRequest(
      _currentUserId,
      user.id,
      _currentUserName.isEmpty ? "User" : _currentUserName,
      currentUserAvatar,
    );

    // Set a timeout to update UI if no response is received
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _requestInProgress[user.id] == true) {
        print('⚠️ Request timeout for user: ${user.id}');
        setState(() {
          isLoading = false;
          _requestInProgress[user.id] = false;
        });

        // Show timeout message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Request is taking longer than expected. It may still be processing.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  void _showRequestSentDialog(String receiverId, String userName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Request Sent'),
          content: Text(
              'Chat request sent to $userName. You\'ll be able to chat when they accept your request.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToChat(_UserListItem user) {
    // Navigate to chat screen
    HomeScreen.setBottomBarVisibility(false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DemoChattingMessageListPage(
          receiverId: user.id,
          currentUserId: _currentUserId,
          receiverName: user.name,
          receiverProfileUrl: user.avatar,
        ),
      ),
    ).then((_) {
      // Show bottom bar again when returning
      HomeScreen.setBottomBarVisibility(true);
    });

    // Close dialog
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Chat',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...(947XXXXXXX)',
                    hintStyle: TextStyle(color: Colors.blue[200]),
                    prefixIcon: Icon(Icons.search, color: Colors.blue[300]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
                  onChanged: _filterUsers,
                ),
              ),
              const SizedBox(height: 20),

              // Users List
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.blue[200],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No users found',
                                  style: TextStyle(
                                    color: Colors.blue[300],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final isRequesting =
                                  _requestInProgress[user.id] == true;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.blue[100]!,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: user.avatar != null
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                'http://145.223.21.62:8090/api/files/users/${user.id}/${user.avatar}',
                                            imageBuilder:
                                                (context, imageProvider) =>
                                                    CircleAvatar(
                                              backgroundImage: imageProvider,
                                              radius: 25,
                                            ),
                                            placeholder: (context, url) =>
                                                CircleAvatar(
                                              radius: 25,
                                              backgroundColor: Colors.blue[50],
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.blue[300],
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    CircleAvatar(
                                              radius: 25,
                                              backgroundColor: Colors.blue[50],
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.blue[300],
                                              ),
                                            ),
                                          )
                                        : CircleAvatar(
                                            radius: 25,
                                            backgroundColor: Colors.blue[50],
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.blue[300],
                                            ),
                                          ),
                                  ),
                                  title: Text(
                                    user.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                  subtitle: Text(
                                    user.bio?.isNotEmpty == true
                                        ? user.bio!
                                        : "Hey I'm using Leo Chat",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.blue[300],
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: isRequesting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.blue[300],
                                          ),
                                        )
                                      : Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.blue[200],
                                        ),
                                  onTap: () => _sendChatRequest(user),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 20),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    backgroundColor: Colors.blue[50],
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    // Clean up socket listeners to avoid memory leaks
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;
    _socketService.onError = null;
    super.dispose();
  }
}
