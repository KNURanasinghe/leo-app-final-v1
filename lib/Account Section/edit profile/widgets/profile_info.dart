import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'level_tag.dart';

import '../../constants.dart';

class ProfileInfo extends StatelessWidget {
  final String userId;
  final String name;
  final String profileImgUrl;
  const ProfileInfo(
      {super.key,
      required this.name,
      required this.userId,
      required this.profileImgUrl});

  @override
  Widget build(BuildContext context) {
    final String validProfileImgUrl = profileImgUrl.isNotEmpty &&
            Uri.tryParse(profileImgUrl)?.hasAbsolutePath == true
        ? profileImgUrl
        : 'https://img.freepik.com/free-vector/portrait-boy-with-brown-hair-brown-eyes_1308-146018.jpg';
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(44.w),
          child: Image.network(
            validProfileImgUrl,
            width: 88.w,
            height: 88.w,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(
          width: 15.w,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
            ),
            SizedBox(
              height: 5.w,
            ),
            Text(
              'ID: $userId',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.normal,
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
            ),
            SizedBox(
              height: 5.w,
            ),
            // Row(
            //   children: [
            //     const LevelTag(
            //       text: 'Noble',
            //     ),
            //     SizedBox(
            //       width: 5.w,
            //     ),
            //     const LevelTag(
            //       text: 'Noble',
            //     ),
            //     SizedBox(
            //       width: 5.w,
            //     ),
            //     const LevelTag(
            //       text: 'Noble',
            //     ),
            //   ],
            // )
          ],
        )
      ],
    );
  }
}
