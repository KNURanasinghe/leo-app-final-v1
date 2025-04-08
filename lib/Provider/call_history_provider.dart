import 'dart:convert';

import 'package:leo_app_01/models/call_istory_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallHistoryService {
  // Singleton pattern
  static final CallHistoryService _instance = CallHistoryService._internal();
  factory CallHistoryService() => _instance;
  CallHistoryService._internal();

  final List<CallHistoryEntry> _callHistory = [];

  // Get all call history entries
  List<CallHistoryEntry> get allCalls => _callHistory;

  // Add a new call to history
  void addCall(CallHistoryEntry call) {
    _callHistory.add(call);
    // You might want to save to local storage here
  }

  // Load call history from storage

  // You can add methods to filter call history:
  List<CallHistoryEntry> getMissedCalls() {
    return _callHistory.where((call) => call.isMissed).toList();
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = _callHistory
        .map((call) => {
              'callId': call.callId,
              'callerId': call.callerId,
              'receiverId': call.receiverId,
              'isOutgoing': call.isOutgoing,
              'isVideoCall': call.isVideoCall,
              'isMissed': call.isMissed,
              'timestamp': call.timestamp,
              'roomId': call.roomId,
            })
        .toList();

    await prefs.setString('call_history', jsonEncode(historyJson));
    print('Call history saved: $historyJson');
  }

// Update the load method
  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('call_history');
    print('Call history loaded: $historyJson');
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      _callHistory.clear();

      for (final item in decoded) {
        _callHistory.add(CallHistoryEntry(
          callId: item['callId'],
          callerId: item['callerId'],
          receiverId: item['receiverId'],
          isOutgoing: item['isOutgoing'],
          isVideoCall: item['isVideoCall'],
          isMissed: item['isMissed'],
          timestamp: item['timestamp'],
          roomId: item['roomId'],
        ));
      }
    }
    print('Call history loaded: $_callHistory');
  }
}
