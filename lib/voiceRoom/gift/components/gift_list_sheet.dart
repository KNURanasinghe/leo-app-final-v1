import 'package:flutter/material.dart';
import 'package:leo_app_01/voiceRoom/inroom_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../gift_data.dart';
import '../gift_manager/defines.dart';
import '../gift_manager/gift_manager.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class GiftData {
  final String id;
  final String giftname;
  final String giftFile;
  final int diamondAmount;
  final String giftPhoto;
  final String collectionId;
  final String collectionName;
  final String category; // Added category field

  GiftData({
    required this.id,
    required this.giftname,
    required this.giftFile,
    required this.diamondAmount,
    required this.giftPhoto,
    required this.collectionId,
    required this.collectionName,
    required this.category, // Added to constructor
  });

  factory GiftData.fromJson(Map<String, dynamic> json) {
    return GiftData(
      id: json['id'],
      giftname: json['giftname'],
      giftFile: json['gift_file'],
      diamondAmount: json['diamond_amount'] ?? 0,
      giftPhoto: json['gift_photo'],
      collectionId: json['collectionId'],
      collectionName: json['collectionName'],
      category: json['catagory'] ??
          '', // Added to fromJson, note the API uses 'catagory'
    );
  }
  String getPhotoUrl(String pocketbaseUrl) {
    return '$pocketbaseUrl/api/files/$collectionId/$id/$giftPhoto';
  }

  ZegoGiftItem toZegoGiftItem(String pocketbaseUrl) {
    // Construct full URLs for assets
    final fullGiftUrl = giftFile.startsWith('http')
        ? giftFile
        : '$pocketbaseUrl/api/files/$collectionId/$id/$giftFile';
    final fullPhotoUrl =
        '$pocketbaseUrl/api/files/$collectionId/$id/$giftPhoto';

    final giftType = _determineGiftType(giftFile);

    // Always use URL source since we're loading from server
    const giftSource = ZegoGiftSource.url;

    print('Creating gift item:');
    print('- URL: $fullGiftUrl');
    print('- Type: $giftType');
    print('- Source: $giftSource');

    return ZegoGiftItem(
      name: giftname,
      icon: fullPhotoUrl,
      sourceURL: fullGiftUrl,
      source: giftSource, // Always URL
      type: giftType,
      weight: diamondAmount,
    );
  }

  ZegoGiftType _determineGiftType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'mp4':
        return ZegoGiftType.mp4;
      case 'svga':
        return ZegoGiftType.svga;
      default:
        return ZegoGiftType.mp4;
    }
  }
}

class User {
  final String id;
  final String username;
  final String avatarUrl;
  final int walletBalance;
  final String firstname;
  final String lastname;

