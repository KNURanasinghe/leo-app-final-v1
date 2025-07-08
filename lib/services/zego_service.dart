import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoService {
  static final ZegoService _instance = ZegoService._internal();

  factory ZegoService() => _instance;

  ZegoService._internal();

  // ZegoCloud credentials
  // These should be stored securely and preferably fetched from your server
  final int appID = 970649463;
  final String appSign =
      '208a410cd46ba9cc218ebfbf27e366c1247991300164ae66512cce6eab7ec74c';

  bool _isInitialized = false;

  // Stream IDs
  String? _localStreamID;
  String? _remoteStreamID;

  // Stream objects
  late ZegoExpressEngine _engine;

  // Initialize the ZegoCloud engine
  Future<void> initZegoEngine() async {
    if (_isInitialized) return;

    // Create ZegoEngineProfile
    ZegoEngineProfile profile = ZegoEngineProfile(
      appID,
      ZegoScenario.Default,
      appSign: appSign,
    );

    // Initialize ZegoExpressEngine
    await ZegoExpressEngine.createEngineWithProfile(profile);
    _engine = ZegoExpressEngine.instance;
    // Set up event handlers
    _setupEventHandlers();

    _isInitialized = true;
  }

  void _setupEventHandlers() {
    // Room state update
    ZegoExpressEngine.onRoomStateUpdate = (String roomID, ZegoRoomState state,
        int errorCode, Map<String, dynamic> extendedData) {
      print(
          'Room state update: roomID: $roomID, state: ${state.index}, errorCode: $errorCode');
    };

    // Stream update
    ZegoExpressEngine.onRoomStreamUpdate = (String roomID,
        ZegoUpdateType updateType,
        List<ZegoStream> streamList,
        Map<String, dynamic> extendedData) {
      if (updateType == ZegoUpdateType.Add) {
        // New streams added
        for (final stream in streamList) {
          print(
              'New stream added: ${stream.streamID} from user: ${stream.user.userID}');
          _remoteStreamID = stream.streamID;
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        // Streams removed
        for (final stream in streamList) {
          print('Stream removed: ${stream.streamID}');
          if (_remoteStreamID == stream.streamID) {
            _remoteStreamID = null;
          }
        }
      }
    };

    // Network quality update
    // Use the correct event handler based on your SDK version
    ZegoExpressEngine.onNetworkQuality = (String userID,
        ZegoStreamQualityLevel upstreamQuality,
        ZegoStreamQualityLevel downstreamQuality) {
      print(
          'Network quality update: userID: $userID, upstreamQuality: $upstreamQuality, downstreamQuality: $downstreamQuality');
    };
  }

  // Request necessary permissions
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    return statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted;
  }

  // Generate a token for authentication
  String generateToken(String userId, String roomId, {int expireTime = 3600}) {
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int expireTimestamp = currentTime + expireTime;

    final Map<String, dynamic> payload = {
      'app_id': appID,
      'user_id': userId,
      'room_id': roomId,
      'privilege': 1, // Use appropriate privilege level
      'create_time': currentTime,
      'expire_time': expireTimestamp
    };

    final String payloadString = jsonEncode(payload);
    final String signature = _generateSignature(payloadString);

    final token = '$signature:${base64Encode(utf8.encode(payloadString))}';
    print(
        "Generated token: ${token.substring(0, 20)}..."); // Log partial token for debugging

    return token;
  }

  String _generateSignature(String payload) {
    var key = utf8.encode(appSign);
    var bytes = utf8.encode(payload);
    var hmacSha256 = Hmac(sha256, key);
    var digest = hmacSha256.convert(bytes);
    return base64.encode(digest.bytes);
  }

  // Join a room
  Future<void> joinRoom(String roomId, String userId, String userName,
      {String? token}) async {
    if (!_isInitialized) {
      await initZegoEngine();
    }

    // Generate a proper token for each session
    final String roomToken = generateToken(userId, roomId);

    print(
        "Joining room with userId: $userId, roomId: $roomId, token length: ${roomToken.length}");

    try {
      // Use the token in room config
      await _engine.loginRoom(
        roomId,
        ZegoUser(userId, userName),
        config: ZegoRoomConfig(0, true, roomToken),
      );

      // Set the local stream ID with a proper format
      _localStreamID =
          '${roomId}_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      print("Local stream ID set to: $_localStreamID");
    } catch (e) {
      print("Error joining ZEGO room: $e");
    }
  }

  // Leave room
  Future<void> leaveRoom(String roomId) async {
    if (_isInitialized) {
      await _engine.logoutRoom(roomId);
      _localStreamID = null;
      _remoteStreamID = null;
    }
  }

  // Start local preview
  Future<void> startPreview(int viewID) async {
    if (!_isInitialized) return;

    ZegoCanvas canvas = ZegoCanvas(
      viewID,
      viewMode: ZegoViewMode.AspectFill,
    );

    await _engine.startPreview(canvas: canvas);
  }

  // Stop local preview
  Future<void> stopPreview() async {
    if (!_isInitialized) return;

    await _engine.stopPreview();
  }

  // Start publishing local stream
  // Update startPublishingStream method
  Future<void> startPublishingStream() async {
    if (!_isInitialized) {
      print("Engine not initialized when trying to publish stream");
      return;
    }

    if (_localStreamID == null || _localStreamID!.isEmpty) {
      print("Local stream ID is not set properly");
      _localStreamID = 'stream_${DateTime.now().millisecondsSinceEpoch}';
      print("Generated new stream ID: $_localStreamID");
    }

    try {
      print("Starting to publish stream: $_localStreamID");
      await _engine.startPublishingStream(_localStreamID!);
    } catch (e) {
      print("Error publishing stream: $e");
    }
  }

  // Stop publishing stream
  Future<void> stopPublishingStream() async {
    if (!_isInitialized || _localStreamID == null) return;

    await _engine.stopPublishingStream();
  }

  // Start playing a remote stream
  Future<void> startPlayingStream(String streamId, int viewID) async {
    if (!_isInitialized) return;

    ZegoCanvas canvas = ZegoCanvas(
      viewID,
      viewMode: ZegoViewMode.AspectFill,
    );

    await _engine.startPlayingStream(streamId, canvas: canvas);
  }

  // Stop playing a stream
  Future<void> stopPlayingStream(String streamId) async {
    if (!_isInitialized) return;

    await _engine.stopPlayingStream(streamId);
  }

  // Create a local stream with audio and video
  Future<void> createStream(
      {bool enableVideo = true, bool enableAudio = true}) async {
    if (!_isInitialized) return;

    await _engine.enableCamera(enableVideo);
    await _engine.mutePublishStreamAudio(!enableAudio);
  }

  // Enable/disable camera
  Future<void> enableCamera(bool enable) async {
    if (!_isInitialized) return;

    await _engine.enableCamera(enable);
  }

  // Enable/disable microphone
  Future<void> enableMicrophone(bool enable) async {
    if (!_isInitialized) return;

    await _engine.mutePublishStreamAudio(!enable);
  }

  // Switch camera (front/back)
  Future<void> switchCamera() async {
    if (!_isInitialized) return;

    await _engine.useFrontCamera(true);
  }

  // Use specific camera
  Future<void> useFrontCamera(bool useFront) async {
    if (!_isInitialized) return;

    await _engine.useFrontCamera(useFront);
  }

  // Enable/disable speaker
  Future<void> enableSpeaker(bool enable) async {
    if (!_isInitialized) return;

    await _engine.setAudioRouteToSpeaker(enable);
  }

  // Get call statistics
  Future<Map<String, dynamic>> getCallStats() async {
    if (!_isInitialized) return {};

    return {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Clean up resources
  Future<void> destroyEngine() async {
    if (_isInitialized) {
      await ZegoExpressEngine.destroyEngine();
      _isInitialized = false;
    }
  }

  // Getters for stream IDs
  String? get localStreamID => _localStreamID;
  String? get remoteStreamID => _remoteStreamID;

  // Check if engine is initialized
  bool get isInitialized => _isInitialized;
}
