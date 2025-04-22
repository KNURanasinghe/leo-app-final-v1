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
      final roomFilter = Uri.encodeComponent('voice_room_id="$roomId"');
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/collections/joined_users/records?filter=$roomFilter'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch users');
      }

      final data = json.decode(response.body);
      final joinedUsers = data['items'] as List;

      Map<String, String> userRiveFiles = {};

      for (var user in joinedUsers) {
        final userId = user['userid'];
        final riveFileUrl = await getUserActiveRiveFile(userId);
        if (riveFileUrl != null) {
          userRiveFiles[userId] = riveFileUrl;
        }
      }

      print('Fetched users rive files: $userRiveFiles');
      return userRiveFiles;
    } catch (e) {
      print('Error fetching users rive files: $e');
      return {};
    }
  }

  // Add this to HttpService
  static Future<String?> getUserActiveRiveFile(String userId) async {
    try {
      // URL encode the filter parameter
      final filter = Uri.encodeComponent('userId="$userId" && is_used=true');

      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/myItems/records?filter=$filter'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;

        if (items.isNotEmpty && items[0]['rive_file'] != null) {
          final item = items[0];
          return '$baseUrl/api/files/myItems/${item['id']}/${item['rive_file']}';
        }
      }
      return null;
    } catch (e) {
      print('Error fetching user rive file: $e');
      return null;
    }
  }
}