  User({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.walletBalance,
    required this.firstname,
    required this.lastname,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final String fullname =
        '${json['firstname'] ?? ''} ${json['lastname'] ?? ''}'.trim();
    return User(
      id: json['id'],
      username: fullname.isEmpty ? 'Unknown' : fullname,
      avatarUrl:
          'http://145.223.21.62:8090/api/files/${json['collectionId']}/${json['id']}/${json['avatar'] ?? ''}',
      walletBalance: json['wallet'] ?? 0,
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
    );
  }
}

void showGiftListSheet(
  BuildContext context,
  String roomId, {
  required IO.Socket socket,
  required String userId,
  required String userName,
  String? userAvatarUrl,
}) {
  showModalBottomSheet(
    backgroundColor: Colors.black.withOpacity(0.8),
    context: context,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(32.0),
        topRight: Radius.circular(32.0),
      ),
    ),
    isDismissible: true,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return AnimatedPadding(
        padding: MediaQuery.of(context).viewInsets,
        duration: const Duration(milliseconds: 50),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: ZegoGiftSheet(
              roomId: roomId,
              messageService: SocketMessageService(
                socket: socket,
                roomId: roomId,
                userId: userId,
                userName: userName,
                userAvatarUrl: userAvatarUrl,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ZegoGiftSheet extends StatefulWidget {
  final String roomId;
  final SocketMessageService messageService;
  const ZegoGiftSheet({
    super.key,
    required this.roomId,
    required this.messageService,
  });

  @override
  State<ZegoGiftSheet> createState() => _ZegoGiftSheetState();
}

class _ZegoGiftSheetState extends State<ZegoGiftSheet>
    with SingleTickerProviderStateMixin {
  bool _showUserList = false;
  final Color selectedColor = const Color(0xFF2196F3);
  final selectedGiftItemNotifier = ValueNotifier<ZegoGiftItem?>(null);
  final countNotifier = ValueNotifier<String>('1');
  final selectedUserNotifier = ValueNotifier<User?>(null);

  late TabController _tabController;
  List<GiftCategory> categories = [];
  Map<String, List<ZegoGiftItem>> categorizedGifts = {};
  bool isLoadingCategories = true;

  List<User> users = [];
  List<ZegoGiftItem> giftItems = [];
  String? loggedUserId;
  int? userBalance;
  final String pocketbaseUrl = 'http://145.223.21.62:8090';
  bool isLoading = false;

  Map<String, List<GiftData>> originalGiftsByCategory = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([_loadLoggedUserId(), _loadCategories()]);
      await Future.wait([
        _loadUsers(),
        _loadGifts(),
      ]);
      _initializeTabController();
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadLoggedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    loggedUserId = prefs.getString('userId');
    if (loggedUserId != null) {
      await _loadUserBalance();
    }
  }

  void _initializeTabController() {
    _tabController = TabController(
      length: categories.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$pocketbaseUrl/api/collections/gift_catagory/records'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        categories = (data['items'] as List)
            .map((item) => GiftCategory.fromJson(item))
            .toList();
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  // Future<void> _loadGifts() async {
  //   try {
  //     List<GiftData> allGifts = [];
  //     int page = 1;
  //     int perPage = 50000;
  //     bool hasMore = true;

  //     while (hasMore) {
  //       final response = await http.get(
  //         Uri.parse(
  //             '$pocketbaseUrl/api/collections/gifts/records?page=$page&perPage=$perPage'),
  //       );

  //       if (response.statusCode == 200) {
  //         final data = json.decode(response.body);
  //         final List<GiftData> pageGifts = (data['items'] as List)
  //             .map((item) => GiftData.fromJson(item))
  //             .toList();

  //         allGifts.addAll(pageGifts);

  //         // Check if there are more pages
  //         hasMore = data['items'].length == perPage;
  //         page++;

  //         print(
  //             'Loaded page $page: ${pageGifts.length} gifts (Total so far: ${allGifts.length}) ${data['items']}');
  //       } else {
  //         throw Exception('Failed to load gifts: ${response.statusCode}');
  //       }
  //     }

  //     print('Total gifts loaded: ${allGifts.length}');

  //     // Debug: Print all gifts and their categories
  //     print('\n=== ALL GIFTS ===');
  //     for (var gift in allGifts) {
  //       print('Gift: "${gift.giftname}" -> Category: "${gift.category}"');
  //     }

  //     // Organize gifts by category
  //     categorizedGifts.clear();
  //     for (var category in categories) {
  //       var matchingGifts = allGifts
  //           .where((gift) => gift.category == category.categoryName)
  //           .toList();

  //       categorizedGifts[category.id] = matchingGifts
  //           .map((gift) => gift.toZegoGiftItem(pocketbaseUrl))
  //           .toList();

  //       print(
  //           'Category "${category.categoryName}" has ${categorizedGifts[category.id]?.length ?? 0} gifts');
  //     }

  //     if (mounted) {
  //       setState(() {});
  //     }
  //   } catch (e) {
  //     print('Error loading all gifts: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error loading gifts: ${e.toString()}')),
  //       );
  //     }
  //   }
  // }

  Future<void> _loadGifts() async {
    try {
      List<GiftData> allGifts = [];
      int page = 1;
      int perPage = 50000;
      bool hasMore = true;

      while (hasMore) {
        final response = await http.get(
          Uri.parse(
              '$pocketbaseUrl/api/collections/gifts/records?page=$page&perPage=$perPage'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<GiftData> pageGifts = (data['items'] as List)
              .map((item) => GiftData.fromJson(item))
              .toList();

          allGifts.addAll(pageGifts);

          hasMore = data['items'].length == perPage;
          page++;

          print(
              'Loaded page $page: ${pageGifts.length} gifts (Total so far: ${allGifts.length})');
        } else {
          throw Exception('Failed to load gifts: ${response.statusCode}');
        }
      }

      print('Total gifts loaded: ${allGifts.length}');

      // Organize gifts by category and store both original and ZegoGiftItem versions
      categorizedGifts.clear();
      originalGiftsByCategory.clear();

      for (var category in categories) {
        var matchingGifts = allGifts
            .where((gift) => gift.category == category.categoryName)
            .toList();

        // Store original GiftData
        originalGiftsByCategory[category.id] = matchingGifts;

        // Store ZegoGiftItem version
        categorizedGifts[category.id] = matchingGifts
            .map((gift) => gift.toZegoGiftItem(pocketbaseUrl))
            .toList();

        print(
            'Category "${category.categoryName}" has ${categorizedGifts[category.id]?.length ?? 0} gifts');
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading all gifts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading gifts: ${e.toString()}')),
        );
      }
    }
  }

  // Helper method to find original GiftData by ZegoGiftItem name
  GiftData? _findOriginalGiftData(ZegoGiftItem giftItem) {
    for (var categoryGifts in originalGiftsByCategory.values) {
      for (var gift in categoryGifts) {
        if (gift.giftname == giftItem.name) {
          return gift;
        }
      }
    }
    return null;
  }

  Future<void> _loadUserBalance() async {
    if (loggedUserId == null) return;

    try {
      final response = await http.get(
        Uri.parse('$pocketbaseUrl/api/collections/users/records/$loggedUserId'),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (mounted) {
          setState(() {
            userBalance = userData['wallet'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error loading user balance: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      if (loggedUserId == null) {
        print('LoggedUserId is null, cannot load users');
        return;
      }

      print('Loading users with logged user ID: $loggedUserId');
      print('Room ID: ${widget.roomId}');

      // Get all online users from this specific room
      final onlineUsersResponse = await http.get(
        Uri.parse('$pocketbaseUrl/api/collections/online_users/records')
            .replace(queryParameters: {
          'filter': 'voiceRoomId="${widget.roomId}"',
          'expand': '', // Don't expand relations to keep response clean
        }),
      );

      print('Online users response status: ${onlineUsersResponse.statusCode}');
      print('Online users response body: ${onlineUsersResponse.body}');

      if (onlineUsersResponse.statusCode == 200) {
        final onlineUsersData = json.decode(onlineUsersResponse.body);
        final onlineUsersList = onlineUsersData['items'] as List;

        print('Found ${onlineUsersList.length} total online users in room');

        if (onlineUsersList.isEmpty) {
          print('No online users found in room ${widget.roomId}');
          if (mounted) {
            setState(() {
              users = [];
            });
          }
          return;
        }

        // Extract user IDs excluding current user
        List<String> onlineUserIds = [];
        for (var item in onlineUsersList) {
          final userId = item['userId'] as String;
          print('Processing online user: $userId');

          // Skip current user
          if (userId != loggedUserId) {
            onlineUserIds.add(userId);
          } else {
            print('Skipping current user: $userId');
          }
        }

        print(
            'Found ${onlineUserIds.length} other users in room: $onlineUserIds');

        if (onlineUserIds.isEmpty) {
          print('No other users found in room besides current user');
          if (mounted) {
            setState(() {
              users = [];
            });
          }
          return;
        }

        // Load details for each online user
        List<User> loadedUsers = [];

        // Use Future.wait for better performance when loading multiple users
        final userFutures = onlineUserIds.map((userId) async {
          try {
            print('Fetching details for user: $userId');
            final userResponse = await http.get(
              Uri.parse('$pocketbaseUrl/api/collections/users/records/$userId'),
            );

            print('User $userId response status: ${userResponse.statusCode}');

            if (userResponse.statusCode == 200) {
              final userData = json.decode(userResponse.body);
              final user = User.fromJson(userData);
              print(
                  'Successfully loaded user: ${user.username} with ID: ${user.id}');
              return user;
            } else {
              print('Failed to load user $userId: ${userResponse.statusCode}');
              print('Error response: ${userResponse.body}');
              return null;
            }
          } catch (e) {
            print('Error loading user $userId: $e');
            return null;
          }
        }).toList();

        // Wait for all user details to be fetched
        final userResults = await Future.wait(userFutures);

        // Filter out null results
        loadedUsers =
            userResults.where((user) => user != null).cast<User>().toList();

        print(
            'Successfully loaded ${loadedUsers.length} users from room ${widget.roomId}:');
        for (var user in loadedUsers) {
          print('- User: ${user.username}, ID: ${user.id}');
        }

        if (mounted) {
          setState(() {
            users = loadedUsers;
          });
        }
      } else {
        print(
            'Failed to fetch online users: ${onlineUsersResponse.statusCode}');
        print('Error response: ${onlineUsersResponse.body}');

        if (mounted) {
          setState(() {
            users = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to load users: ${onlineUsersResponse.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Error in _loadUsers: $e');
      if (mounted) {
        setState(() {
          users = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading users from room')),
        );
      }
    }
  }

  Future<bool> _checkAndUpdateBalance(double giftCost) async {
    if (userBalance == null || userBalance! < giftCost) return false;

    final newBalance = (userBalance! - giftCost).toInt();
    try {
      final response = await http.patch(
        Uri.parse('$pocketbaseUrl/api/collections/users/records/$loggedUserId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'wallet': newBalance}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            userBalance = newBalance;
          });
        }
        return true;
      }
    } catch (e) {
      print('Error updating balance: $e');
    }
    return false;
  }

  Future<void> _handleGiftPlayback(ZegoGiftItem giftItem, int count) async {
    try {
      print('Starting gift playback:');
      print('- Name: ${giftItem.name}');
      print('- URL: ${giftItem.sourceURL}');
      print('- Type: ${giftItem.type}');
      print('- Source: ${giftItem.source}');

      // Pre-download the gift file for SVGA
      if (giftItem.type == ZegoGiftType.svga) {
        await _preloadSvgaFile(giftItem);
      }

      // Add to playlist
      ZegoGiftManager()
          .playList
          .add(PlayData(giftItem: giftItem, count: count));

      // Send the gift
      final result = await ZegoGiftManager()
          .service
          .sendGift(name: giftItem.name, count: count);

      print('Gift send result: $result');
    } catch (e, stackTrace) {
      print('Gift playback error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing gift: ${e.toString()}')),
        );
      }
      rethrow;
    }
  }

  Future<void> precacheGiftAsset(ZegoGiftItem giftItem) async {
    try {
      if (giftItem.type == ZegoGiftType.mp4) {
        // For MP4 files, we can pre-warm the cache
        final response = await http.get(Uri.parse(giftItem.sourceURL));
        if (response.statusCode != 200) {
          throw Exception('Failed to pre-cache gift asset');
        }
      }
    } catch (e) {
      print('Error pre-caching gift asset: $e');
      // Don't rethrow - precaching is optional
    }
  }

  bool _validateGiftItem(ZegoGiftItem giftItem) {
    if (giftItem.sourceURL.isEmpty) {
      print('Invalid gift: Empty source URL');
      return false;
    }

    if (giftItem.type == ZegoGiftType.svga &&
        !giftItem.sourceURL.toLowerCase().endsWith('.svga')) {
      print('Invalid SVGA gift: Incorrect file extension');
      return false;
    }

    if (giftItem.type == ZegoGiftType.mp4 &&
        !giftItem.sourceURL.toLowerCase().endsWith('.mp4')) {
      print('Invalid MP4 gift: Incorrect file extension');
      return false;
    }

    return true;
  }

  Future<void> _preloadSvgaFile(ZegoGiftItem giftItem) async {
    try {
      final response = await http.get(Uri.parse(giftItem.sourceURL));
      if (response.statusCode != 200) {
        throw Exception('Failed to download SVGA file');
      }

      // You might need to store this data somewhere depending on your SVGA player implementation
      final bytes = response.bodyBytes;
      print('Successfully pre-downloaded SVGA file: ${bytes.length} bytes');

      // Store the bytes in a cache or pass them to your SVGA player
      // Implementation depends on your specific SVGA player setup
    } catch (e) {
      print('Error pre-loading SVGA file: $e');
      rethrow;
    }
  }

  // Future<void> sendGift(ZegoGiftItem giftItem, int count, User receiver) async {
  //   try {
  //     if (!_validateGiftItem(giftItem)) {
  //       throw Exception('Invalid gift data');
  //     }
  //
  //     final totalCost = giftItem.weight * count.toDouble();
  //     final rewardAmount = totalCost * 0.4; // 40% of total cost
  //
  //     if (await _checkAndUpdateBalance(totalCost)) {
  //       // Send to PocketBase first
  //       final response = await http.post(
  //           Uri.parse('http://145.223.21.62:6003/api/gifts/send'),
  //           headers: {'Content-Type': 'application/json'},
  //           body: json.encode({
  //             'sender_user_id': loggedUserId,
  //             'reciever_user_id': receiver.id,
  //             'gifts_url': giftItem.sourceURL,
  //             'giftname': giftItem.name,
  //             'gift_count': count,
  //             'voiceRoomId':widget.roomId
  //           })
  //       );
  //
  //       if (response.statusCode == 200) {
  //         try {
  //           await _handleGiftPlayback(giftItem, count);
  //           await _updateReceiverWallet(receiver.id, rewardAmount);
  //           if (mounted) {
  //             Navigator.of(context).pop();
  //             ScaffoldMessenger.of(context).showSnackBar(
  //                 const SnackBar(content: Text('Gift sent successfully!'))
  //             );
  //           }
  //         } catch (e) {
  //           print('Playback error: $e');
  //           if (mounted) {
  //             Navigator.of(context).pop();
  //             ScaffoldMessenger.of(context).showSnackBar(
  //                 const SnackBar(content: Text('Gift sent but animation failed'))
  //             );
  //           }
  //         }
  //       } else {
  //         throw Exception('Failed to send gift');
  //       }
  //     } else {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text('Insufficient balance!'))
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     print('Error sending gift: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Error sending gift: ${e.toString()}'))
  //       );
  //     }
  //   }
  // }

  // Future<void> sendGift(ZegoGiftItem giftItem, int count, User receiver) async {
  //   try {
  //     print('Sending gift with following details:');
  //     print('Receiver ID: ${receiver.id}');
  //     print('Receiver Username: ${receiver.username}');
  //     print('Gift Name: ${giftItem.name}');
  //     print('Count: $count');
  //     print('Room ID: ${widget.roomId}');

  //     if (!_validateGiftItem(giftItem)) {
  //       throw Exception('Invalid gift data');
  //     }

  //     final totalCost = giftItem.weight * count.toDouble();
  //     final rewardAmount = totalCost * 0.4;

  //     // Check balance first
  //     if (!await _checkAndUpdateBalance(totalCost)) {
  //       if (mounted) {
  //         _showSnackBar('Insufficient balance!');
  //       }
  //       return;
  //     }

  //     // Prepare the payload
  //     final payload = {
  //       'sender_user_id': loggedUserId,
  //       'reciever_user_id': receiver.id,
  //       'gifts_url': giftItem.sourceURL,
  //       'giftname': giftItem.name,
  //       'gift_count': count,
  //       'voiceRoomId': widget.roomId
  //     };

  //     print('Sending request with payload:');
  //     print(json.encode(payload));

  //     // Send to server first
  //     final response = await http.post(
  //         Uri.parse('http://145.223.21.62:6003/api/gifts/send'),
  //         headers: {'Content-Type': 'application/json'},
  //         body: json.encode(payload));

  //     print('Server response status: ${response.statusCode}');
  //     print('Server response body: ${response.body}');

  //     if (response.statusCode != 200) {
  //       throw Exception('Failed to send gift to server');
  //     }

  //     // Update receiver wallet BEFORE closing dialog
  //     print('Updating receiver wallet...');
  //     await _updateReceiverWallet(receiver.id, rewardAmount);
  //     print('Receiver wallet updated successfully');

  //     // Emit gift message BEFORE closing dialog
  //     print('Emitting gift message...');
  //     await _emitGiftMessage(giftItem, count, receiver, totalCost);
  //     print('Gift message emitted successfully');

  //     // Close dialog
  //     if (mounted) {
  //       Navigator.of(context).pop();
  //     }

  //     // Handle gift playback after dialog is closed
  //     try {
  //       await _handleGiftPlayback(giftItem, count);
  //       print('Gift playback completed successfully');
  //     } catch (e) {
  //       print('Animation error: $e');
  //       if (mounted) {
  //         _showSnackBar('Gift sent but animation failed');
  //       }
  //       return; // Don't show success message if animation failed
  //     }

  //     // Show success message
  //     if (mounted) {
  //       Future.delayed(const Duration(milliseconds: 500), () {
  //         if (mounted) {
  //           _showSnackBar('Gift sent successfully!');
  //         }
  //       });
  //     }
  //   } catch (e) {
  //     print('Error sending gift: $e');
  //     if (mounted) {
  //       _showSnackBar('Error sending gift: ${e.toString()}');
  //     }
  //   }
  // }
  Future<void> sendGift(ZegoGiftItem giftItem, int count, User receiver) async {
    try {
      print('Sending gift with following details:');
      print('Receiver ID: ${receiver.id}');
      print('Receiver Username: ${receiver.username}');
      print('Gift Name: ${giftItem.name}');
      print('Count: $count');
      print('Room ID: ${widget.roomId}');

      if (!_validateGiftItem(giftItem)) {
        throw Exception('Invalid gift data');
      }

      final totalCost = giftItem.weight * count.toDouble();
      final rewardAmount = totalCost * 0.4;

      // Check balance first
      if (!await _checkAndUpdateBalance(totalCost)) {
        if (mounted) {
          _showSnackBar('Insufficient balance!');
        }
        return;
      }

      // Find original gift data to get photo URL
      final originalGift = _findOriginalGiftData(giftItem);
      final giftPhotoUrl =
          originalGift?.getPhotoUrl(pocketbaseUrl) ?? giftItem.icon;

      // Prepare the payload
      final payload = {
        'sender_user_id': loggedUserId,
        'reciever_user_id': receiver.id,
        'gifts_url': giftItem
            .sourceURL, // This is still the SVGA/animation file for server storage
        'giftname': giftItem.name,
        'gift_count': count,
        'voiceRoomId': widget.roomId
      };

      print('Sending request with payload:');
      print(json.encode(payload));

      // Send to server first
      final response = await http.post(
          Uri.parse('http://145.223.21.62:6003/api/gifts/send'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));

      print('Server response status: ${response.statusCode}');
      print('Server response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to send gift to server');
      }

      // Update receiver wallet BEFORE closing dialog
      print('Updating receiver wallet...');
      await _updateReceiverWallet(receiver.id, rewardAmount);
      print('Receiver wallet updated successfully');

      // Emit gift message BEFORE closing dialog - using photo URL instead of SVGA URL
      print('Emitting gift message with photo URL: $giftPhotoUrl');
      await _emitGiftMessage(
          giftItem, count, receiver, totalCost, giftPhotoUrl);
      print('Gift message emitted successfully');

      // Close dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Handle gift playback after dialog is closed
      try {
        await _handleGiftPlayback(giftItem, count);
        print('Gift playback completed successfully');
      } catch (e) {
        print('Animation error: $e');
        if (mounted) {
          _showSnackBar('Gift sent but animation failed');
        }
        return;
      }

      // Show success message
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showSnackBar('Gift sent successfully!');
          }
        });
      }
    } catch (e) {
      print('Error sending gift: $e');
      if (mounted) {
        _showSnackBar('Error sending gift: ${e.toString()}');
      }
    }
  }

// **NEW: Add this method to emit gift message via socket**
  // Future<void> _emitGiftMessage(
  //     ZegoGiftItem giftItem, int count, User receiver, double totalCost) async {
  //   try {
  //     // Use the messageService that was passed to the widget
  //     widget.messageService.sendGiftMessage(
  //       receiverUserId: receiver.id,
  //       receiverUserName: receiver.username,
  //       giftName: giftItem.name,
  //       giftCount: count,
  //       giftUrl: giftItem.sourceURL,
  //       totalCost: totalCost.toInt(),
  //     );

  //     print('Gift message sent via socket successfully');
  //   } catch (e) {
  //     print('Error emitting gift message: $e');
  //   }
  // }

  Future<void> _emitGiftMessage(ZegoGiftItem giftItem, int count, User receiver,
      double totalCost, String giftPhotoUrl) async {
    try {
      // Use the messageService that was passed to the widget
      widget.messageService.sendGiftMessage(
        receiverUserId: receiver.id,
        receiverUserName: receiver.username,
        giftName: giftItem.name,
        giftCount: count,
        giftUrl: giftItem.sourceURL, // Use photo URL instead of SVGA URL
        photourl: giftPhotoUrl,
        totalCost: totalCost.toInt(),
      );

      print(
          'Gift message sent via socket successfully with photo URL: $giftPhotoUrl');
    } catch (e) {
      print('Error emitting gift message: $e');
    }
  }

// Helper method to show snackbar
  void _showSnackBar(String message) {
    // Remove any existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();

    // Show new snackbar with duration
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Future<void> sendGift(ZegoGiftItem giftItem, int count, User receiver) async {
  //   try {
  //     final totalCost = giftItem.weight * count.toDouble();
  //
  //     if (await _checkAndUpdateBalance(totalCost)) {
  //       // Send to PocketBase
  //       final response = await http.post(
  //           Uri.parse('http://145.223.21.62:6003/api/gifts/send'),
  //           headers: {'Content-Type': 'application/json'},
  //           body: json.encode({
  //             'sender_user_id': loggedUserId,
  //             'reciever_user_id': receiver.id,
  //             'gifts_url': giftItem.sourceURL,
  //             'giftname': giftItem.name,
  //             'gift_count': count,
  //             'voiceRoomId': widget.roomId,
  //           })
  //       );
  //
  //       if (response.statusCode == 200) {
  //         try {
  //           await _handleGiftPlayback(giftItem, count);
  //           if (mounted) {
  //             Navigator.of(context).pop();
  //             ScaffoldMessenger.of(context).showSnackBar(
  //                 const SnackBar(content: Text('Gift sent successfully!'))
  //             );
  //           }
  //         } catch (e) {
  //           print('Playback error: $e');
  //           if (mounted) {
  //             Navigator.of(context).pop();
  //             ScaffoldMessenger.of(context).showSnackBar(
  //                 const SnackBar(content: Text('Gift sent but animation failed'))
  //             );
  //           }
  //         }
  //       } else {
  //         throw Exception('Failed to send gift');
  //       }
  //     } else {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text('Insufficient balance!'))
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     print('Error sending gift: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Error sending gift: ${e.toString()}'))
  //       );
  //     }
  //   }
  // }

  Future<void> _updateReceiverWallet(
      String receiverId, double rewardAmount) async {
    try {
      print('Starting wallet update for receiver: $receiverId');
      print('Reward amount: $rewardAmount');

      // Fetch current wallet balance
      final fetchResponse = await http.get(
        Uri.parse('$pocketbaseUrl/api/collections/users/records/$receiverId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Fetch wallet response status: ${fetchResponse.statusCode}');
      print('Fetch wallet response body: ${fetchResponse.body}');

      if (fetchResponse.statusCode == 200) {
        final data = jsonDecode(fetchResponse.body);
        final currentBalance = data['wallet'] ?? 0;

        print('Current balance: $currentBalance');

        // Calculate new balance
        final newBalance = currentBalance + rewardAmount;

        print('New balance will be: $newBalance');

        // Update wallet balance
        final updateResponse = await http.patch(
          Uri.parse('$pocketbaseUrl/api/collections/users/records/$receiverId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'wallet': newBalance}),
        );

        print('Update wallet response status: ${updateResponse.statusCode}');
        print('Update wallet response body: ${updateResponse.body}');

        if (updateResponse.statusCode != 200) {
          throw Exception(
              'Failed to update wallet balance: ${updateResponse.body}');
        }

        print(
            'Wallet updated successfully from $currentBalance to $newBalance');
      } else {
        throw Exception(
            'Failed to fetch receiver wallet details: ${fetchResponse.body}');
      }
    } catch (e) {
      print('Error updating receiver wallet: $e');
      throw Exception('Error updating wallet balance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildSelectedUserDisplay(),
              if (!isLoadingCategories && categories.isNotEmpty) ...[
                Container(
                  margin: EdgeInsets.zero, // Remove any margin
                  padding: EdgeInsets.zero, // Remove any padding
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    padding:
                        EdgeInsets.zero, // Remove padding around the TabBar
                    indicatorPadding:
                        EdgeInsets.zero, // Remove padding around the indicator
                    labelPadding: const EdgeInsets.symmetric(
                        horizontal: 16), // Adjust tab label padding
                    tabAlignment: TabAlignment.start, // Align tabs to start
                    tabs: categories.map((category) {
                      return Tab(
                        text: category.categoryName,
                      );
                    }).toList(),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.5),
                    indicatorColor: selectedColor,
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: categories.map((category) {
                      return _buildGiftGridForCategory(category.id);
                    }).toList(),
                  ),
                ),
              ],
              Container(
                padding: EdgeInsets.only(
                  top: 10,
                  bottom: MediaQuery.of(context)
                      .viewInsets
                      .bottom, //+  MediaQuery.of(context).padding.bottom
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/diamond.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${userBalance ?? 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        countDropList(),
                        const SizedBox(width: 10),
                        _buildSendButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showUserList) _buildUserListOverlay(),
        ],
      ),
    );
  }

  Widget _buildGiftGridForCategory(String categoryId) {
    final gifts = categorizedGifts[categoryId] ?? [];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 5),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final item = gifts[index];
        return GestureDetector(
          onTap: () => selectedGiftItemNotifier.value = item,
          child: ValueListenableBuilder<ZegoGiftItem?>(
            valueListenable: selectedGiftItemNotifier,
            builder: (context, selectedGiftItem, _) {
              final isSelected = selectedGiftItem?.name == item.name;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? selectedColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.icon.isEmpty
                          ? Icon(Icons.card_giftcard,
                              color: selectedColor, size: 40)
                          : Image.network(
                              item.icon,
                              width: 45,
                              height: 45,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.card_giftcard,
                                    color: selectedColor, size: 40);
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 45,
                                  height: 45,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/diamond.png',
                          width: 12,
                          height: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          item.weight.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSelectedUserDisplay() {
    return ValueListenableBuilder<User?>(
      valueListenable: selectedUserNotifier,
      builder: (context, selectedUser, _) {
        return GestureDetector(
          onTap: () async {
            // First ensure we have the logged user ID
            if (loggedUserId == null) {
              await _loadLoggedUserId();
            }

            setState(() {
              isLoading = true; // Show loading state
            });

            try {
              // Refresh users from current room
              await _loadUsers();
              print(
                  'Users refreshed. Found ${users.length} users in room ${widget.roomId}');
            } catch (e) {
              print('Error refreshing users: $e');
            } finally {
              if (mounted) {
                setState(() {
                  isLoading = false;
                  _showUserList = !_showUserList;
                });
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      if (selectedUser != null) ...[
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.grey,
                          child: selectedUser.avatarUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.network(
                                    selectedUser.avatarUrl,
                                    width: 30,
                                    height: 30,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.person,
                                          color: Colors.white);
                                    },
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedUser.username,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        Expanded(
                          child: Text(
                            users.isEmpty
                                ? 'No users in room'
                                : 'Select User (${users.length} available)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildUserListOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showUserList = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Column(
          children: [
            const Spacer(),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Select User',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return InkWell(
                          onTap: () {
                            selectedUserNotifier.value = user;
                            setState(() {
                              _showUserList = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey,
                                  child: user.avatarUrl.isEmpty
                                      ? const Icon(Icons.person,
                                          color: Colors.white)
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Image.network(
                                            user.avatarUrl,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(Icons.person,
                                                  color: Colors.white);
                                            },
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.username,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (user.firstname.isNotEmpty ||
                                          user.lastname.isNotEmpty)
                                        Text(
                                          '${user.firstname} ${user.lastname}',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                ValueListenableBuilder<User?>(
                                  valueListenable: selectedUserNotifier,
                                  builder: (context, selectedUser, _) {
                                    final isSelected =
                                        selectedUser?.id == user.id;
                                    return Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? selectedColor
                                              : Colors.white.withOpacity(0.3),
                                          width: 2,
                                        ),
                                        color: isSelected
                                            ? selectedColor
                                            : Colors.transparent,
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.account_balance_wallet,
              color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            'Balance: ${userBalance ?? 0}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Add a new compact balance display widget
  Widget _buildCompactBalanceDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/diamond.png', // Make sure to add this image
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '${userBalance ?? 0}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      height: 36,
      child: ValueListenableBuilder<ZegoGiftItem?>(
        valueListenable: selectedGiftItemNotifier,
        builder: (context, selectedGift, _) {
          return ElevatedButton(
            onPressed: selectedGift == null ||
                    selectedUserNotifier.value == null
                ? null
                : () {
                    final giftCount = int.tryParse(countNotifier.value) ?? 1;
                    sendGift(
                        selectedGift, giftCount, selectedUserNotifier.value!);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text(
              'SEND',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ValueListenableBuilder<User?>(
        valueListenable: selectedUserNotifier,
        builder: (context, selectedUser, _) {
          return Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.black.withOpacity(0.8),
            ),
            child: DropdownButton<User>(
              isExpanded: true,
              value: selectedUser,
              hint: const Text('Select User',
                  style: TextStyle(color: Colors.white)),
              style: const TextStyle(color: Colors.white),
              underline: Container(
                height: 1,
                color: Colors.white.withOpacity(0.3),
              ),
              items: users.map((User user) {
                return DropdownMenuItem<User>(
                  value: user,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.grey,
                        child: user.avatarUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  user.avatarUrl,
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.person,
                                        color: Colors.white);
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user.username,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (User? value) {
                setState(() {
                  selectedUserNotifier.value = value;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget countDropList() {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 15,
    );

    return ValueListenableBuilder<String>(
      valueListenable: countNotifier,
      builder: (context, count, _) {
        return DropdownButton<String>(
          value: count,
          onChanged: (selectedValue) {
            if (selectedValue != null) {
              countNotifier.value = selectedValue;
            }
          },
          alignment: AlignmentDirectional.centerEnd,
          style: textStyle,
          dropdownColor: Colors.black.withOpacity(0.5),
          items: <String>['1', '5', '10', '100'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: textStyle,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget giftGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 5),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: giftItems.length,
      itemBuilder: (context, index) {
        final item = giftItems[index];
        return GestureDetector(
          onTap: () => selectedGiftItemNotifier.value = item,
          child: ValueListenableBuilder<ZegoGiftItem?>(
            valueListenable: selectedGiftItemNotifier,
            builder: (context, selectedGiftItem, _) {
              final isSelected = selectedGiftItem?.name == item.name;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? selectedColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                // Rest of the gift item UI remains the same
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.icon.isEmpty
                          ? Icon(Icons.card_giftcard,
                              color: selectedColor, size: 40)
                          : Image.network(
                              item.icon,
                              width: 45,
                              height: 45,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.card_giftcard,
                                    color: selectedColor, size: 40);
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 45,
                                  height: 45,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/diamond.png',
                          width: 12,
                          height: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          item.weight.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    selectedGiftItemNotifier.dispose();
    countNotifier.dispose();
    selectedUserNotifier.dispose();
    super.dispose();
  }
}

class GiftCategory {
  final String id;
  final String categoryName;

  GiftCategory({
    required this.id,
    required this.categoryName,
  });

  factory GiftCategory.fromJson(Map<String, dynamic> json) {
    return GiftCategory(
      id: json['id'],
      categoryName: json['catagory_name'],
    );
  }
}
