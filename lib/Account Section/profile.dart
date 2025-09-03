import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileApp extends StatelessWidget {
  const ProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProfileUI(),
    );
  }
}

class ProfileUI extends StatefulWidget {
  const ProfileUI({super.key});

  @override
  State<ProfileUI> createState() => _ProfileUIState();
}

class _ProfileUIState extends State<ProfileUI> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      // Retrieve user ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("userId") ?? "default_id";

      // Make API request to fetch user data
      final response = await http.get(
        Uri.parse(
            "http://145.223.21.62:8090//api/collections/users/records/$userId"),
      );

      if (response.statusCode == 200) {
        setState(() {
          userData = json.decode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load user data");
      }
    } catch (e) {
      // Handle errors gracefully
      setState(() {
        userData = null;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.arrow_back),
        title: const Text("Profile"),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header Section
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: userData != null &&
                                  userData!["avatar"] != null
                              ? NetworkImage(
                                  "http://your-pocketbase-url/api/files/${userData!['collectionId']}/${userData!['id']}/${userData!['avatar']}")
                              : const AssetImage("assets/images/profile.jpg")
                                  as ImageProvider,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          userData?["firstname"] ?? "Unknown",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "ID: ${userData?['id'] ?? 'Unknown'}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          children: (userData?["badges"] as List<dynamic>?)
                                  ?.map((badge) => Chip(label: Text(badge)))
                                  .toList() ??
                              [const Chip(label: Text("Entrepreneur"))],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            userData?["bio"] ?? "Entrepreneur",
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Followers Section
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem("Followers", "11"),
                        _buildStatItem("Fans", "2"),
                        _buildStatItem("Visitors", "22"),
                      ],
                    ),
                  ),

                  // Gifts Section
                  const SectionTitle(title: "Gifts"),
                  HorizontalList(
                    items: userData?["gift"] ?? [],
                  ),

                  // Badges Section
                  const SectionTitle(title: "Badges"),
                  HorizontalList(
                    items: userData?["badges"] ?? [],
                  ),

                  // Buttons Section
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // Share functionality
                          },
                          child: const Text("Share"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // Edit functionality
                          },
                          child: const Text("Edit"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(label),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class HorizontalList extends StatelessWidget {
  final List<dynamic> items;
  const HorizontalList({required this.items, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              children: [
                Image.network(
                  "http://your-pocketbase-url/api/files/your-collection-id/your-record-id/$item",
                  width: 60,
                  height: 60,
                ),
                const SizedBox(height: 5),
                const Text("x255"),
              ],
            ),
          );
        },
      ),
    );
  }
}
