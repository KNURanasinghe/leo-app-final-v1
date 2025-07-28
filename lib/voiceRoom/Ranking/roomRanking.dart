import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RankingBottomSheet extends StatefulWidget {
  final String roomId;

  const RankingBottomSheet({super.key, required this.roomId});

  @override
  _RankingBottomSheetState createState() => _RankingBottomSheetState();
}

class _RankingBottomSheetState extends State<RankingBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  List<Map<String, dynamic>> dailyRankings = [];
  List<Map<String, dynamic>> weeklyRankings = [];
  List<Map<String, dynamic>> totalRankings = [];
  Map<String, double> diamondAmounts = {};
  Map<String, dynamic> userDetails = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      await Future.wait([
        _fetchGiftDiamondAmounts(),
        _fetchRankings(),
      ]);
      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchGiftDiamondAmounts() async {
    try {
      print('Fetching gift diamond amounts...');
      int page = 1;
      const int perPage = 50000;
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/gifts/records?page=$page&perPage=$perPage'),
      );
      print('diamond re ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;

        diamondAmounts = Map.fromEntries(items.map((item) => MapEntry(
              item['giftname'],
              (item['diamond_amount'] as num).toDouble(),
            )));
        print('Fetched diamond amounts: $diamondAmounts');
      }
    } catch (e) {
      print('Error fetching diamond amounts: $e');
    }
  }

  Future<void> _fetchUserDetails(String userId) async {
    if (userDetails.containsKey(userId)) return;

    try {
      print('Fetching user details for ID: $userId');
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/$userId'),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        userDetails[userId] = userData;
        print('Fetched user details: ${userDetails[userId]}');
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }

  // Future<void> _fetchRankings() async {
  //   try {
  //     print('Fetching rankings for room: ${widget.roomId}');
  //     final response = await http.get(
  //       Uri.parse(
  //           'http://145.223.21.62:8090/api/collections/sending_recieving_gifts/records?filter=(voiceRoomId="${widget.roomId}")'),
  //     );

  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       final gifts = data['items'] as List;

  //       // Process for daily rankings
  //       final now = DateTime.now();
  //       final today = DateTime(now.year, now.month, now.day);
  //       final dailyGifts = gifts
  //           .where((gift) => DateTime.parse(gift['created']).isAfter(today))
  //           .toList();

  //       // Process for weekly rankings
  //       final weekAgo = now.subtract(const Duration(days: 7));
  //       final weeklyGifts = gifts
  //           .where((gift) => DateTime.parse(gift['created']).isAfter(weekAgo))
  //           .toList();

  //       // Calculate rankings
  //       dailyRankings = await _calculateRankings(dailyGifts);
  //       weeklyRankings = await _calculateRankings(weeklyGifts);
  //       totalRankings = await _calculateRankings(gifts);

  //       setState(() {});
  //     }
  //   } catch (e) {
  //     print('Error fetching rankings: $e');
  //   }
  // }

  Future<void> _fetchRankings() async {
    try {
      print('Fetching rankings for room: ${widget.roomId}');

      List<dynamic> allGifts = [];
      int page = 1;
      const int perPage = 500000; // Adjust based on your needs and API limits
      bool hasMoreData = true;

      // Fetch all pages
      while (hasMoreData) {
        final response = await http.get(
          Uri.parse(
              'http://145.223.21.62:8090/api/collections/sending_recieving_gifts/records?filter=(voiceRoomId="${widget.roomId}")&page=$page&perPage=$perPage&sort=-created'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final gifts = data['items'] as List;
          print('data from ranking ${data.toString()}');

          if (gifts.isEmpty) {
            hasMoreData = false;
          } else {
            allGifts.addAll(gifts);

            // Check if we've fetched all available records
            final totalItems = data['totalItems'] as int;
            final totalPages = data['totalPages'] as int;

            if (page >= totalPages || allGifts.length >= totalItems) {
              hasMoreData = false;
            } else {
              page++;
            }
          }

          print('Fetched page $page, total gifts so far: ${allGifts.length}');
        } else {
          print('Error: HTTP ${response.statusCode}');
          hasMoreData = false;
        }
      }

      print('Total gifts fetched: ${allGifts.length}');

      // Process for daily rankings
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dailyGifts = allGifts
          .where((gift) => DateTime.parse(gift['created']).isAfter(today))
          .toList();

      // Process for weekly rankings
      final weekAgo = now.subtract(const Duration(days: 7));
      final weeklyGifts = allGifts
          .where((gift) => DateTime.parse(gift['created']).isAfter(weekAgo))
          .toList();

      // Calculate rankings
      dailyRankings = await _calculateRankings(dailyGifts);
      weeklyRankings = await _calculateRankings(weeklyGifts);
      totalRankings = await _calculateRankings(allGifts);
      print(
          'Daily rankings: $dailyRankings   Weekly rankings: $weeklyRankings');

      setState(() {});
    } catch (e) {
      print('Error fetching rankings: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _calculateRankings(
      List<dynamic> gifts) async {
    Map<String, double> userTotals = {};

    for (var gift in gifts) {
      final senderId = gift['sender_user_id'];
      final giftName = gift['giftname'];
      final count = gift['gift_count'] as int;
      final diamondAmount = diamondAmounts[giftName] ?? 0.0;

      userTotals[senderId] =
          (userTotals[senderId] ?? 0) + (count * diamondAmount);
      await _fetchUserDetails(senderId);
    }

    var sortedUsers = userTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedUsers
        .map((entry) => {
              'userId': entry.key,
              'total': entry.value,
              'userDetails': userDetails[entry.key],
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Center-aligned title row
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  'Contribution',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Daily'),
                Tab(text: 'Weekly'),
                Tab(text: 'Total'),
              ],
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRankingList(dailyRankings),
                      _buildRankingList(weeklyRankings),
                      _buildRankingList(totalRankings),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingList(List<Map<String, dynamic>> rankings) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: rankings.length,
      itemBuilder: (context, index) {
        final ranking = rankings[index];
        final userDetail = ranking['userDetails'];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Rank number or medal
              Container(
                width: 30,
                margin: const EdgeInsets.only(right: 12),
                child: index < 3
                    ? Image.asset('assets/images/medal${index + 1}.png')
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
              ),

              // Profile image
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!),
                  image: DecorationImage(
                    image: NetworkImage(
                        'http://145.223.21.62:8090/api/files/${userDetail['collectionId']}/${userDetail['id']}/${userDetail['avatar']}'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Name and motto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userDetail['firstname'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      userDetail['moto'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Diamond amount
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/diamond.png',
                    width: 16,
                    height: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ranking['total'].toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
