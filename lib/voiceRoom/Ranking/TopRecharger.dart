import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

const String NODE_API_URL = 'http://145.223.21.62:6007';

class TopRechargerCard extends StatelessWidget {
  final Map<String, dynamic> userDetails;
  final double totalAmount;

  const TopRechargerCard({
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
            const Color(0xFF4682B4).withOpacity(0.95),
            const Color(0xFF0000CD).withOpacity(0.90),
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
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: CachedNetworkImage(
                  imageUrl:
                      'http://145.223.21.62:8090/api/files/${userDetails['collectionId']}/${userDetails['id']}/${userDetails['avatar']}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(
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
                      Icon(Icons.workspace_premium,
                          color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Last Week\'s Champion',
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ],
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
                  Image.asset('assets/images/diamond.png',
                      width: 16, height: 16),
                  const SizedBox(width: 4),
                  Text(
                    totalAmount.toStringAsFixed(0),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ],
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

class RechargeRankings extends StatefulWidget {
  const RechargeRankings({super.key});

  @override
  _RechargeRankingsState createState() => _RechargeRankingsState();
}

class _RechargeRankingsState extends State<RechargeRankings>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  List<Map<String, dynamic>> dailyRankings = [];
  List<Map<String, dynamic>> weeklyRankings = [];
  List<Map<String, dynamic>> monthlyRankings = [];
  Map<String, dynamic>? lastWeekTopRecharger;

  // Cache mechanism
  static final Map<String, List<Map<String, dynamic>>> _rankingsCache = {};
  static final Map<String, DateTime> _lastFetchTime = {};
  static const cacheDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadData(); // Initial load
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _loadData(); // Reload data when tab changes
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // Always fetch last week's top recharger
      await _fetchLastWeekTopRecharger();

      // Fetch rankings based on current tab
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
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchDailyRankings() async {
    try {
      final response =
          await http.get(Uri.parse('$NODE_API_URL/api/rankings/daily'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            dailyRankings =
                List<Map<String, dynamic>>.from(data['data'].map((item) => {
                      'userId': item['userId'],
                      'total': item['total'].toDouble(),
                      'userDetails': item['userDetails']
                    }));
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
          await http.get(Uri.parse('$NODE_API_URL/api/rankings/weekly'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            weeklyRankings =
                List<Map<String, dynamic>>.from(data['data'].map((item) => {
                      'userId': item['userId'],
                      'total': item['total'].toDouble(),
                      'userDetails': item['userDetails']
                    }));
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
          await http.get(Uri.parse('$NODE_API_URL/api/rankings/monthly'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            monthlyRankings =
                List<Map<String, dynamic>>.from(data['data'].map((item) => {
                      'userId': item['userId'],
                      'total': item['total'].toDouble(),
                      'userDetails': item['userDetails']
                    }));
          });
        }
      }
    } catch (e) {
      print('Error fetching monthly rankings: $e');
    }
  }

  Future<void> _fetchLastWeekTopRecharger() async {
    try {
      final response =
          await http.get(Uri.parse('$NODE_API_URL/api/rankings/last-week'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          final topRecharger = data['data'][0];
          setState(() {
            lastWeekTopRecharger = {
              'userDetails': topRecharger['userDetails'],
              'total': (topRecharger['total'] is int)
                  ? (topRecharger['total'] as int).toDouble()
                  : (topRecharger['total'] as double? ?? 0.0),
            };
          });
          await _verifyBillionaireBadge(topRecharger['userDetails']['id']);
        }
      }
    } catch (e) {
      print('Error fetching last week top recharger: $e');
    }
  }

  Future<bool> _verifyBillionaireBadge(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/recieved_badges/records?filter=userId="$userId"&fields=batch_name'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        bool hasBillionairBadge =
            items.any((item) => item['batch_name'] == 'billionair');

        if (!hasBillionairBadge) {
          final createResponse = await http.post(
            Uri.parse(
                'http://145.223.21.62:8090/api/collections/recieved_badges/records'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': userId,
              'batch_name': 'billionair',
              'created': DateTime.now().toIso8601String(),
              'updated': DateTime.now().toIso8601String(),
            }),
          );

          return createResponse.statusCode == 200;
        }
        return true;
      }
    } catch (e) {
      print('Error verifying billionaire badge: $e');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (lastWeekTopRecharger != null)
          TopRechargerCard(
            userDetails: lastWeekTopRecharger!['userDetails'],
            totalAmount: (lastWeekTopRecharger!['total'] is int)
                ? (lastWeekTopRecharger!['total'] as int).toDouble()
                : (lastWeekTopRecharger!['total'] as double? ?? 0.0),
          ),
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
    );
  }

  Widget _buildRankingList(List<Map<String, dynamic>> rankings) {
    String refreshMessage = '';
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
            'This ranking will refresh at the end of every month at 00:00 (GMT+5:30)';
        break;
    }

    return Column(
      children: [
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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              final ranking = rankings[index];
              final userDetail = ranking['userDetails'];

              if (userDetail == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
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
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.person,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
