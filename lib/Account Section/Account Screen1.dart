import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'constants.dart';
import 'edit profile/theme.dart';
import 'edit profile/widgets/account_edit_tile.dart';
import 'edit profile/widgets/back_button.dart';
import 'edit profile/widgets/body_container.dart';
import 'edit profile/widgets/text_with_arrow.dart';

class AccountScreen1 extends StatelessWidget {
  const AccountScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        centerTitle: true,
        title: Text(
          'My Account',
          style: TextStyle(
            fontSize: 16.sp,
            color: darkModeEnabled ? kDarkTextColor : kTextColor,
          ),
        ),
      ),
      body: BodyContainer(
        padding: const EdgeInsets.all(20.0),
        enableScroll: true,
        child: Column(
          children: [
            Material(
              color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
              shadowColor: Colors.black26,
              elevation: 5,
              borderRadius: BorderRadius.circular(10.w),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(10.w),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20.0, horizontal: 20.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30.w),
                          child: Image.asset(
                            'assets/images/avatar.png',
                            width: 60.w,
                            height: 60.w,
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
                              'Gihan Fernando',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: kTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Phone: 077 5580 646',
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
            ),
            SizedBox(
              height: 15.w,
            ),
            Material(
              color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
              shadowColor: Colors.black26,
              elevation: 5,
              borderRadius: BorderRadius.circular(10.w),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 10.0),
                child: Column(
                  children: [
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.wallet,
                      text: 'Wallet',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                    const Divider(
                      color: Colors.black12,
                      thickness: 0.3,
                    ),
                    AccountTile(
                      isUpcomming: true,
                      icon: Icons.diamond_outlined,
                      text: 'Earn diamond',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 15.w,
            ),
            Material(
              color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
              shadowColor: Colors.black26,
              elevation: 5,
              borderRadius: BorderRadius.circular(10.w),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 10.0),
                child: Column(
                  children: [
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.leaderboard_outlined,
                      text: 'Level',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                    const Divider(
                      color: Colors.black12,
                      thickness: 0.3,
                    ),
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.wallet_giftcard_outlined,
                      text: 'Nobel',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                    const Divider(
                      color: Colors.black12,
                      thickness: 0.3,
                    ),
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.workspace_premium_outlined,
                      text: 'Svip',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                    const Divider(
                      color: Colors.black12,
                      thickness: 0.3,
                    ),
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.favorite_border_rounded,
                      text: 'Cp space',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                    const Divider(
                      color: Colors.black12,
                      thickness: 0.3,
                    ),
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.family_restroom_rounded,
                      text: 'Family',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 15.w,
            ),
            Material(
              color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
              shadowColor: Colors.black26,
              elevation: 5,
              borderRadius: BorderRadius.circular(10.w),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 10.0),
                child: Column(
                  children: [
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.add_chart_outlined,
                      text: 'Achievement',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                    const Divider(
                      color: Colors.black12,
                      thickness: 0.3,
                    ),
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.list,
                      text: 'My items',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                    const Divider(
                      color: Colors.black12,
                      thickness: 0.3,
                    ),
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.group_add_outlined,
                      text: 'Invited friends',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 15.w,
            ),
            Material(
              color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
              shadowColor: Colors.black26,
              elevation: 5,
              borderRadius: BorderRadius.circular(10.w),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 10.0),
                child: Column(
                  children: [
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.language_outlined,
                      text: 'Language',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                    const Divider(
                      color: Colors.black12,
                      thickness: 0.3,
                    ),
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.feedback_outlined,
                      text: 'Feedback',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                    const Divider(
                      color: Colors.black12,
                      thickness: 0.3,
                    ),
                    AccountTile(
                      isUpcomming: false,
                      icon: Icons.settings_outlined,
                      text: 'Setting',
                      onTap: () {},
                      endWidget: const TextWithArrow(
                        text: '',
                        showArrow: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
