import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../widgets/body_container.dart';
import '../widgets/profile_info.dart';
import '../../constants.dart';
import '../widgets/back_button.dart';
import '../widgets/badge_grid_item.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  String? userId;
  String? name;
  String? profileImgUrl;
  List<Map<String, dynamic>> badges = [];
  final baseUrl = 'http://145.223.21.62:8090';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
      name = prefs.getString('firstName');
    });
    if (userId != null) {
      await Future.wait([
        fetchUserAvatar(),
        fetchUserBadges(),
      ]);
    }
  }

  String _formatIdToInteger(String userId) {
    int? intId;
    String displayId = 'N/A';

    try {
      if (userId.isNotEmpty) {
        intId = int.parse(userId, radix: 36);
        displayId = intId.toString();
        print('Converted ID: $intId');
      }
    } catch (e) {
      print('Error converting ID to integer: $e');
      // Fallback: use hash code or show original ID
      try {
        intId = userId.hashCode.abs();
        displayId = intId.toString();
      } catch (e2) {
        displayId = userId; // Show original ID as fallback
      }
    }

    return displayId;
  }

  Future<void> fetchUserAvatar() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/users/records/$userId'),
      );
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        setState(() {
          profileImgUrl = userData['avatar'] != null
              ? '$baseUrl/api/files/${userData['collectionId']}/${userData['id']}/${userData['avatar']}'
              : null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching avatar: $e');
    }
  }

  Future<void> fetchUserBadges() async {
    try {
      // First fetch received badges for the specific user
      final receivedBadgesResponse = await http.get(
        Uri.parse(
            '$baseUrl/api/collections/recieved_badges/records?filter=(userId="$userId")'),
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
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        centerTitle: true,
        title: Text(
          'Badges',
          style: TextStyle(
            fontSize: 16.sp,
            color: darkModeEnabled ? kDarkTextColor : kTextColor,
          ),
        ),
      ),
      body: BodyContainer(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userId != null && name != null)
              ProfileInfo(
                name: name!,
                userId: _formatIdToInteger(userId!),
                profileImgUrl: profileImgUrl ?? 'assets/images/avatar.png',
              ),
            SizedBox(height: 30.w),
            Text(
              'Earned Badges',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 16.sp,
                color: kPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20.w),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final badge = badges[index];
                  return BadgeGridItem(
                    icon:
                        '$baseUrl/api/files/${badge['collectionId']}/${badge['id']}/${badge['badgePhoto']}',
                    text: badge['badgeName'],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
