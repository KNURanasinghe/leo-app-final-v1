import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants.dart';

class AccountTile extends StatelessWidget {
  AccountTile({
    super.key,
    required this.text,
    required this.icon,
    required this.endWidget,
    required this.onTap,
    required this.isUpcomming,
  });

  final String text;
  final IconData icon;
  final Widget endWidget;
  final GestureTapCallback onTap;
  bool isUpcomming = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 10.0,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: darkModeEnabled ? kDarkTextColor : kTextColor,
              grade: 200,
              weight: 600,
            ),
            SizedBox(
              width: 15.w,
            ),
            Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              width: 15.w,
            ),
            // if (isUpcomming)
            //   Container(
            //     height: 50,
            //     width: 50,
            //     decoration: BoxDecoration(
            //       borderRadius: BorderRadius.circular(20),
            //       color: darkModeEnabled ? Colors.grey[800] : Colors.grey[200],
            //     ),
            //     child: ClipRRect(
            //       borderRadius: BorderRadius.circular(20),
            //       child: const Image(
            //         image: AssetImage('assets/comingzoon1.jpg'),
            //         fit: BoxFit.cover,
            //       ),
            //     ),
            //   ),
            const Spacer(),
            endWidget,
          ],
        ),
      ),
    );
  }
}
