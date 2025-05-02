import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:leo_app_01/StartScreen.dart';
import 'package:leo_app_01/chat/chatting.dart';
import 'package:leo_app_01/splash.dart';
import 'package:provider/provider.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';
import 'package:zego_zimkit/zego_zimkit.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'package:flutter/cupertino.dart';
import 'Provider/broadcast_.dart';
import 'chat/default_dialogs.dart';
import 'services/socket_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the ZEGOCLOUD SDK
  ZIMKit().init(
    appID: 50134611,
    appSign: '3c478217fcd4ec348ae0783f6c12fb7171978dc4cc1399f5ca2f9f5234332d83',
  );

  ZegoUIKit().initLog().then((value) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BroadcastProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            navigatorObservers: [TUICallKit.navigatorObserver],
            navigatorKey: navigatorKey, // Add the navigator key
            debugShowCheckedModeBanner: false,
            title: 'ZEGOCLOUD Chat App',
            theme: ThemeData(
              fontFamily: 'Poppins',
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: Colors.white,
            ),
            home: const ZegoUIKitPrebuiltLiveAudioRoomMiniPopScope(
              child: SplashScreen(), // Your splash or main screen
            ),
            builder: (BuildContext context, Widget? child) {
              return Stack(
                children: [
                  child!,
                  ZegoUIKitPrebuiltLiveAudioRoomMiniOverlayPage(
                    contextQuery: () {
                      return navigatorKey.currentState!.context;
                    },
                    // Customize the minimized window appearance
                    size: const Size(120, 160),
                    showDevices: true,
                    showUserName: true,
                    showLeaveButton: true,
                    borderRadius: 12.0,
                    borderColor: Colors.blue.withOpacity(0.2),
                    backgroundColor: Colors.black.withOpacity(0.8),
                    soundWaveColor: Colors.purple,
                    supportClickZoom:
                        true, // Allow click-to-restore functionality
                  ),
                  // Positioned(
                  //   bottom: 20,
                  //   right: 20,
                  //   child: ElevatedButton(
                  //     onPressed: () {
                  //       if (ZegoUIKitPrebuiltLiveAudioRoomController().minimize.isMinimizing) {
                  //         ZegoUIKitPrebuiltLiveAudioRoomController().minimize.restore(context);
                  //       }
                  //     },
                  //     child: Text("Restore Audio Room"),
                  //   ),
                  //
                  // ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// class LoginPage extends StatefulWidget {
//   @override
//   _LoginPageState createState() => _LoginPageState();
// }
//
// class _LoginPageState extends State<LoginPage> {
//   final TextEditingController _userIdController = TextEditingController();
//   final TextEditingController _userNameController = TextEditingController();
//
//   void _login() {
//     String userId = _userIdController.text;
//     String userName = _userNameController.text;
//
//     ZIMKit().connectUser(id: userId, name: userName).then((_) {
//       Navigator.of(context).push(
//         MaterialPageRoute(builder: (context) => const ZIMKitDemoHomePage()),
//       );
//     }).catchError((error) {
//       // Handle login error
//       print("Login failed: $error");
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Login')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: _userIdController,
//               decoration: InputDecoration(labelText: 'User ID'),
//             ),
//             TextField(
//               controller: _userNameController,
//               decoration: InputDecoration(labelText: 'User Name'),
//             ),
//             SizedBox(height: 20),
//             ElevatedButton(onPressed: _login, child: const Text('Login')),
//           ],
//         ),
//       ),
//     );
//   }
// }

class ZIMKitDemoHomePage extends StatelessWidget {
  const ZIMKitDemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Conversations'),
          actions: const [HomePagePopupMenuButton()],
        ),
        body: ZIMKitConversationListView(
          onPressed: (context, conversation, defaultAction) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return ZIMKitMessageListPage(
                  conversationID: conversation.id,
                  conversationType: conversation.type,
                );
              },
            ));
          },
        ),
      ),
    );
  }
}

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
            value: 'Call History',
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
        ];
      },
    );
  }
}
