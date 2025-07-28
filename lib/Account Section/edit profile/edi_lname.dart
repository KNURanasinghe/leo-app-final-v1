import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/body_container.dart';
import 'widgets/primary_button.dart';
import 'widgets/back_button.dart';
import '../constants.dart';

class EditLNameScreen extends StatefulWidget {
  final String userId;
  const EditLNameScreen({super.key, required this.userId});

  @override
  State<EditLNameScreen> createState() => _EditLNameScreenState();
}

class _EditLNameScreenState extends State<EditLNameScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
  }

  Future<void> _loadCurrentName() async {
    try {
      final response = await http.get(Uri.parse(
          'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'));

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        setState(() {
          _nameController.text = userData['lastname'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading name: $e');
    }
  }

  Future<void> _updateName(BuildContext context) async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    try {
      final response = await http.patch(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lastname': newName}),
      );

      if (response.statusCode == 200) {
        await _updateLocalStorage(newName);
        _showSuccessDialog(context);
      } else {
        _showErrorDialog(context);
      }
    } catch (e) {
      print('Error updating name: $e');
      _showErrorDialog(context);
    }
  }

  Future<void> _updateLocalStorage(String newName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastname', newName);
    } catch (e) {
      print('Error updating local storage: $e');
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Name updated successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: const Text('Failed to update name. Please try again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        centerTitle: true,
        title: Text(
          'Edit Name',
          style: TextStyle(
            fontSize: 16.sp,
            color: darkModeEnabled ? kDarkTextColor : kTextColor,
          ),
        ),
      ),
      body: BodyContainer(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Name",
              style: TextStyle(
                fontSize: 16.sp,
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _nameController,
              style: TextStyle(fontSize: 16.sp),
              decoration: InputDecoration(
                border: kInputBorder,
                enabledBorder: kInputEnabledBorder,
                focusedBorder: kInputFocusedBorder,
              ),
            ),
            SizedBox(height: 20.h),
            PrimaryButton(
              onTap: () => _updateName(context),
              text: 'Save',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
