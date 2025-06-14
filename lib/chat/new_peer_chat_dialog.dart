part of 'default_dialogs.dart';

// Assuming SocketService, HomeScreen, and DemoChattingMessageListPage are defined elsewhere
// import 'socket_service.dart';
// import 'home_screen.dart';
// import 'demo_chatting_message_list_page.dart';

class _UserListItem {
  final String id;
  final String name;
  final String? avatar;
  final String? bio;
  final String? phoneNumber;

  _UserListItem({
    required this.id,
    required this.name,
    this.avatar,
    this.bio,
    this.phoneNumber,
  });
}

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
      final hasPermission = await FlutterContacts.requestPermission();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

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

      if (context.mounted) {
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
      }

      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('userId');

      final response = await http.get(
        Uri.parse('http://145.223.21.62:8090/api/collections/users/records'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> userItems = data['items'] as List;
        print('Total users from DB: ${userItems.length}');

        List<Contact> contacts = [];
        try {
          contacts = await FlutterContacts.getContacts(
              withProperties: true, withThumbnail: false);
          print('Total contacts found: ${contacts.length}');
        } catch (e) {
          print('Error accessing contacts even with permission: $e');
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to access contacts. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        Set<String> contactPhoneNumbers = {};

        for (var contact in contacts) {
          for (var phone in contact.phones) {
            if (phone.number.isNotEmpty) {
              String normalizedNumber =
                  phone.number.replaceAll(RegExp(r'[^\d+]'), '');
              contactPhoneNumbers.add(normalizedNumber);
              print(
                  'Contact: ${contact.displayName}, Normalized Number: $normalizedNumber');
            }
          }
        }

        print(
            'Total unique phone numbers from contacts: ${contactPhoneNumbers.length}');

        final List<_UserListItem> filteredUsers = [];

        for (var item in userItems) {
          if (item['id'] == currentUserId) continue;

          String? phoneNumber = item['phonenumber']?.toString();

          if (phoneNumber != null && phoneNumber.isNotEmpty) {
            if (phoneNumber.startsWith('94') &&
                !phoneNumber.startsWith('+94')) {
              phoneNumber = '+$phoneNumber';
            }

            String normalizedNumber =
                phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
            print(
                'User: ${item['firstname']} ${item['lastname']}, Phone: $normalizedNumber');

            bool isInContacts = false;

            for (String contactNumber in contactPhoneNumbers) {
              if (normalizedNumber == contactNumber) {
                isInContacts = true;
                print('MATCH FOUND - Exact match: $normalizedNumber');
                break;
              }

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
                phoneNumber: item['phonenumber']?.toString(),
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

        if (context.mounted) {
          if (filteredUsers.isEmpty) {
            print('No matches found between contacts and users.');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No contacts found in your app.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          } else {
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
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  });
}

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
  final Map<String, bool> _requestInProgress = {};
  Timer? _debounce; // Add debounce timer

  @override
  void initState() {
    super.initState();
    filteredUsers = widget.users;
    _loadCurrentUserData();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;

    _socketService.onChatRequestUpdated = (request) {
      print('SetState: Chat request updated in dialog: ${request.status}');
      setState(() {
        isLoading = false;
        _requestInProgress[request.receiverId] = false;
      });

      if (request.status == 'pending') {
        _showRequestSentDialog(request.receiverId, request.senderName);
      } else if (request.status == 'approved') {
        final user = widget.users.firstWhere(
          (u) => u.id == request.receiverId,
          orElse: () => _UserListItem(id: '', name: ''),
        );
        _navigateToChat(user);
      } else if (request.status == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat request was rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };

    _socketService.onError = (errorData) {
      print('Socket error: $errorData');
      setState(() {
        isLoading = false;
        _requestInProgress.clear();
      });

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
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/$_currentUserId'),
        headers: {'Content-Type': 'application/json'},
      );
      print('response users 1 ${json.decode(response.body)}');
      if (!_socketService.isConnected) {
        print('Socket not connected in user dialog, connecting...');
        _socketService.connect(_currentUserId);
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<void> _filterUsers(String query) async {
    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        filteredUsers = widget.users;
        isLoading = false;
      });
      return;
    }

    final normalizedQuery = _normalizePhoneNumber(query);

    if (normalizedQuery.replaceAll(RegExp(r'[^\d]'), '').length >= 9) {
      _debounce = Timer(const Duration(milliseconds: 500), () async {
        setState(() {
          isLoading = true;
        });

        try {
          final response = await http.get(
            Uri.parse(
                'http://145.223.21.62:8090/api/collections/users/records'),
            headers: {'Content-Type': 'application/json'},
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final List<dynamic> userItems = data['items'] as List;

            final phoneFilteredUsers = userItems
                .where((item) {
                  if (item['id'] == _currentUserId) return false;

                  String? phoneNumber = item['phonenumber']?.toString();

                  if (phoneNumber != null && phoneNumber.isNotEmpty) {
                    String normalizedNumber =
                        _normalizePhoneNumber(phoneNumber);
                    return normalizedNumber.contains(normalizedQuery) ||
                        normalizedNumber == normalizedQuery;
                  }
                  return false;
                })
                .map((item) => _UserListItem(
                      id: item['id'],
                      name:
                          '${item['firstname'] ?? ''} ${item['lastname'] ?? ''}'
                              .trim(),
                      avatar: item['avatar'],
                      bio: item['bio'],
                      phoneNumber: item['phonenumber']?.toString(),
                    ))
                .toList();

            setState(() {
              filteredUsers = phoneFilteredUsers;
              isLoading = false;
            });

            if (phoneFilteredUsers.isEmpty && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No users found for this phone number'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            setState(() {
              isLoading = false;
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to search users'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          print('Error searching users by phone number: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error searching users: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() {
            isLoading = false;
          });
        }
      });
    } else {
      setState(() {
        filteredUsers = widget.users;
        isLoading = false;
      });
    }
  }

  void _sendChatRequest(_UserListItem user) async {
    if (_requestInProgress[user.id] == true) {
      print('Request already in progress for user: ${user.id}');
      return;
    }

    if (_currentUserId.isEmpty) {
      await _loadCurrentUserData();
    }

    setState(() {
      isLoading = true;
      _requestInProgress[user.id] = true;
    });

    if (!_socketService.isConnected) {
      print('Socket not connected, attempting to connect...');
      _socketService.connect(_currentUserId);
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!_socketService.isConnected) {
        print('Failed to connect socket');
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

    String? currentUserAvatar;
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentUserId = prefs.getString('userId') ?? '';
      });
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/$_currentUserId'),
        headers: {'Content-Type': 'application/json'},
      );
      print('response users 1 ${json.decode(response.body)}');

      final userData = json.decode(response.body);
      final avatar = userData['avatar'];
      if (avatar != null && avatar.isNotEmpty) {
        setState(() {
          currentUserAvatar =
              'http://145.223.21.62:8090/api/files/users/$_currentUserId/$avatar';
          _currentUserName = '${userData['firstname']} ${userData['lastname']}';
        });
      }
    } catch (e) {
      print('Error getting avatar: $e');
    }

    print('Sending chat request to user: ${user.id}');
    _socketService.sendChatRequest(
      _currentUserId,
      user.id,
      _currentUserName.isEmpty ? "User" : _currentUserName,
      currentUserAvatar,
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _requestInProgress[user.id] == true) {
        print('Request timeout for user: ${user.id}');
        setState(() {
          isLoading = false;
          _requestInProgress[user.id] = false;
        });

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
      HomeScreen.setBottomBarVisibility(true);
    });

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
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.blue[300]),
                            onPressed: () {
                              searchController.clear();
                              _filterUsers('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  onChanged: (query) {
                    setState(() {});
                    _filterUsers(query);
                  },
                ),
              ),
              const SizedBox(height: 20),
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
    _debounce?.cancel();
    searchController.dispose();
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;
    _socketService.onError = null;
    super.dispose();
  }
}
