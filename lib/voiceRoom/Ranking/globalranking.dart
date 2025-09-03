import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:leo_app_01/voiceRoom/Ranking/rewards.dart';
import 'package:leo_app_01/voiceRoom/Ranking/rules.dart';
import 'TopGifter.dart';
import 'TopRecharger.dart';
import 'TopStar.dart';
import 'package:country_picker/country_picker.dart';

// Add this constant at the top of your file
const String ROOM_API_URL = 'http://145.223.21.62:6003';

class TopRoomCard extends StatelessWidget {
  final Map<String, dynamic> roomDetails;
  final double totalAmount;

  const TopRoomCard({
    super.key,
    required this.roomDetails,
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
            const Color(0xFFFF8C00).withOpacity(0.95), // Dark orange
            const Color(0xFFDC143C).withOpacity(0.90),
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
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl:
                      'http://145.223.21.62:8090/api/files/voiceRooms/${roomDetails['id']}/${roomDetails['group_photo']}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.image_not_supported,
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
                      SizedBox(width: 4),
                      Text(
                        'Last Week\'s Top Room',
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
                    roomDetails['voice_room_name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    roomDetails['team_moto'] ?? '',
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

class GlobalRanking extends StatefulWidget {
  const GlobalRanking({super.key});

  @override
  _GlobalRankingState createState() => _GlobalRankingState();
}

class _GlobalRankingState extends State<GlobalRanking>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String currentCategory = 'TopRooms';
  bool isLoading = true;
  String refreshMessage = '';

  // Rankings data
  Map<String, dynamic>? lastWeekTopRoom;
  List<Map<String, dynamic>> dailyRankings = [];
  List<Map<String, dynamic>> weeklyRankings = [];
  List<Map<String, dynamic>> monthlyRankings = [];

  // Cache mechanism
  static final Map<String, List<Map<String, dynamic>>> _rankingsCache = {};
  static final Map<String, DateTime> _lastFetchTime = {};
  static const cacheDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchDailyRankings();
    _updateRefreshMessage();
    _loadData();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _updateRefreshMessage();
      _loadData();
    }
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
              'This ranking will refresh at the end of every month at 00:00 (GMT+5:30)';
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

      // Always fetch last week's top room
      await _fetchLastWeekTopRoom();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchDailyRankings() async {
    if (_isCacheValid('daily')) {
      setState(() {
        dailyRankings = _rankingsCache['daily'] ?? [];
      });
      return;
    }

    try {
      final response =
          await http.get(Uri.parse('$ROOM_API_URL/api/rooms/daily'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            dailyRankings = List<Map<String, dynamic>>.from(data['data']);
            _rankingsCache['daily'] = dailyRankings;
            _lastFetchTime['daily'] = DateTime.now();
          });
        }
      }
    } catch (e) {
      print('Error fetching daily rankings: $e');
    }
  }

  Future<void> _fetchWeeklyRankings() async {
    if (_isCacheValid('weekly')) {
      setState(() {
        weeklyRankings = _rankingsCache['weekly'] ?? [];
      });
      return;
    }

    try {
      final response =
          await http.get(Uri.parse('$ROOM_API_URL/api/rooms/weekly'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            weeklyRankings = List<Map<String, dynamic>>.from(data['data']);
            _rankingsCache['weekly'] = weeklyRankings;
            _lastFetchTime['weekly'] = DateTime.now();
          });
        }
      }
    } catch (e) {
      print('Error fetching weekly rankings: $e');
    }
  }

  Future<void> _fetchMonthlyRankings() async {
    if (_isCacheValid('monthly')) {
      setState(() {
        monthlyRankings = _rankingsCache['monthly'] ?? [];
      });
      return;
    }

    try {
      final response =
          await http.get(Uri.parse('$ROOM_API_URL/api/rooms/monthly'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            monthlyRankings = List<Map<String, dynamic>>.from(data['data']);
            _rankingsCache['monthly'] = monthlyRankings;
            _lastFetchTime['monthly'] = DateTime.now();
          });
        }
      }
    } catch (e) {
      print('Error fetching monthly rankings: $e');
    }
  }

  Future<void> _fetchLastWeekTopRoom() async {
    try {
      final response =
          await http.get(Uri.parse('$ROOM_API_URL/api/rooms/last-week'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['data'] != null &&
            data['data'].isNotEmpty) {
          final topRoom = data['data'][0];
          setState(() {
            lastWeekTopRoom = {
              'roomDetails': topRoom['roomDetails'],
              'total': (topRoom['total'] is int)
                  ? topRoom['total'].toDouble()
                  : (topRoom['total'] ?? 0.0),
            };
          });
        }
      }
    } catch (e) {
      print('Error fetching last week top room: $e');
    }
  }

  bool _isCacheValid(String key) {
    final lastFetch = _lastFetchTime[key];
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < cacheDuration;
  }

  Widget _buildRankingList(List<Map<String, dynamic>> rankings) {
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
                Colors.orange.withOpacity(0.1),
                Colors.red.withOpacity(0.1),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              final ranking = rankings[index];
              final roomDetails = ranking['roomDetails'];
              final ownerDetails = ranking['ownerDetails'];

              if (roomDetails == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Rank number/medal
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

                    // Room image
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl:
                              'http://145.223.21.62:8090/api/files/${roomDetails['collectionId']}/${roomDetails['id']}/${roomDetails['group_photo']}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Room details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roomDetails['voice_room_name'] ?? 'Unnamed Room',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 16,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 0.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _buildCountryFlag(
                                    roomDetails['voiceRoom_country']),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  roomDetails['team_moto'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
          ),
        ),
      ],
    );
  }

  Widget _buildCountryFlag(String? countryName) {
    if (countryName == null || countryName.isEmpty) {
      return Icon(
        Icons.flag_outlined,
        size: 12,
        color: Colors.grey[400],
      );
    }

    return CachedNetworkImage(
      imageUrl: _getFlagUrl(countryName),
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[100],
        child: Icon(
          Icons.flag_outlined,
          size: 12,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  String _getFlagUrl(String? countryName) {
    if (countryName == null || countryName.isEmpty) {
      return 'https://flagcdn.com/w320/xx.png'; // Fallback flag
    }

    try {
      final countryService = CountryService();
      final country = countryService.findByName(countryName);
      if (country != null) {
        return 'https://flagcdn.com/w320/${country.countryCode.toLowerCase()}.png';
      }
    } catch (e) {
      print('Error finding country code: $e');
    }
    return 'https://flagcdn.com/w320/xx.png'; // Fallback flag
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ranking',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'rewards') {
                showRankingRewardPopup(context);
              } else if (value == 'rules') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RulesPage()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'rewards',
                child: Text('Rewards'),
              ),
              const PopupMenuItem<String>(
                value: 'rules',
                child: Text('Rules'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category buttons row
          SizedBox(
            height: 60,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCategoryButton(
                    'Top Rooms',
                    [
                      const Color(0xFFFF8C00).withOpacity(0.95),
                      const Color(0xFFDC143C).withOpacity(0.90),
                    ],
                    'TopRooms',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryButton(
                    'Top Gifters',
                    [
                      const Color(0xFF9370DB).withOpacity(0.95),
                      const Color(0xFF4B0082).withOpacity(0.90),
                    ],
                    'TopGifters',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryButton(
                    'Top Stars',
                    [
                      const Color(0xFF3CB371).withOpacity(0.95),
                      const Color(0xFF006400).withOpacity(0.90),
                    ],
                    'TopStars',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryButton(
                    'Top Recharger',
                    [
                      const Color(0xFF4682B4).withOpacity(0.95),
                      const Color(0xFF0000CD).withOpacity(0.90),
                    ],
                    'Billionaires',
                  ),
                ],
              ),
            ),
          ),

          // Top Room Card
          if (currentCategory == 'TopRooms' && lastWeekTopRoom != null)
            TopRoomCard(
              roomDetails: lastWeekTopRoom!['roomDetails'],
              totalAmount: (lastWeekTopRoom!['total'] is int)
                  ? (lastWeekTopRoom!['total'] as int).toDouble()
                  : (lastWeekTopRoom!['total'] as double),
            ),

          // TabBar for TopRooms category
          if (currentCategory == 'TopRooms')
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'This Week'),
                  Tab(text: 'This Month'),
                ],
              ),
            ),

          // Loading indicator
          if (isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          // Content area
          else
            Expanded(
              child: _buildSelectedCategory(),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedCategory() {
    switch (currentCategory) {
      case 'TopRooms':
        return Column(
          children: [
            Expanded(
              child: TabBarView(
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
      case 'TopGifters':
        return const RankingBottomSheet();
      case 'TopStars':
        return const Topstar();
      case 'Billionaires':
        return const RechargeRankings();
      default:
        return Center(
          child: Text('Category not found',
              style: TextStyle(color: Colors.grey[600])),
        );
    }
  }

  Widget _buildCategoryButton(
      String title, List<Color> gradientColors, String category) {
    bool isSelected = currentCategory == category;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () {
          setState(() {
            currentCategory = category;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 18 : 15,
            vertical: isSelected ? 10 : 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: isSelected ? 14 : 12,
            ),
          ),
        ),
      ),
    );
  }

  void showRankingRewardPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) =>
          const RankingRewardPopup(),
      transitionBuilder: (context, animation1, animation2, child) {
        return FadeTransition(
          opacity: animation1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation1, curve: Curves.easeOutQuad),
            ),
            child: child,
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
