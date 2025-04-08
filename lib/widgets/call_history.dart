import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leo_app_01/Provider/call_history_provider.dart';
import 'package:leo_app_01/models/call_istory_model.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CallHistoryService _historyService = CallHistoryService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await _historyService.loadHistory();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Missed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCallList(_historyService.allCalls),
          _buildCallList(_historyService.getMissedCalls()),
        ],
      ),
    );
  }

  Widget _buildCallList(List<CallHistoryEntry> calls) {
    if (calls.isEmpty) {
      return const Center(
        child: Text(
          'No call history',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Sort calls by timestamp (newest first)
    final sortedCalls = List<CallHistoryEntry>.from(calls)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      itemCount: sortedCalls.length,
      itemBuilder: (context, index) {
        final call = sortedCalls[index];
        return _buildCallItem(call);
      },
    );
  }

  Widget _buildCallItem(CallHistoryEntry call) {
    // Determine icon and color based on call properties
    IconData callIcon;
    Color iconColor;

    if (call.isVideoCall) {
      callIcon = call.isOutgoing ? Icons.videocam : Icons.videocam_outlined;
    } else {
      callIcon = call.isOutgoing ? Icons.call_made : Icons.call_received;
    }

    if (call.isMissed) {
      iconColor = Colors.red;
      callIcon =
          call.isOutgoing ? Icons.call_missed_outgoing : Icons.call_missed;
    } else {
      iconColor = Colors.green;
    }

    // Format timestamp
    final callTime = DateTime.fromMillisecondsSinceEpoch(call.timestamp);
    final timeString = DateFormat.yMMMd().add_jm().format(callTime);

    // You'd usually have a user service to look up user details by ID
    final otherUserId = call.isOutgoing ? call.receiverId : call.callerId;
    final otherUserName = "User: $otherUserId"; // Replace with actual user name

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[300],
        child: Icon(call.isVideoCall ? Icons.videocam : Icons.phone),
      ),
      title: Text(otherUserName),
      subtitle: Row(
        children: [
          Icon(callIcon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(timeString),
        ],
      ),
      trailing: IconButton(
        icon: Icon(call.isVideoCall ? Icons.videocam : Icons.call),
        onPressed: () {
          // Implement call back functionality
        },
      ),
      onTap: () {
        // Show call details or initiate a new call
      },
    );
  }
}
