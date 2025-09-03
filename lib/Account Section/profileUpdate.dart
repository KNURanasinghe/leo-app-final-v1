import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EditProfileScreen extends StatefulWidget {
  final String userId;

  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Custom Colors
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color lightBlue = const Color(0xFFE3F2FD);
  final Color darkBlue = const Color(0xFF1565C0);

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _motoController;
  late TextEditingController _bioController;

  File? _avatarFile;
  String? _currentAvatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _motoController = TextEditingController();
    _bioController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _firstNameController.text = data['firstname'] ?? '';
          _lastNameController.text = data['lastname'] ?? '';
          _motoController.text = data['moto'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _currentAvatarUrl = data['avatar'];
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load profile data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _avatarFile = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'),
      );

      request.fields['firstname'] = _firstNameController.text;
      request.fields['lastname'] = _lastNameController.text;
      request.fields['moto'] = _motoController.text;
      request.fields['bio'] = _bioController.text;

      if (_avatarFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'avatar',
          _avatarFile!.path,
        ));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('firstName', _firstNameController.text);

        if (mounted) {
          _showSuccessSnackBar('Profile updated successfully');
          Navigator.pop(context);
        }
      } else {
        _showErrorSnackBar('Failed to update profile');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBlue,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : SingleChildScrollView(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildHeaderCurve(),
                      const SizedBox(
                          height: 60), // Add space for avatar overflow
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              const SizedBox(height: 30),
                              _buildInputFields(),
                              const SizedBox(height: 40),
                              _buildUpdateButton(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 40, // Adjust this value to position the avatar
                    left: 0,
                    right: 0,
                    child: _buildAvatarSection(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCurve() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              image: _avatarFile != null
                  ? DecorationImage(
                      image: FileImage(_avatarFile!),
                      fit: BoxFit.cover,
                    )
                  : _currentAvatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_currentAvatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
            ),
            child: _avatarFile == null && _currentAvatarUrl == null
                ? Icon(Icons.person, size: 60, color: primaryBlue)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: (MediaQuery.of(context).size.width - 120) / 2 - 15,
            child: Material(
              color: darkBlue,
              borderRadius: BorderRadius.circular(50),
              child: InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _firstNameController,
          label: 'First Name',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your first name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _lastNameController,
          label: 'Last Name',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your last name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _motoController,
          label: 'Motto',
          icon: Icons.format_quote,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _bioController,
          label: 'Bio',
          icon: Icons.description_outlined,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(color: darkBlue),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: primaryBlue,
            overflow: TextOverflow.ellipsis,
          ),
          prefixIcon: Icon(icon, color: primaryBlue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: primaryBlue, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide:
                BorderSide(color: primaryBlue.withOpacity(0.3), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Update Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _motoController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
