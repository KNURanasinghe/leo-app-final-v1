import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

const String GIFTER_API_URL =
    'http://145.223.21.62:6002'; // New port for gifter rankings

class TopGifterCard extends StatelessWidget {
  final Map<String, dynamic> userDetails;
  final double totalAmount;

  const TopGifterCard({
    super.key,
    required this.userDetails,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9370DB).withOpacity(0.95), // Medium purple
            const Color(0xFF4B0082).withOpacity(0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image.network(
                  'http://145.223.21.62:8090/api/files/${userDetails['collectionId']}/${userDetails['id']}/${userDetails['avatar']}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Last Week\'s Top Gifter',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userDetails['firstname'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userDetails['moto'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/diamond.png',
                    width: 16,
                    height: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    totalAmount.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RankingBottomSheet extends StatefulWidget {
  const RankingBottomSheet({super.key});

  @override
  _RankingBottomSheetState createState() => _RankingBottomSheetState();
}

class _RankingBottomSheetState extends State<RankingBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  Map<String, dynamic>? lastWeekTopGifter;
  String refreshMessage = '';
  List<Map<String, dynamic>> dailyRankings = [];
  List<Map<String, dynamic>> weeklyRankings = [];
  List<Map<String, dynamic>> monthlyRankings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _updateRefreshMessage();
    _loadData(); // Initial load
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _loadData();
    }
    _updateRefreshMessage();
  }

  void _updateRefreshMessage() {
    setState(() {
      switch (_tabController.index) {
        case 0:
          refreshMessage =
              'This ranking will refresh every day at 00:00 (GMT+5:30)';
          break;
        case 1:
          refreshMessage =
              'This ranking will refresh every Sunday at 00:00 (GMT+5:30)';
          break;
        case 2:
          refreshMessage =
              'This ranking will refresh at the end of every month (GMT+5:30)';
          break;
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      // Load data based on current tab
      switch (_tabController.index) {
        case 0:
          await _fetchDailyRankings();
          break;
        case 1:
          await _fetchWeeklyRankings();
          break;
        case 2:
          await _fetchMonthlyRankings();
          break;
      }

      // Always fetch last week's top gifter
      await _fetchLastWeekTopGifter();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchDailyRankings() async {
    try {
      final response =
          await http.get(Uri.parse('$GIFTER_API_URL/api/gifters/daily'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            dailyRankings = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      print('Error fetching daily rankings: $e');
    }
  }

  Future<void> _fetchWeeklyRankings() async {
    try {
      final response =
          await http.get(Uri.parse('$GIFTER_API_URL/api/gifters/weekly'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            weeklyRankings = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      print('Error fetching weekly rankings: $e');
    }
  }

  Future<void> _fetchMonthlyRankings() async {
    try {
      final response =
          await http.get(Uri.parse('$GIFTER_API_URL/api/gifters/monthly'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            monthlyRankings = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      print('Error fetching monthly rankings: $e');
    }
  }

  Future<void> _fetchLastWeekTopGifter() async {
    try {
      final response =
          await http.get(Uri.parse('$GIFTER_API_URL/api/gifters/last-week'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['data'] != null &&
            data['data'].isNotEmpty) {
          final topGifter = data['data'][0];
          setState(() {
            lastWeekTopGifter = {
              'userDetails': topGifter['userDetails'],
              'total': (topGifter['total'] is int)
                  ? topGifter['total'].toDouble()
                  : (topGifter['total'] ?? 0.0),
            };
          });
        }
      }
    } catch (e) {
      print('Error fetching last week top gifter: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (lastWeekTopGifter != null)
            TopGifterCard(
              userDetails: lastWeekTopGifter!['userDetails'],
              totalAmount: (lastWeekTopGifter!['total'] is int)
                  ? (lastWeekTopGifter!['total'] as int).toDouble()
                  : (lastWeekTopGifter!['total'] as double? ?? 0.0),
            ),
          // Tab bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'This Week'),
                Tab(text: 'This Month'),
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
                      _buildRankingList(monthlyRankings),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingList(List<Map<String, dynamic>> rankings) {
    return Column(
      children: [
        // Refresh time notice with consistent styling
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.withOpacity(0.1),
                Colors.blue.withOpacity(0.1),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  refreshMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // Rankings list
        Expanded(
          child: ListView.builder(
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

                    // Profile image with error handling
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: CachedNetworkImage(
                          imageUrl:
                              'http://145.223.21.62:8090/api/files/${userDetail['collectionId']}/${userDetail['id']}/${userDetail['avatar']}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => Icon(
                            Icons.person,
                            color: Colors.grey[400],
                            size: 30,
                          ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
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
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
