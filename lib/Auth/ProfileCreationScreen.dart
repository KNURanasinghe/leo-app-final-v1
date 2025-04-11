import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../HomeScreen.dart';
import 'package:zego_zimkit/zego_zimkit.dart';

class ProfileCreationScreen extends StatefulWidget {
  final String userId;

  const ProfileCreationScreen({super.key, required this.userId});

  @override
  _ProfileCreationScreenState createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  String firstname = "";
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  File? _profileImage;
  String? _oneSignalPlayerId; // To store the OneSignal player ID
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    // Initialize and get OneSignal Player ID when screen loads
    _initOneSignal();
  }

  Future<void> _initOneSignal() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize OneSignal with your app ID
      OneSignal.initialize("285b1b8b-9ba7-4696-a660-62f0dc1ca908");

      // Request permission for notifications
      OneSignal.Notifications.requestPermission(true);

      // Add subscription observer to get the player ID
      OneSignal.User.pushSubscription.addObserver((state) {
        print("Push subscription state changed:");
        print("Opted in: ${OneSignal.User.pushSubscription.optedIn}");
        print("ID: ${OneSignal.User.pushSubscription.id}");
        print("Token: ${OneSignal.User.pushSubscription.token}");

        setState(() {
          _oneSignalPlayerId = OneSignal.User.pushSubscription.id;
          _isLoading = false;
        });
      });

      // In case the observer doesn't fire immediately, try to get the ID directly
      final id = OneSignal.User.pushSubscription.id;
      if (id != null) {
        setState(() {
          _oneSignalPlayerId = id;
          _isLoading = false;
        });
      }
      setState(() {
        _isLoading = false;
      });
      print("OneSignal Player ID: $_oneSignalPlayerId");
    } catch (e) {
      print("Error initializing OneSignal: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> saveProfile() async {
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    // Validate input fields
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // If we don't have a player ID yet, try to get it again
    if (_oneSignalPlayerId == null) {
      try {
        final deviceState = OneSignal.User.pushSubscription.id;
        _oneSignalPlayerId = deviceState;
      } catch (e) {
        print("Error getting OneSignal Player ID: $e");
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final url = Uri.parse(
        'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}');

    var request = http.MultipartRequest('PATCH', url);
    request.fields['firstname'] = _firstNameController.text;
    request.fields['lastname'] = _lastNameController.text;

    // Add the OneSignal player ID to the request
    if (_oneSignalPlayerId != null) {
      request.fields['player_id'] = _oneSignalPlayerId!;
    } else {
      print("Warning: OneSignal Player ID is null");
    }

    if (_profileImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        _profileImage!.path,
      ));
    }

    try {
      var response = await request.send();

      if (response.statusCode == 200) {
        await prefs.setString('firstName', _firstNameController.text);
        firstname = prefs.getString('firstName') ?? 'User';

        // Also save the player ID to SharedPreferences for future use
        if (_oneSignalPlayerId != null) {
          await prefs.setString('oneSignalPlayerId', _oneSignalPlayerId!);
        }

        if (firstname != "User") {
          ZIMKit().connectUser(id: widget.userId, name: firstname);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                userId: widget.userId,
                username: firstname,
              ),
            ),
          );
        }
      } else {
        // Get response body for better error handling
        final responseBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to save profile. Error ${response.statusCode}: $responseBody'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Profile',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.deepPurple[50],
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? Icon(
                                Icons.add_a_photo,
                                size: 50,
                                color: Colors.blue[700],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Upload Profile Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        labelStyle: TextStyle(color: Colors.blue[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.person, color: Colors.blue[700]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        labelStyle: TextStyle(color: Colors.blue[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon:
                            Icon(Icons.person_outline, color: Colors.blue[700]),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
