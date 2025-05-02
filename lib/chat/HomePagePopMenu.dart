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
    return PopupMenuButton<String>(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
      position: PopupMenuPosition.under,
      icon: const Icon(CupertinoIcons.add_circled),
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'New Chat',
            child: ListTile(
              leading: Icon(
                CupertinoIcons.person_add,
                color: Colors.blue[600],
              ),
              title: const Text('New Chat', maxLines: 1),
              trailing: Text('>',
                  style: TextStyle(
                      color: Colors.grey.withOpacity(0.5), fontSize: 30)),
            ),
            onTap: () => showDefaultNewPeerChatDialog(context),
          ), // Custom divider
          PopupMenuItem<String>(
            enabled: false,
            height: 1,
            padding: EdgeInsets.zero,
            child: Container(
              height: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
          ),

          PopupMenuItem<String>(
            value: 'Call History',
            child: ListTile(
              leading: Icon(
                CupertinoIcons.phone_arrow_up_right,
                color: Colors.blue[600],
              ),
              title: const Text('Call History', maxLines: 1),
              trailing: Text('>',
                  style: TextStyle(
                      color: Colors.grey.withOpacity(0.5), fontSize: 30)),
            ),
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

          // Custom divider with explicit height and color
          PopupMenuItem<String>(
            enabled: false, // Make it non-selectable
            height: 1, // Minimal height
            padding: EdgeInsets.zero, // No padding
            child: Container(
              height: 1,
              color: Colors.grey.withOpacity(0.3), // Adjust opacity as needed
            ),
          ),

          PopupMenuItem<String>(
            value: 'Delete All',
            child: ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Colors.red[600],
              ),
              title: const Text('Delete All', maxLines: 1),
              trailing: Text('>',
                  style: TextStyle(
                      color: Colors.grey.withOpacity(0.5), fontSize: 30)),
            ),
            onTap: () {
              ZIMKit().deleteAllConversation(
                isAlsoDeleteFromServer: true,
                isAlsoDeleteMessages: true,
              );
            },
          ),
        ];
      },
    );
  }
}
