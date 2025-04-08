import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:leo_app_01/widgets/call_history.dart';
import 'package:zego_zimkit/zego_zimkit.dart';
import 'default_dialogs.dart';

class HomePagePopupMenuButton extends StatefulWidget {
  const HomePagePopupMenuButton({super.key});

  @override
  State<HomePagePopupMenuButton> createState() =>
      _HomePagePopupMenuButtonState();
}

class _HomePagePopupMenuButtonState extends State<HomePagePopupMenuButton> {
  final userIDController = TextEditingController();
  final groupNameController = TextEditingController();
  final groupUsersController = TextEditingController();
  final groupIDController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
      position: PopupMenuPosition.under,
      icon: const Icon(CupertinoIcons.add_circled),
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: 'New Chat',
            child: const ListTile(
              leading: Icon(CupertinoIcons.chat_bubble_2_fill),
              title: Text('New Chat', maxLines: 1),
            ),
            onTap: () => showDefaultNewPeerChatDialog(context),
          ),
          // PopupMenuItem(
          //   value: 'New Group',
          //   child: const ListTile(
          //     leading: Icon(CupertinoIcons.person_2_fill),
          //     title: Text('New Group', maxLines: 1),
          //   ),
          //   onTap: () => showDefaultNewGroupChatDialog(context),
          // ),
          // PopupMenuItem(
          //   value: 'Join Group',
          //   child: const ListTile(
          //       leading: Icon(Icons.group_add),
          //       title: Text('Join Group', maxLines: 1)),
          //   onTap: () => showDefaultJoinGroupDialog(context),
          // ),
          PopupMenuItem(
            value: 'Delete All',
            child: const ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete All', maxLines: 1)),
            onTap: () {
              ZIMKit().deleteAllConversation(
                isAlsoDeleteFromServer: true,
                isAlsoDeleteMessages: true,
              );
            },
          ),
          PopupMenuItem(
            value: 'Call History ',
            child: const ListTile(
                leading: Icon(Icons.phone_missed_sharp),
                title: Text('Call History', maxLines: 1)),
            onTap: () {
              Future.delayed(Duration.zero, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CallHistoryScreen()),
                );
              });
            },
          ),
        ];
      },
    );
  }
}
