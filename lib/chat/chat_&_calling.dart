import 'package:flutter/material.dart';
import 'package:leo_app_01/chat/chat_list.dart';
import 'package:leo_app_01/widgets/status_create_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../HomeScreen.dart';
import '../widgets/admin_list.dart';
import '../widgets/status_screen.dart';
import 'HomePagePopMenu.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class ChatScreen1 extends StatefulWidget {
  final String userId;
  const ChatScreen1({super.key, required this.userId});

  @override
  ChatScreen1State createState() => ChatScreen1State();
}

class ChatScreen1State extends State<ChatScreen1>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int tabCount = 3;
  String currentUserId = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: 0,
    );
    _tabController.addListener(_handleTabChange);

//_fetchAndSetUserAvatar();
  }

  void _handleTabChange() {
    setState(() {});
  }

  void getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getString('userId') ?? '';
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildChatTab() {
    print('chat adn calling uid ${widget.userId}');
    return ChatListScreenUser(
      currentUserId: widget.userId,
      onNavigation: (bool visible) {
        // This replaces the HomeScreen.setBottomBarVisibility call
        HomeScreen.setBottomBarVisibility(visible);
      },
    );
  }

  Widget _buildStatusPage() {
    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: StatusScreen(currentUserId: widget.userId));
  }

  Widget _buildContactPage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: AdminListScreen(
        currentUserId: widget.userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primaryColor: Colors.blue[700],
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.blue[700],
        ),
      ),
      home: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            title: Text(
              'Messages',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            actions: const [HomePagePopupMenuButton()],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue[700],
              labelColor: Colors.blue[700],
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.chat_bubble)),
                Tab(icon: Icon(Icons.access_time)),
                Tab(icon: Icon(Icons.people)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildChatTab(),
              _buildStatusPage(),
              _buildContactPage(),
            ],
          ),
          // floatingActionButton: FloatingActionButton(
          //   onPressed: () {
          //     if (_tabController.index == 0) {
          //       const HomePagePopupMenuButton();
          //     } else {
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //           builder: (context) => StatusCreateScreen(
          //             currentUserId: widget.userId,
          //           ),
          //         ),
          //       );
          //     }
          //   },
          //   backgroundColor:
          //       _tabController.index != 2 ? Colors.blue[700] : null,
          //   child: Icon(
          //     _tabController.index == 0
          //         ? Icons.chat
          //         : _tabController.index == 1
          //             ? Icons.camera_alt
          //             : null,
          //   ),
          // ),
        ),
      ),
    );
  }
}
