import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

class DismissAdminScreen extends StatefulWidget {
  final String voiceRoomId;

  const DismissAdminScreen({super.key, required this.voiceRoomId});

  @override
  _DismissAdminScreenState createState() => _DismissAdminScreenState();
}

class _DismissAdminScreenState extends State<DismissAdminScreen> {
  final String baseUrl = 'http://145.223.21.62:8090';
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> admins = [];
  List<Map<String, dynamic>> filteredAdmins = [];
  Set<String> selectedAdminIds = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    try {
      setState(() => isLoading = true);

      // Correct PocketBase filter syntax
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/collections/joined_users/records?filter=(voice_room_id="${widget.voiceRoomId}")'),
      );

      if (response.statusCode == 200) {
        final joinedData = json.decode(response.body)['items'] as List;
        // Filter admins from the response
        final joinedAdmins =
            joinedData.where((user) => user['admin_or_not'] == true).toList();

        final userFutures = joinedAdmins.map((admin) async {
          try {
            final userResponse = await http.get(
              Uri.parse(
                  '$baseUrl/api/collections/users/records/${admin['userid']}'),
            );

            if (userResponse.statusCode == 200) {
              final userData = json.decode(userResponse.body);
              return {
                'userid': admin['userid'],
                'firstname': userData['firstname'],
                'avatar': userData['avatar'],
                'collectionId': userData['collectionId'],
                'joinedId': admin['id'],
              };
            }
          } catch (e) {
            print('Error fetching user ${admin['userid']}: $e');
          }
          return null;
        }).toList();

        final adminProfiles = (await Future.wait(userFutures))
            .where((profile) => profile != null)
            .cast<Map<String, dynamic>>()
            .toList();

        setState(() {
          admins = adminProfiles;
          filteredAdmins = List.from(adminProfiles);
          isLoading = false;
        });
      } else {
        print('Failed to fetch admins: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching admins: $e');
      setState(() => isLoading = false);
    }
  }

  void _filterAdmins(String query) {
    setState(() {
      filteredAdmins = admins.where((admin) {
        final name = (admin['firstname'] ?? '').toLowerCase();
        final userId = (admin['userid'] ?? '').toLowerCase();
        return name.contains(query.toLowerCase()) ||
            userId.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _dismissAdmins() async {
    if (selectedAdminIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one admin')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Dismissing admins...'),
                ],
              ),
            ),
          ),
        ),
      );

      for (String adminId in selectedAdminIds) {
        final adminRecord =
            admins.firstWhere((admin) => admin['userid'] == adminId);
        await http.patch(
          Uri.parse(
              '$baseUrl/api/collections/joined_users/records/${adminRecord['joinedId']}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'admin_or_not': false}),
        );
      }

      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Return to previous screen

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admins dismissed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to dismiss admins'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAdminTile(Map<String, dynamic> admin) {
    final avatarUrl = admin['avatar'] != null
        ? '$baseUrl/api/files/${admin['collectionId']}/${admin['userid']}/${admin['avatar']}'
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CheckboxListTile(
        value: selectedAdminIds.contains(admin['userid']),
        onChanged: (value) {
          setState(() {
            if (value == true) {
              selectedAdminIds.add(admin['userid']);
            } else {
              selectedAdminIds.remove(admin['userid']);
            }
          });
        },
        secondary: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: CachedNetworkImage(
            imageUrl: avatarUrl ?? '',
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: Icon(Icons.person, color: Colors.grey[400]),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: Icon(Icons.person, color: Colors.grey[400]),
            ),
          ),
        ),
        title: Text(
          admin['firstname'] ?? 'Unknown Admin',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          admin['userid'] ?? '',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Dismiss Admins',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search admins',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _filterAdmins,
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredAdmins.isEmpty
                    ? Center(
                        child: Text(
                          'No admins found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredAdmins.length,
                        itemBuilder: (context, index) {
                          return _buildAdminTile(filteredAdmins[index]);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _dismissAdmins,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Dismiss ${selectedAdminIds.length} Admins',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
