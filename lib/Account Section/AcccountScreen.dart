import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:leo_app_01/Account%20Section/upcomming_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings.dart';
import '../widgets/feedback_screen.dart';
import '../widgets/language_page.dart';
import 'constants.dart';
import 'edit profile/theme.dart';
import 'edit profile/widgets/account_edit_tile.dart';
import 'edit profile/widgets/back_button.dart';
import 'edit profile/widgets/body_container.dart';
import 'edit profile/widgets/text_with_arrow.dart';
import 'wallet.dart';
import '../level/rankingpage.dart';
import '../nobel/profilepage.dart';
import 'Myitems.dart';
import 'achievement/achievement_screen.dart';
import 'invite friends/invite_screen.dart';
import 'edit profile/main_profile.dart';

class AccountScreen1 extends StatefulWidget {
  const AccountScreen1({super.key});

  @override
  State<AccountScreen1> createState() => _AccountScreen1State();
}

class _AccountScreen1State extends State<AccountScreen1> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  final String baseUrl = 'http://145.223.21.62:8090';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? 'd1k9aih2t9t9wo3';

      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/users/records/$userId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          userData = json.decode(response.body);

          // Convert phonenumber to string if it's not already
          if (userData != null && userData!['phonenumber'] is int) {
            userData!['phonenumber'] = userData!['phonenumber'].toString();
          }

          isLoading = false;
        });
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // leading: const AppBarBackButton(),
        centerTitle: true,
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 16.sp,
            color: darkModeEnabled ? kDarkTextColor : kTextColor,
          ),
        ),
      ),
      body: BodyContainer(
        padding: const EdgeInsets.all(20.0),
        enableScroll: true,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                // Remove SingleChildScrollView since BodyContainer handles it
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProfileSection(context),
                  SizedBox(height: 15.w),
                  _buildWalletSection(context),
                  SizedBox(height: 15.w),
                  _buildMainFeaturesSection(context),
                  SizedBox(height: 15.w),
                  _buildSecondaryFeaturesSection(context),
                  SizedBox(height: 15.w),
                  _buildSettingsSection(context),
                  SizedBox(height: 20.w),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    String? avatarUrl;
    if (userData != null && userData!['avatar'] != null) {
      avatarUrl =
          '$baseUrl/api/files/${userData!['collectionId']}/${userData!['id']}/${userData!['avatar']}';
    }

    return Material(
      color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
      shadowColor: Colors.black26,
      elevation: 5,
      borderRadius: BorderRadius.circular(10.w),
      child: InkWell(
        onTap: () => _navigateToViewProfile(context),
        borderRadius: BorderRadius.circular(10.w),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30.w),
                  child: avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          width: 60.w,
                          height: 60.w,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          'assets/images/avatar.png',
                          width: 60.w,
                          height: 60.w,
                          fit: BoxFit.cover,
                        ),
                ),
                SizedBox(width: 15.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData?['firstname'] ?? 'User',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: kTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      userData?['phonenumber'] ?? '94769146421',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: kAltTextColor,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SvgPicture.asset(
                  'assets/icons/ic-arrow-right.svg',
                  colorFilter: const ColorFilter.mode(
                      darkModeEnabled ? kDarkTextColor : kTextColor,
                      BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletSection(BuildContext context) {
    return Material(
      color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
      shadowColor: Colors.black26,
      elevation: 5,
      borderRadius: BorderRadius.circular(10.w),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
        child: Column(
          children: [
            AccountTile(
              isUpcomming: false,
              icon: Icons.wallet,
              text: 'Wallet',
              onTap: () => _navigateToWallet(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
            const Divider(color: Colors.black12, thickness: 0.3),
            AccountTile(
              isUpcomming: true,
              icon: Icons.diamond_outlined,
              text: 'Earn diamond',
              onTap: () => _navigateToEarnDiamond(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
          ],
        ),
      ),
    );
  }

  // Continue with other widget sections...

  // Navigation methods
  void _navigateToWallet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'd1k9aih2t9t9wo3';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WalletScreen(userId: userId)),
    );
  }

  void _navigateToViewProfile(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'd1k9aih2t9t9wo3';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainProfile(
          name: userData?['firstname'] ?? "User",
          userId: userId,
          profileImgUrl: userData?['avatar'] != null
              ? '$baseUrl/api/files/${userData!['collectionId']}/${userData!['id']}/${userData!['avatar']}'
              : "#",
        ),
      ),
    );
  }

  // Add these widget sections in the _AccountScreen1State class

  Widget _buildMainFeaturesSection(BuildContext context) {
    return Material(
      color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
      shadowColor: Colors.black26,
      elevation: 5,
      borderRadius: BorderRadius.circular(10.w),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
        child: Column(
          children: [
            AccountTile(
              isUpcomming: false,
              icon: Icons.leaderboard_outlined,
              text: 'Level',
              onTap: () => _navigateToLevel(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
            const Divider(color: Colors.black12, thickness: 0.3),
            AccountTile(
              isUpcomming: false,
              icon: Icons.wallet_giftcard_outlined,
              text: 'Nobel',
              onTap: () => _navigateToNobel(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
            const Divider(color: Colors.black12, thickness: 0.3),
            AccountTile(
              isUpcomming: true,
              icon: Icons.workspace_premium_outlined,
              text: 'Svip',
              onTap: () => _navigateToSVIP(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
            const Divider(color: Colors.black12, thickness: 0.3),
            AccountTile(
              isUpcomming: true,
              icon: Icons.favorite_border_rounded,
              text: 'Cp space',
              onTap: () => _navigateToCpSpace(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
            const Divider(color: Colors.black12, thickness: 0.3),
            AccountTile(
              isUpcomming: true,
              icon: Icons.family_restroom_rounded,
              text: 'Family',
              onTap: () => _navigateToFamily(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryFeaturesSection(BuildContext context) {
    return Material(
      color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
      shadowColor: Colors.black26,
      elevation: 5,
      borderRadius: BorderRadius.circular(10.w),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
        child: Column(
          children: [
            AccountTile(
              isUpcomming: false,
              icon: Icons.add_chart_outlined,
              text: 'Achievement',
              onTap: () => _navigateToAchievements(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
            const Divider(color: Colors.black12, thickness: 0.3),
            AccountTile(
              isUpcomming: false,
              icon: Icons.list,
              text: 'My items',
              onTap: () => _navigateToItems(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
            const Divider(color: Colors.black12, thickness: 0.3),
            AccountTile(
              isUpcomming: false,
              icon: Icons.group_add_outlined,
              text: 'Invited friends',
              onTap: () => _navigateToInviteFriends(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Material(
      color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
      shadowColor: Colors.black26,
      elevation: 5,
      borderRadius: BorderRadius.circular(10.w),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
        child: Column(
          children: [
            AccountTile(
              isUpcomming: false,
              icon: Icons.language_outlined,
              text: 'Language',
              onTap: () => _navigateToLanguage(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
            const Divider(color: Colors.black12, thickness: 0.3),
            AccountTile(
              isUpcomming: false,
              icon: Icons.feedback_outlined,
              text: 'Feedback',
              onTap: () => _navigateToFeedback(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
            const Divider(color: Colors.black12, thickness: 0.3),
            AccountTile(
              isUpcomming: false,
              icon: Icons.settings_outlined,
              text: 'Setting',
              onTap: () => _navigateToSettings(context),
              endWidget: const TextWithArrow(text: '', showArrow: true),
            ),
          ],
        ),
      ),
    );
  }

// Add these navigation methods in the _AccountScreen1State class

  void _navigateToEarnDiamond(BuildContext context) {
    // Implement earn diamond navigation
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ComingSoonScreen(screenTitle: "Earn Diamond")));
  }

  void _navigateToLevel(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'd1k9aih2t9t9wo3';
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RankingPagelevel(ID: userId)));
  }

  void _navigateToNobel(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'd1k9aih2t9t9wo3';
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => profilepage(userId: userId, ID: userId)));
  }

  void _navigateToSVIP(BuildContext context) {
    // Implement SVIP navigation
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ComingSoonScreen(screenTitle: "SVIP")));
  }

  void _navigateToCpSpace(BuildContext context) {
    // Implement CP space navigation
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ComingSoonScreen(screenTitle: "Cp Space")));
  }

  void _navigateToFamily(BuildContext context) {
    // Implement family navigation
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ComingSoonScreen(screenTitle: "Family")));
  }

  void _navigateToItems(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const StoreScreen()));
  }

  void _navigateToAchievements(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AchievementPage()));
  }

  void _navigateToInviteFriends(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InviteFriendsPage()),
    );
  }

  void _navigateToLanguage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LanguagePage()),
    );
  }

  void _navigateToFeedback(BuildContext context) {
    // Implement feedback navigation
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FeedbackScreen()),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

// Add remaining navigation methods...
}
