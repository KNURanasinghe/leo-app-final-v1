import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:leo_app_01/StartScreen.dart';
import 'package:leo_app_01/chat/chatting.dart';
import 'package:leo_app_01/firebase_options.dart';
import 'package:leo_app_01/services/firebase_service.dart';
import 'package:leo_app_01/splash.dart';
import 'package:provider/provider.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';
import 'package:zego_zimkit/zego_zimkit.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'Provider/broadcast_.dart';
import 'chat/default_dialogs.dart';

// Global Navigator key for accessing Navigator from outside of widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Make this available to the FirebaseService
void initializeGlobalKeys() {
  globalNavigatorKey = navigatorKey;
}

// Create a global instance of FirebaseService for easier access
final FirebaseService firebaseService = FirebaseService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize navigator key before Firebase initialization
  initializeGlobalKeys();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize notifications
    try {
      await firebaseService.initNotifications();
    } catch (e) {
      print('Failed to initialize notifications: $e');
      // Continue app initialization regardless of notification failure
    }
  } catch (e) {
    print('Failed to initialize Firebase: $e');
    // Continue without Firebase
  }

  // Initialize the ZEGOCLOUD SDK
  ZIMKit().init(
    appID: 970649463,
    appSign: '208a410cd46ba9cc218ebfbf27e366c1247991300164ae66512cce6eab7ec74c',
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
            navigatorKey: navigatorKey, // This is used for global navigation
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
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Create a screen for handling incoming calls
class IncomingCallScreen extends StatelessWidget {
  final String callerId;
  final String callerName;
  final bool isVideoCall;
  final String roomId;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.isVideoCall,
    required this.roomId,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue.withOpacity(0.2),
              child: Icon(
                isVideoCall ? Icons.videocam : Icons.call,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              callerName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideoCall ? 'Incoming Video Call' : 'Incoming Voice Call',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const Spacer(flex: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onTap: () {
                    onDecline();
                    Navigator.of(context).pop();
                  },
                  label: 'Decline',
                ),
                _buildCallButton(
                  icon: Icons.call,
                  color: Colors.green,
                  onTap: () {
                    onAccept();
                    Navigator.of(context).pop();
                    // Navigate to call screen or initiate call here
                    // For example, using TUICallKit:
                    // TUICallKit.instance.join(roomId);
                  },
                  label: 'Accept',
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

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
                leading: Icon(Icons.history),
                title: Text('Call History', maxLines: 1)),
            onTap: () {
              // TODO: Navigate to call history screen
            },
          ),
        ];
      },
    );
  }
}
