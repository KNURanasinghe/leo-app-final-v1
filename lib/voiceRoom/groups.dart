import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'Ranking/globalranking.dart';
import 'live_page.dart';
import 'voiceRoomCreate.dart';
import 'package:country_icons/country_icons.dart';
import 'package:country_picker/country_picker.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:country_flags/country_flags.dart';

class VoiceRoom {
  final String id;
  final String voiceRoomName;
  final int voiceRoomId;
  final String ownerId;
  final String voiceRoomCountry;
  final String teamMoto;
  final String groupPhoto;
  final String tags;
  final String backgroundImages;
  final String language; // Added language field

  VoiceRoom({
    required this.id,
    required this.voiceRoomName,
    required this.voiceRoomId,
    required this.ownerId,
    required this.voiceRoomCountry,
    required this.teamMoto,
    required this.groupPhoto,
    required this.tags,
    required this.backgroundImages,
    required this.language, // Added to constructor
  });

  factory VoiceRoom.fromJson(Map<String, dynamic> json) {
    return VoiceRoom(
      id: json['id'],
      voiceRoomName: json['voice_room_name'],
      voiceRoomId: json['voiceRoom_id'],
      ownerId: json['ownerId'],
      voiceRoomCountry: json['voiceRoom_country'],
      teamMoto: json['team_moto'],
      groupPhoto: json['group_photo'],
      tags: json['tags'],
      backgroundImages: json['background_images'],
      language: json['language'] ?? '', // Added with null safety
    );
  }
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final bool _isInitialMineLoad = true;
  String? _selectedCountry;
  final bool _showCountryDialog = false;
  final TextEditingController _countrySearchController =
      TextEditingController();

  final bool _isSearchingById = false;
  final TextEditingController _roomIdController = TextEditingController();

  late TabController _tabController;
  final List<String> _tabs = ["Discover", "Mine"];
  List<VoiceRoom> _allVoiceRooms = []; // For discover tab
  List<VoiceRoom> _myVoiceRooms = []; // For mine tab (created + joined)
  final List<VoiceRoom> _voiceRooms = [];
  String? _userId;
  String? _username;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _countries = [
    {'name': 'Sri Lanka', 'flag': 'https://flagcdn.com/w320/lk.png'},
    {'name': 'USA', 'flag': 'https://flagcdn.com/w320/us.png'},
    {'name': 'UK', 'flag': 'https://flagcdn.com/w320/gb.png'},
    {'name': 'Philippines', 'flag': 'https://flagcdn.com/w320/ph.png'},
    {'name': 'Australia', 'flag': 'https://flagcdn.com/w320/au.png'},
    {'name': 'Albania', 'flag': 'https://flagcdn.com/w320/al.png'},
    {'name': 'India', 'flag': 'https://flagcdn.com/w320/in.png'},
    {'name': 'Kuwait', 'flag': 'https://flagcdn.com/w320/kw.png'},
    {'name': 'Bangladesh', 'flag': 'https://flagcdn.com/w320/bd.png'},
  ];

  final Map<String, String> _tagPhotos = {};

