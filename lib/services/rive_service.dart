import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HttpService {
  static const String baseUrl = 'http://145.223.21.62:8090';

  // Default page size for pagination
  static const int defaultPageSize = 20;

  // Get current user ID from shared preferences
  static Future<String?> getUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // Get items purchased by the current user with pagination
  static Future<Map<String, dynamic>> getMyItems({
    int page = 1,
    int pageSize = defaultPageSize,
    String? sortField,
    bool descending = false,
  }) async {
    final userId = await getUserId();

    if (userId == null) {
      throw Exception('User ID not found');
    }

    // Build sorting parameter if provided
    String sortParam = '';
    if (sortField != null) {
      sortParam = '&sort=${descending ? '-' : ''}$sortField';
    }

    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/collections/myItems/records?filter=(userId="$userId")&page=$page&perPage=$pageSize$sortParam'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'items': data['items'] ?? [],
        'totalItems': data['totalItems'] ?? 0,
        'totalPages': data['totalPages'] ?? 0,
        'page': data['page'] ?? 1,
      };
    } else {
      throw Exception('Failed to load items: ${response.statusCode}');
    }
  }

  // Purchase a new item
  static Future<void> purchaseItem(Map<String, dynamic> item) async {
    final userId = await getUserId();

    if (userId == null) {
      throw Exception('User ID not found');
    }

    final body = {
      'name': item['name'],
      'price': item['price'],
      'duration': item['duration'],
      'image': item['image'],
      'is_used': false,
      'userId': userId
    };

    final response = await http.post(
      Uri.parse('$baseUrl/api/collections/myItems/records'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to purchase item: ${response.statusCode}');
    }
  }

  // Upload Rive file for an item
  static Future<void> uploadRiveFile(String itemId, dynamic riveFile) async {
    final userId = await getUserId();

    if (userId == null) {
      throw Exception('User ID not found');
    }

    // Create form data
    var request = http.MultipartRequest(
      'PATCH', // Changed from POST to PATCH to update the record
      Uri.parse('$baseUrl/api/collections/myItems/records/$itemId'),
    );

    // Add file
    request.files.add(
      await http.MultipartFile.fromPath('rive_file', riveFile.path),
    );

    // Send request
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('Failed to upload Rive file: ${response.statusCode}');
    }
  }

  // Mark an item as used and set all other items to unused for this user
  static Future<void> markItemAsUsed(String itemId) async {
    final userId = await getUserId();

    if (userId == null) {
      throw Exception('User ID not found');
    }

    // First, mark all items for this user as unused
    await _resetAllItemsToUnused(userId);

    // Then mark the specific item as used
    final response = await http.patch(
      Uri.parse('$baseUrl/api/collections/myItems/records/$itemId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'is_used': true}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark item as used: ${response.statusCode}');
    }
  }

  // Reset all items to unused for a user
  static Future<void> _resetAllItemsToUnused(String userId) async {
    // This would normally use a batch update API, but since the endpoint might not support it,
    // we'll get all items first and then update them one by one

    // Get all items for this user (might need to handle pagination for 1000+ items)
    List<dynamic> allItems = [];
    int page = 1;
    bool hasMoreItems = true;

    // Fetch all items using pagination
    while (hasMoreItems) {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/collections/myItems/records?filter=(userId="$userId" && is_used=true)&page=$page&perPage=100'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] ?? [];

        if (items.isEmpty) {
          hasMoreItems = false;
        } else {
          allItems.addAll(items);
          page++;
        }

        // Check if we've reached the last page
        if (data['page'] >= data['totalPages']) {
          hasMoreItems = false;
        }
      } else {
        throw Exception('Failed to load items: ${response.statusCode}');
      }
    }

    // Update all used items to unused
    for (var item in allItems) {
      await http.patch(
        Uri.parse('$baseUrl/api/collections/myItems/records/${item['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'is_used': false}),
      );
    }
  }

  // Search items with pagination
  static Future<Map<String, dynamic>> searchMyItems({
    required String query,
    int page = 1,
    int pageSize = defaultPageSize,
  }) async {
    final userId = await getUserId();

    if (userId == null) {
      throw Exception('User ID not found');
    }

    // Create a search filter combining userId and the search term
    // This assumes the backend supports searching in the name field
    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/collections/myItems/records?filter=(userId="$userId" && name~"$query")&page=$page&perPage=$pageSize'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'items': data['items'] ?? [],
        'totalItems': data['totalItems'] ?? 0,
        'totalPages': data['totalPages'] ?? 0,
        'page': data['page'] ?? 1,
      };
    } else {
      throw Exception('Failed to search items: ${response.statusCode}');
    }
  }

  // Add this to your HttpService class
  static Future<Map<String, String>> fetchUsersRiveFiles(String roomId) async {
    try {
      print('Fetching Rive files for room: $roomId');
      Map<String, String> userRiveFiles = {};

      // First, get all joined users for this room
      final roomFilter = Uri.encodeComponent('voice_room_id="$roomId"');
      final joinedResponse = await http.get(
        Uri.parse(
            '$baseUrl/api/collections/joined_users/records?filter=$roomFilter'),
        headers: {'Content-Type': 'application/json'},
      );

      if (joinedResponse.statusCode != 200) {
        print('Failed to fetch joined users: ${joinedResponse.statusCode}');
        return userRiveFiles;
      }

      final joinedData = json.decode(joinedResponse.body);
      final joinedUsers = joinedData['items'] as List;

      // Then, get the room owner
      final roomResponse = await http.get(
        Uri.parse('$baseUrl/api/collections/voiceRooms/records/$roomId'),
        headers: {'Content-Type': 'application/json'},
      );

      String? ownerId;
      if (roomResponse.statusCode == 200) {
        final roomData = json.decode(roomResponse.body);
        ownerId = roomData['ownerId'];

        // Process the owner first
        if (ownerId != null) {
          final ownerRiveFile = await getUserActiveRiveFile(ownerId);
          if (ownerRiveFile != null) {
            userRiveFiles[ownerId] = ownerRiveFile;
            print('Added owner ($ownerId) Rive file: $ownerRiveFile');
          }
        }
      }

      // Process all joined users
      List<Future> futures = [];
      for (var user in joinedUsers) {
        final userId = user['userid'];
        if (userId != ownerId) {
          // Skip owner as we already processed them
          futures.add(getUserActiveRiveFile(userId).then((riveFileUrl) {
            if (riveFileUrl != null) {
              userRiveFiles[userId] = riveFileUrl;
              print('Added user ($userId) Rive file: $riveFileUrl');
            }
          }));
        }
      }

      // Wait for all requests to complete
      await Future.wait(futures);

      print('Fetched ${userRiveFiles.length} Rive files for room $roomId');
      return userRiveFiles;
    } catch (e) {
      print('Error fetching users Rive files: $e');
      return {};
    }
  }

  // Add this to HttpService
  static Future<String?> getUserActiveRiveFile(String userId) async {
    try {
      print('Fetching Rive file for user: $userId');

      // URL encode the filter parameter
      final filter = Uri.encodeComponent('userId="$userId" && is_used=true');

      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/myItems/records?filter=$filter'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;

        if (items.isNotEmpty) {
          // Find the item with a Rive file
          for (var item in items) {
            if (item['rive_file'] != null) {
              final url =
                  '$baseUrl/api/files/myItems/${item['id']}/${item['rive_file']}';
              print('Found Rive file for user $userId: $url');
              return url;
            }
          }
          print('User $userId has items but no Rive file');
        } else {
          print('No items found for user $userId');
        }
      } else {
        print('Error response (${response.statusCode}): ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error fetching user Rive file: $e');
      return null;
    }
  }

// New method to check if a user has a specific Rive file cached
  static Future<bool> checkRiveFileExists(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print('Error checking Rive file exists: $e');
      return false;
    }
  }
}
