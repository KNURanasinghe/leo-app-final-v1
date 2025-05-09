import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import 'Account Section/AcccountScreen.dart';
import 'voiceRoom/groups.dart';
import 'chat/chat_&_calling.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'chat/Status.dart';

class HomeScreen extends StatefulWidget {
  static final GlobalKey<_HomeScreenState> homeKey =
      GlobalKey<_HomeScreenState>();
  final String userId;
  final String username;

  HomeScreen({required this.userId, required this.username})
      : super(key: homeKey); // Add the key here

  static void setBottomBarVisibility(bool visible) {
    homeKey.currentState?.setBottomNavVisibility(visible);
  }

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = "user";
  String userId = "";
  int _selectedIndex = 0;
  late List<Widget> _widgetOptions;
  bool _showBottomNav = true;

  void setBottomNavVisibility(bool visible) {
    setState(() {
      _showBottomNav = visible;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Fetch data from SharedPreferences or use the provided values
      username = prefs.getString('firstName') ?? widget.username;
      userId = prefs.getString('userId') ?? widget.userId;

      // Initialize _widgetOptions with required data
      _widgetOptions = [
        ChatScreen1(
          userId: widget.userId,
        ),
        const GroupsScreen(),
        const GameScreen(),
        const AccountScreen1(),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.isNotEmpty
            ? _widgetOptions.elementAt(_selectedIndex)
            : const CircularProgressIndicator(),
      ),
      bottomNavigationBar: _showBottomNav
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    color: Colors.black.withOpacity(.1),
                  )
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
                  child: GNav(
                    rippleColor: Colors.grey[300]!,
                    hoverColor: Colors.grey[100]!,
                    gap: 8,
                    activeColor: Colors.blue[700],
                    iconSize: 24,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    duration: const Duration(milliseconds: 400),
                    tabBackgroundColor: Colors.blue[50]!,
                    color: Colors.black,
                    tabs: const [
                      GButton(
                        icon: LineIcons.comments,
                        text: 'Chat',
                      ),
                      GButton(
                        icon: LineIcons.users,
                        text: 'Rooms',
                      ),
                      GButton(
                        icon: LineIcons.gamepad,
                        text: 'Game',
                      ),
                      GButton(
                        icon: LineIcons.user,
                        text: 'Account',
                      ),
                    ],
                    selectedIndex: _selectedIndex,
                    onTabChange: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// class ChatScreen1 extends StatefulWidget {
//   final String userId;
//   final String username;
//
//   ChatScreen1({required this.userId, required this.username});
//
//   @override
//   _ChatScreen1State createState() => _ChatScreen1State();
// }
//
// class _ChatScreen1State extends State<ChatScreen1> with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//   }
//
//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: Text(
//           'Chats',
//           style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.search, color: Colors.blue[700]),
//             onPressed: () {},
//           ),
//           IconButton(
//             icon: Icon(Icons.more_vert, color: Colors.blue[700]),
//             onPressed: () {},
//           ),
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: Colors.blue[700],
//           labelColor: Colors.blue[700],
//           unselectedLabelColor: Colors.grey,
//           tabs: [
//             Tab(text: 'CHATS'),
//             Tab(text: 'STATUS'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           ChatListView(),
//           StatusPage(),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {},
//         child: Icon(_tabController.index == 0 ? Icons.chat : Icons.camera_alt),
//         backgroundColor: Colors.blue[700],
//       ),
//     );
//   }
// }
//
// class ChatListView extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return ListView.builder(
//       itemCount: 20,
//       itemBuilder: (context, index) {
//         return ListTile(
//           leading: CircleAvatar(
//             backgroundImage: NetworkImage('https://picsum.photos/seed/${index + 1}/200'),
//           ),
//           title: Text('User ${index + 1}'),
//           subtitle: Text('Last message...'),
//           trailing: Text('12:00 PM'),
//         );
//       },
//     );
//   }
// }

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full background image
          Image.asset(
            'assets/images/gameback.jpeg', // Replace with your actual asset path
            fit: BoxFit.fitHeight,
          ),
          const SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Optional: Add game content here
                Text(
                  'Game Screen',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // You can add more widgets like game elements, buttons, etc.
              ],
            ),
          ),
        ],
      ),
    );
  }
}