  Future<void> _fetchTagPhotos() async {
    try {
      final response = await http.get(
        Uri.parse('http://145.223.21.62:8090/api/collections/tags/records'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tags = data['items'] as List;
        setState(() {
          for (var tag in tags) {
            _tagPhotos[tag['tag_name']] = tag['tag_photo'];
          }
        });
      }
    } catch (e) {
      print('Error fetching tag photos: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUserData();
    _fetchVoiceRooms(); // Initial fetch
    _fetchMineVoiceRooms(); // Initial fetch
    _fetchTagPhotos();

    // Add listener for lifecycle changes to handle refresh
    WidgetsBinding.instance.addObserver(this);

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this screen
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      _fetchVoiceRooms();
      _fetchMineVoiceRooms();
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _handleTabChange() {
    if (_tabController.index == 1) {
      // Mine tab
      _fetchMineVoiceRooms();
    } else {
      // Discover tab
      _fetchVoiceRooms();
    }
  }

  List<VoiceRoom> get filteredRoomsByCountry {
    var rooms = filteredRooms;

    // Filter by country if selected
    if (_selectedCountry != null) {
      rooms = rooms.where((room) {
        return room.voiceRoomCountry.toLowerCase() ==
            _selectedCountry!.toLowerCase();
      }).toList();
    }

    // Filter by room ID if searching
    if (_isSearchingById && _roomIdController.text.isNotEmpty) {
      rooms = rooms.where((room) {
        return room.voiceRoomId.toString().contains(_roomIdController.text);
      }).toList();
    }

    return rooms;
  }

  List<VoiceRoom> get filteredRooms {
    return _voiceRooms.where((room) {
      final query = _searchQuery.toLowerCase();
      return room.voiceRoomName.toLowerCase().contains(query) ||
          room.voiceRoomId.toString().toLowerCase().contains(query);
    }).toList();
  }

  String _getFlagUrl(String countryName) {
    try {
      // Create CountryService instance
      final countryService = CountryService();
      // Find country by name
      final country = countryService.findByName(countryName);
      if (country != null) {
        return 'https://flagcdn.com/w320/${country.countryCode.toLowerCase()}.png';
      }
    } catch (e) {
      print('Error finding country code: $e');
    }
    return 'https://flagcdn.com/w320/xx.png'; // Fallback flag
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
      _username = prefs.getString('firstName');
    });
  }

  Future<void> _fetchVoiceRooms() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/voiceRooms/records'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        setState(() {
          _allVoiceRooms =
              items.map((item) => VoiceRoom.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching voice rooms: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMineVoiceRooms() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      print('Debug: Fetching rooms for userId: $userId');

      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. First fetch self-created rooms
      final createdResponse = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/voiceRooms/records?filter=(ownerId="$userId")'),
      );

      // 2. Then fetch joined rooms list
      final joinedResponse = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/joined_users/records?filter=(userid="$userId")'),
      );

      print('Debug: Joined rooms API response: ${joinedResponse.body}');

      if (createdResponse.statusCode == 200 &&
          joinedResponse.statusCode == 200) {
        // Parse created rooms
        final createdRoomsData = json.decode(createdResponse.body);
        final createdRooms = (createdRoomsData['items'] as List)
            .map((item) => VoiceRoom.fromJson(item))
            .toList();

        print('Debug: Found ${createdRooms.length} created rooms');

        // Parse joined rooms data
        final joinedRoomsData = json.decode(joinedResponse.body);
        final joinedList = joinedRoomsData['items'] as List;
        print('Debug: Found ${joinedList.length} joined room records');

        // Fetch voice room details for each joined room
        List<VoiceRoom> joinedRooms = [];
        for (var joinedRoom in joinedList) {
          String voiceRoomId = joinedRoom['voice_room_id'];
          print('Debug: Fetching details for joined room ID: $voiceRoomId');

          // Fetch the actual room details
          final roomResponse = await http.get(
            Uri.parse(
                'http://145.223.21.62:8090/api/collections/voiceRooms/records?filter=(id="$voiceRoomId")'),
          );

          if (roomResponse.statusCode == 200) {
            final roomData = json.decode(roomResponse.body);
            if (roomData['items'] != null && roomData['items'].isNotEmpty) {
              final room = VoiceRoom.fromJson(roomData['items'][0]);
              joinedRooms.add(room);
              print(
                  'Debug: Successfully added joined room: ${room.voiceRoomName}');
            }
          }
        }

        // Combine both lists
        setState(() {
          _myVoiceRooms = [
            ...createdRooms,
            ...joinedRooms,
          ];
          print('Debug: Total rooms in mine tab: ${_myVoiceRooms.length}');
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Debug: Error in _fetchMineVoiceRooms: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkIfUserRemoved(String voiceRoomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        print('Debug: userId is null');
        return false;
      }

      print(
          'Debug: Checking removal status for userId: $userId and voiceRoomId: $voiceRoomId');

      // Using PocketBase's list filter syntax
      final encodedFilter = Uri.encodeComponent(
          'user_id="$userId" && voice_room_id="$voiceRoomId"');
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/removed_users/records?filter=($encodedFilter)'),
      );

      print('Debug: API Response Status Code: ${response.statusCode}');
      print('Debug: API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        final isRemoved = items.isNotEmpty;

        print('Debug: Found ${items.length} removal records');
        print('Debug: User removed status: $isRemoved');

        return isRemoved;
      }

      print('Debug: API call failed with status code: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Debug: Error checking if user is removed: $e');
      return false;
    }
  }

  Future<bool> _checkExistingRoom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        return false;
      }

      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/voiceRooms/records?filter=(ownerId="$userId")'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rooms = data['items'] as List;
        return rooms.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('Error checking existing room: $e');
      return false;
    }
  }

  void _navigateToCreateRoom() async {
    final hasExistingRoom = await _checkExistingRoom();

    if (!mounted) return;

    if (hasExistingRoom) {
      _showErrorDialog(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateVoiceRoomPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildStatsSquares(),
                          _buildCountriesSection(),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          tabs: _tabs
                              .map((String name) => Tab(text: name))
                              .toList(),
                          labelColor: Colors.blue[700],
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.blue[700],
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVoiceRoomsList(true),
                    _buildVoiceRoomsList(false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.lightBlue[50],
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by room name or ID...',
                  prefixIcon: const Icon(Icons.search, color: Colors.blue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _navigateToCreateRoom,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvertBanner() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: const DecorationImage(
          image: NetworkImage(
              'https://www.perfectly-nintendo.com/wp-content/uploads/2024/07/Battle-Crush.jpg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[50]!,
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  spreadRadius: 4,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.red[400],
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Room Already Exists',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  'You can only create one voice room at a time. Please delete your existing room before creating a new one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[700]!, Colors.blue[500]!],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceRoomsList(bool isDiscoverTab) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    List<VoiceRoom> roomsToShow;

    if (isDiscoverTab) {
      // Show all rooms in discover tab
      roomsToShow = _allVoiceRooms;

      // Apply country filter if selected
      if (_selectedCountry != null) {
        roomsToShow = roomsToShow.where((room) {
          return room.voiceRoomCountry.toLowerCase() ==
              _selectedCountry!.toLowerCase();
        }).toList();
      }
    } else {
      // Show mine and joined rooms in Mine tab
      roomsToShow = _myVoiceRooms;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      roomsToShow = roomsToShow.where((room) {
        return room.voiceRoomName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            room.voiceRoomId.toString().contains(_searchQuery);
      }).toList();
    }

    if (roomsToShow.isEmpty) {
      return Center(
        child: Text(
          _getEmptyMessage(isDiscoverTab),
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: roomsToShow.length,
      itemBuilder: (context, index) {
        final room = roomsToShow[index];
        return _buildRoomCard(room);
      },
    );
  }

  String _getEmptyMessage(bool isDiscoverTab) {
    if (isDiscoverTab) {
      if (_isSearchingById) {
        return 'No rooms found with this ID';
      } else if (_selectedCountry != null) {
        return 'No rooms found in $_selectedCountry';
      }
      return 'No voice rooms found';
    }
    return 'You haven\'t created any rooms yet';
  }

  Widget _buildStatsSquares() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8), // Reduced vertical padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Family Square
          Expanded(
            child: Container(
              height: 80, // Reduced from 100
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF40E0D0),
                    Color(0xFF48F3D1),
                  ],
                  stops: [0.2, 0.9],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF40E0D0).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.family_restroom,
                      color: Colors.white, size: 28), // Reduced icon size
                  SizedBox(height: 4), // Reduced spacing
                  Text(
                    'Family',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14, // Reduced font size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rank Square
          Expanded(
            child: GestureDetector(
              // Added GestureDetector for tap handling
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GlobalRanking(),
                  ),
                );
              },
              child: Container(
                height: 80,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFB347),
                      Color(0xFFFFE5B4),
                    ],
                    stops: [0.2, 0.9],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB347).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium,
                        color: Colors.white, size: 28),
                    SizedBox(height: 4),
                    Text(
                      'Rank',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Couple Square
          Expanded(
            child: Container(
              height: 80, // Reduced from 100
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6B95),
                    Color(0xFFFFB6C1),
                  ],
                  stops: [0.2, 0.9],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B95).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite,
                      color: Colors.white, size: 28), // Reduced icon size
                  SizedBox(height: 4), // Reduced spacing
                  Text(
                    'Couple',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14, // Reduced font size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSquareFlag(Map<String, String> country) {
    bool isSelected = _selectedCountry == country['name'];
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCountry = country['name'];
        });
      },
      child: Column(
        children: [
          Container(
            width: 40, // Fixed small square size
            height: 40, // Fixed small square size
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.white,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge, // Replace overflow with clipBehavior
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                country['flag']!,
                fit: BoxFit
                    .contain, // This will show the full flag within container
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            country['name']!
                .split(' ')[0], // Show only first word of country name
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.blue : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCountriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Countries',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_selectedCountry != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCountry = null;
                    });
                  },
                  child: const Text(
                    'Clear Filter',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // First Row of Countries
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _countries
                .take(5)
                .map((country) => _buildSmallSquareFlag(country))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Second Row of Countries
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ..._countries
                  .skip(5)
                  .take(4)
                  .map((country) => _buildSmallSquareFlag(country)),
              // More button
              GestureDetector(
                onTap: _showCountryPicker,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.more_horiz,
                          color: Colors.grey[600], size: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'More',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountryItem(Map<String, String> country) {
    final isSelected = _selectedCountry == country['name'];
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCountry = isSelected ? null : country['name'];
        });
      },
      child: SizedBox(
        width: 45, // Reduced width
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(25), // More oval shape
                color: isSelected
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      country['flag']!,
                      width: 24, // Smaller flag
                      height: 24,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              country['name']!,
              style: TextStyle(
                fontSize: 10, // Smaller text
                color: isSelected ? Colors.blue : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showCountrySearchDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filteredCountries = _countries.where((country) {
            return country['name']!
                .toLowerCase()
                .contains(_countrySearchController.text.toLowerCase());
          }).toList();

          return AlertDialog(
            title: const Text('Select Country'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _countrySearchController,
                    decoration: InputDecoration(
                      hintText: 'Search country...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredCountries.length,
                      itemBuilder: (context, index) {
                        final country = filteredCountries[index];
                        return ListTile(
                          leading: Image.network(
                            country['flag']!,
                            width: 24,
                            height: 24,
                          ),
                          title: Text(country['name']!),
                          onTap: () {
                            this.setState(() {
                              _selectedCountry = country['name'];
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: const CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: TextStyle(fontSize: 16, color: Colors.black),
        bottomSheetHeight: 500,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country.name;
        });
      },
    );
  }

  Widget _buildRoomCard(VoiceRoom room) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: InkWell(
        onTap: () async {
          final isRemoved = await _checkIfUserRemoved(room.id);
          if (isRemoved) {
            _showRemovalAlert();
          } else {
            _navigateToLivePage(room);
          }
        },
        child: Card(
          elevation: 2,
          color: Colors.white70,
          shadowColor: Colors.blue.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 110,
            child: Row(
              children: [
                // Room Image Section
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: SizedBox(
                    width: 100,
                    height: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl:
                          'http://145.223.21.62:8090/api/files/voiceRooms/${room.id}/${room.groupPhoto}',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue[300],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),

                // Room Details Section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Room Name
                        Text(
                          room.voiceRoomName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 2),

                        // Room ID and Motto
                        Row(
                          children: [
                            const SizedBox(width: 2),
                            Text(
                              'ID: ${room.voiceRoomId}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        // Team Motto
                        Text(
                          room.teamMoto,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const Spacer(),

                        // Flag, Language, and Tags Row
                        Row(
                          children: [
                            // Country Flag
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
                              child: CachedNetworkImage(
                                imageUrl: _getFlagUrl(room.voiceRoomCountry),
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
                              ),
                            ),

                            const SizedBox(width: 13),

                            // Language Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFB8860B),
                                    Color(0xFFDAA520),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                room.language,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            const SizedBox(width: 13),

                            // Tags
                            Expanded(
                              child: SizedBox(
                                height: 20,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: room.tags.split(',').map((tag) {
                                    final trimmedTag = tag.trim();
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Center(
                                        child: Text(
                                          trimmedTag,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Helper Methods

  void _showRemovalAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 4,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.block,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have been removed from this voice room and cannot rejoin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //
  // Widget _buildDiscoverHeader() {
  //   return Container(
  //     padding: EdgeInsets.all(16),
  //     child: Row(
  //       children: [
  //         Expanded(
  //           child: TextField(
  //             controller: _roomIdController,
  //             keyboardType: TextInputType.number,
  //             decoration: InputDecoration(
  //               hintText: 'Search by Room ID...',
  //               prefixIcon: Icon(Icons.search),
  //               filled: true,
  //               fillColor: Colors.grey[100],
  //               border: OutlineInputBorder(
  //                 borderRadius: BorderRadius.circular(30),
  //                 borderSide: BorderSide.none,
  //               ),
  //             ),
  //             onChanged: (value) {
  //               setState(() {
  //                 _isSearchingById = value.isNotEmpty;
  //               });
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildTags(String tags) {
    final tagsList = tags.split(',');
    return Row(
      children: tagsList
          .map((tag) => Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.lightBlue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag.trim(),
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              ))
          .toList(),
    );
  }

  void _navigateToLivePage(VoiceRoom room) {
    if (ZegoUIKitPrebuiltLiveAudioRoomController().minimize.isMinimizing) {
      return;
    }

    final isHost = room.ownerId == _userId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZegoUIKitPrebuiltLiveAudioRoomMiniPopScope(
          child: LivePage(
            roomID: room.id,
            isHost: isHost,
            username1: _username ?? '',
            userId: _userId!,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
