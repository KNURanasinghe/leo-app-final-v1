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
    useRootNavigator: false,
    context: context,
    builder: (BuildContext context) {
      return const _UserSelectionDialog();
    },
  );
}

class _UserSelectionDialog extends StatefulWidget {
  const _UserSelectionDialog();

  @override
  _UserSelectionDialogState createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  final TextEditingController searchController = TextEditingController();
  final SocketService _socketService = SocketService();
  bool isLoading = false;
  String _currentUserId = '';
  String _currentUserName = '';
  final Map _requestInProgress = {};

  // Variables for mobile search functionality
  bool _showSearchResult = false;
  _UserListItem? _foundUser;
  String _searchedNumber = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;
    _socketService.onError = null;

    _socketService.onChatRequestUpdated = (request) {
      print('SetState: Chat request updated in dialog: ${request.status}');
      print('Request receiverId: ${request.receiverId}');
      print('Current _requestInProgress keys: ${_requestInProgress.keys}');

      if (mounted) {
        setState(() {
          isLoading = false;
          _requestInProgress[request.receiverId] = false;
        });

        if (request.status == 'pending') {
          print('Showing request sent dialog for ${request.senderName}');
          _showRequestSentDialog(request.receiverId, request.senderName);
        } else if (request.status == 'approved') {
          if (_foundUser != null && _foundUser!.id == request.receiverId) {
            _navigateToChat(_foundUser!);
          }
        } else if (request.status == 'rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat request was rejected'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    };

    _socketService.onError = (errorData) {
      print('Socket error: $errorData');
      if (mounted) {
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

  Future<void> _searchUserByPhoneNumber() async {
    final phoneNumber = searchController.text.trim();

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a mobile number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final normalizedQuery = _normalizePhoneNumber(phoneNumber);
    _searchedNumber = normalizedQuery;

    setState(() {
      isLoading = true;
      _showSearchResult = false;
      _foundUser = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://145.223.21.62:8090/api/collections/users/records'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> userItems = data['items'] as List;

        // Search for exact match
        final matchedUser = userItems.firstWhere(
          (item) {
            if (item['id'] == _currentUserId) return false;

            String? userPhone = item['phonenumber']?.toString();
            if (userPhone != null && userPhone.isNotEmpty) {
              String normalizedUserPhone = _normalizePhoneNumber(userPhone);
              return normalizedUserPhone == normalizedQuery ||
                  normalizedUserPhone.endsWith(normalizedQuery) ||
                  normalizedQuery.endsWith(normalizedUserPhone);
            }
            return false;
          },
          orElse: () => null,
        );

        setState(() {
          isLoading = false;
          _showSearchResult = true;
          if (matchedUser != null) {
            _foundUser = _UserListItem(
              id: matchedUser['id'],
              name:
                  '${matchedUser['firstname'] ?? ''} ${matchedUser['lastname'] ?? ''}'
                      .trim(),
              avatar: matchedUser['avatar'],
              bio: matchedUser['bio'],
              phoneNumber: matchedUser['phonenumber']?.toString(),
            );
          } else {
            _foundUser = null;
          }
        });
      } else {
        setState(() {
          isLoading = false;
          _showSearchResult = true;
          _foundUser = null;
        });
      }
    } catch (e) {
      print('Error searching user by phone number: $e');
      setState(() {
        isLoading = false;
        _showSearchResult = true;
        _foundUser = null;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

    print('Starting chat request for user: ${user.id}');
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
    print('From user: $_currentUserId');
    print(
        'Sender name: ${_currentUserName.isEmpty ? "User" : _currentUserName}');

    _socketService.sendChatRequest(
      _currentUserId,
      user.id,
      _currentUserName.isEmpty ? "User" : _currentUserName,
      currentUserAvatar,
    );

    print('Chat request sent, waiting for response...');

    // Increase timeout to 8 seconds and add better cleanup
    Timer(const Duration(seconds: 8), () {
      if (mounted && _requestInProgress[user.id] == true) {
        print(
            'Request timeout for user: ${user.id} - no socket response received');
        setState(() {
          isLoading = false;
          _requestInProgress[user.id] = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Request sent but taking longer than expected. Check your connection.'),
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

  void _inviteFriend() {
    // Add your invite functionality here
    // For example, you could open a share dialog or send an SMS
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite functionality will be implemented here'),
        backgroundColor: Color(0xFF3DB6EB),
      ),
    );
  }

  void _clearSearch() {
    searchController.clear();
    setState(() {
      _showSearchResult = false;
      _foundUser = null;
      _searchedNumber = '';
    });
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

              // Search input section
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Enter mobile number (947XXXXXXX)',
                          hintStyle: TextStyle(color: Colors.blue[200]),
                          prefixIcon:
                              Icon(Icons.phone, color: Colors.blue[300]),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: Colors.blue[300]),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _searchUserByPhoneNumber,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3DB6EB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Search',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Search results section
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: _showSearchResult
                    ? _buildSearchResult()
                    : _buildWelcomeMessage(),
              ),

              const SizedBox(height: 20),

              // Cancel button
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

  Widget _buildWelcomeMessage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: Colors.blue[200],
          ),
          const SizedBox(height: 10),
          Text(
            'Enter a mobile number to search',
            style: TextStyle(
              color: Colors.blue[300],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResult() {
    if (_foundUser != null) {
      // User found in database
      return Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
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
                child: _foundUser!.avatar != null
                    ? CachedNetworkImage(
                        imageUrl:
                            'http://145.223.21.62:8090/api/files/users/${_foundUser!.id}/${_foundUser!.avatar}',
                        imageBuilder: (context, imageProvider) => CircleAvatar(
                          backgroundImage: imageProvider,
                          radius: 25,
                        ),
                        placeholder: (context, url) => CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.blue[50],
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue[300],
                          ),
                        ),
                        errorWidget: (context, url, error) => CircleAvatar(
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
                _foundUser!.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue[900],
                ),
              ),
              subtitle: Text(
                _foundUser!.bio?.isNotEmpty == true
                    ? _foundUser!.bio!
                    : "Hey I'm using Leo Chat",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.blue[300],
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_requestInProgress[_foundUser!.id] == true || isLoading)
                        ? null
                        : () => _sendChatRequest(_foundUser!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3DB6EB),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: (_requestInProgress[_foundUser!.id] == true || isLoading)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    } else {
      // User not found in database
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.orange[100]!,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search,
              size: 48,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 12),
            Text(
              'This number is not on Leo yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite your friend!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[600],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _clearSearch,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.grey[100],
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _inviteFriend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3DB6EB),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Invite',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    _socketService.onChatRequestUpdated = null;
    _socketService.onChatRequestReceived = null;
    _socketService.onError = null;
    super.dispose();
  }
}
