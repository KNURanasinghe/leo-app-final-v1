import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'theme.dart';
import 'widgets/body_container.dart';
import 'widgets/primary_button.dart';
import 'widgets/voice_room_item.dart';
import 'widgets/gift_item.dart';
import 'widgets/outline_button.dart';
import 'widgets/profile_info.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://145.223.21.62:8090';

class ProfileScreenView extends StatefulWidget {
  final String viewedUserId;
  final String viewerUserId;

  const ProfileScreenView({
    super.key,
    required this.viewedUserId,
    required this.viewerUserId,
  });

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreenView> {
  String? userId;
  Map<String, dynamic>? userProfile;
  List<Map<String, dynamic>>? gifts;
  List<Map<String, dynamic>>? badges;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = widget.viewedUserId;

    if (userId != null) {
      try {
        await Future.wait([
          _fetchUserProfile(),
          _fetchReceivedGifts(),
          _fetchUserBadges(),
        ]);
      } catch (e) {
        debugPrint('Error initializing data: $e');
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/${widget.viewedUserId}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          userProfile = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _fetchReceivedGifts() async {
    try {
      // First fetch all gifts
      final allGiftsResponse = await http.get(
        Uri.parse('$baseUrl/api/collections/gifts/records'),
      );

      if (allGiftsResponse.statusCode != 200) {
        throw Exception('Failed to fetch gifts');
      }

      final allGifts = json.decode(allGiftsResponse.body)['items'] as List;
      Map<String, Map<String, dynamic>> giftsMap = {};

      // Debug: Print all gift fields
      print('First gift data: ${allGifts.first}');

      // Create gifts map
      for (var gift in allGifts) {
        giftsMap[gift['giftname']] = {
          ...gift,
          'count': 0,
        };
      }

      // Fetch received gifts
      final receivedResponse = await http.get(
        Uri.parse(
            '$baseUrl/api/collections/sending_recieving_gifts/records?filter=(reciever_user_id="${widget.viewedUserId}")'),
      );

      if (receivedResponse.statusCode != 200) {
        throw Exception('Failed to fetch received gifts');
      }

      final receivedGifts = json.decode(receivedResponse.body)['items'] as List;

      // Count gifts
      for (var received in receivedGifts) {
        final giftName = received['giftname'] as String;
        final count = received['gift_count'] as int;

        if (giftsMap.containsKey(giftName)) {
          giftsMap[giftName]!['count'] =
              (giftsMap[giftName]!['count'] as int) + count;
        }
      }

      // Convert to list and filter out gifts with count 0
      List<Map<String, dynamic>> giftsList = giftsMap.values
          .where((gift) => gift['count'] > 0)
          .map((gift) => {
                'id': gift['id'],
                'collectionId': gift['collectionId'],
                // Try all possible field names for gift photo
                'gifphoto': gift['gift_photo'] ??
                    gift['giftphoto'] ??
                    gift['gifPhoto'] ??
                    gift['photo'] ??
                    '',
                'giftCount': gift['count'],
                'giftName': gift['giftname'],
              })
          .toList();

      // Sort by count
      giftsList.sort(
          (a, b) => (b['giftCount'] as int).compareTo(a['giftCount'] as int));

      if (mounted) {
        setState(() {
          gifts = giftsList;
        });
      }

      // Debug log
      for (var gift in giftsList) {
        print('\nGift details:');
        print('Name: ${gift['giftName']}');
        print('ID: ${gift['id']}');
        print('CollectionId: ${gift['collectionId']}');
        print('Photo field: ${gift['gifphoto']}');
        print(
            'Full URL: $baseUrl/api/files/${gift['collectionId']}/${gift['id']}/${gift['gifphoto']}');
      }
    } catch (e) {
      debugPrint('Error fetching gifts: $e');
    }
  }

  Future<void> _fetchUserBadges() async {
    try {
      // First fetch received badges for the specific user
      final receivedBadgesResponse = await http.get(
        Uri.parse(
            '$baseUrl/api/collections/recieved_badges/records?filter=(userId="${widget.viewedUserId}")'),
      );

      if (receivedBadgesResponse.statusCode == 200) {
        final receivedBadges =
            json.decode(receivedBadgesResponse.body)['items'] as List;
        List<Map<String, dynamic>> badgesList = [];

        // Create a Set to track unique badge names
        Set<String> processedBadgeNames = {};

        for (var receivedBadge in receivedBadges) {
          final badgeName = receivedBadge['batch_name'];

          // Skip if we've already processed this badge name
          if (processedBadgeNames.contains(badgeName)) continue;
          processedBadgeNames.add(badgeName);

          // Fetch badge details
          final badgeResponse = await http.get(
            Uri.parse(
                '$baseUrl/api/collections/badges/records?filter=(badgeName="$badgeName")'),
          );

          if (badgeResponse.statusCode == 200) {
            final badgeItems = json.decode(badgeResponse.body)['items'] as List;
            if (badgeItems.isNotEmpty) {
              final badgeData = badgeItems[0];
              // Make sure badgePhoto exists and is not empty
              if (badgeData['badgePhoto'] != null &&
                  badgeData['badgePhoto'].toString().isNotEmpty) {
                badgesList.add({
                  'id': badgeData['id'],
                  'collectionId': badgeData['collectionId'],
                  'badgePhoto': badgeData['badgePhoto'],
                  'badgeName': badgeData['badgeName'],
                });
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            badges = badgesList;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching badges: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (isLoading || userProfile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Get cover photo URL with fallback
    final String coverPhotoUrl = userProfile!['coverphoto'] != null &&
            userProfile!['coverphoto'].isNotEmpty
        ? '$baseUrl/api/files/${userProfile!['collectionId']}/${userProfile!['id']}/${userProfile!['coverphoto']}'
        : 'assets/images/default_cover.png';

    // Get avatar URL with fallback
    final String avatarUrl = userProfile!['avatar'] != null &&
            userProfile!['avatar'].isNotEmpty
        ? '$baseUrl/api/files/${userProfile!['collectionId']}/${userProfile!['id']}/${userProfile!['avatar']}'
        : 'assets/images/default_avatar.png';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Photo and Profile Picture
                    _buildCoverAndProfile(coverPhotoUrl, avatarUrl),

                    // Profile Info
                    _buildProfileInfo(),

                    // Gifts Section
                    _buildGiftsSection(),

                    // Badges Section
                    _buildBadgesSection(),

                    // Add bottom padding for better scrolling
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildCoverAndProfile(String coverPhotoUrl, String avatarUrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Photo - Made taller for better full-screen experience
        SizedBox(
          width: double.infinity,
          height: 200, // Increased height
          child: Image.network(
            coverPhotoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[900],
              child: const Icon(Icons.image, color: Colors.white24, size: 40),
            ),
          ),
        ),

        // Profile Picture
        Positioned(
          bottom: -50,
          left: 20,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[800],
                  child:
                      const Icon(Icons.person, color: Colors.white70, size: 50),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${userProfile!['firstname']} ${userProfile!['lastname']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (userProfile!['moto'] != null &&
              userProfile!['moto'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              userProfile!['moto'],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildGiftsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gifts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 75.w,
            child: gifts == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : gifts!.isEmpty
                    ? const Center(
                        child: Text('No gifts',
                            style: TextStyle(color: Colors.white70)))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: gifts!.length,
                        separatorBuilder: (_, __) => SizedBox(width: 16.w),
                        itemBuilder: (context, index) =>
                            _buildGiftItem(gifts![index]),
                      ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildGiftItem(Map<String, dynamic> gift) {
    final imageUrl =
        '$baseUrl/api/files/${gift['collectionId']}/${gift['id']}/${gift['gifphoto']}';
    return Column(
      children: [
        Container(
          width: 50.w,
          height: 50.w,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.card_giftcard,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'x${gift['giftCount']}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Badges',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100.w,
            child: badges == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : badges!.isEmpty
                    ? const Center(
                        child: Text('No badges',
                            style: TextStyle(color: Colors.white70)))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: badges!.length,
                        separatorBuilder: (_, __) => SizedBox(width: 16.w),
                        itemBuilder: (context, index) =>
                            _buildBadgeItem(badges![index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(Map<String, dynamic> badge) {
    final imageUrl =
        '$baseUrl/api/files/${badge['collectionId']}/${badge['id']}/${badge['badgePhoto']}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50.w,
          height: 50.w,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildBadgeImage(imageUrl),
          ),
        ),
        SizedBox(height: 5.h),
        SizedBox(
          width: 60.w,
          child: Text(
            badge['badgeName'] ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeImage(String imageUrl) {
    final extension = imageUrl.split('.').last.toLowerCase();

    if (extension == 'svg') {
      return SvgPicture.network(
        imageUrl,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50.w,
            height: 50.w,
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, size: 25.w),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    }
  }
}
