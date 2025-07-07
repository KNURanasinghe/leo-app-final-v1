import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants.dart';
import 'badges/badges_screen.dart';
import 'edit_bio.dart';
import 'edit_motto.dart';
import 'edit_name_screen.dart';
import 'profile_edit_screen.dart';
import 'profile_screen.dart';
import 'gifts/gifts_screen.dart';
import 'rooms/voice_rooms_screen.dart';
import 'theme.dart';

class MainProfile extends StatelessWidget {
  final String userId;
  final String name;
  final String profileImgUrl;
  const MainProfile(
      {super.key,
      required this.name,
      required this.userId,
      required this.profileImgUrl});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      child: MaterialApp(
        title: 'Leo',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        themeMode: darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
        darkTheme: darkTheme,
        routes: {
          'profile': (context) => const ProfileScreen(),
          'gifts': (context) => const GiftsScreen(),
          'badges': (context) => const BadgesScreen(),
          'rooms': (context) => const VoiceRoomsScreen(),
          'edit-profile': (context) =>
              EditProfileScreen(firstname: name, userId: userId),
          'edit-name': (context) => EditNameScreen(userId: userId),
          'edit-bio': (context) => EditBio(
                userId: userId,
              ),
          'edit-motto': (context) => EditMotto(userId: userId),
        },
        initialRoute: 'profile',
      ),
    );
  }
}
