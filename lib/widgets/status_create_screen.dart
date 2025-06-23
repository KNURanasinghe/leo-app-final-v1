import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:leo_app_01/widgets/status_screen.dart';
import 'dart:convert';
import 'package:path/path.dart' as path_helper;
import 'package:http_parser/http_parser.dart';

import '../constants/app_constants.dart';
import '../services/socket_service.dart';

class StatusCreateScreen extends StatefulWidget {
  final String currentUserId;
  final File? sharedMedia;
  final String? sharedMediaType;
  final String? sharedCaption;
  const StatusCreateScreen({
    super.key,
    required this.currentUserId,
    this.sharedMedia,
    this.sharedMediaType,
    this.sharedCaption,
  });

  @override
  _StatusCreateScreenState createState() => _StatusCreateScreenState();
}

class _StatusCreateScreenState extends State<StatusCreateScreen> {
  final TextEditingController _textController = TextEditingController();
  final SocketService _socketService = SocketService();
  File? _mediaFile;
  String? _mediaType;
  bool _isUploading = false;

  // Blue theme colors
  final Color kPrimaryColor = const Color(0xFF3DB6EB);
  final Color primaryBlue = const Color(0xFF1E88E5);
  final Color darkBlue = const Color(0xFF0D47A1);
  final Color lightBlue = const Color(0xFFBBDEFB);
  final Color accentBlue = const Color(0xFF42A5F5);
// Add this to your initState() method
  @override
  void initState() {
    super.initState();

    // Initialize with shared values if provided
    if (widget.sharedMedia != null) {
      _mediaFile = widget.sharedMedia;
      _mediaType = widget.sharedMediaType;
      _textController.text = widget.sharedCaption ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kPrimaryColor,
        title: const Text(
          'Create Status',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ElevatedButton(
              onPressed: _isUploading ? null : _postStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: primaryBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(
                'POST',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isUploading ? Colors.grey : kPrimaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryBlue),
                  const SizedBox(height: 16),
                  const Text(
                    'Uploading status...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Media preview
                  if (_mediaFile != null)
                    Container(
                      height: 300,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: lightBlue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          _mediaType == 'image'
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    _mediaFile!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                              : _mediaType == 'video'
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        color: darkBlue.withOpacity(0.1),
                                        child: Center(
                                          child: Icon(
                                            Icons.play_circle_fill,
                                            size: 64,
                                            color: primaryBlue,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _mediaFile = null;
                                  _mediaType = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: darkBlue,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Text input
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: _mediaFile == null
                            ? 'What\'s on your mind?'
                            : 'Add a caption...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                      maxLines: 5,
                      minLines: 3,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Media options title
                  Text(
                    'Add to your status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkBlue,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Media buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMediaButton(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        color: kPrimaryColor,
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                      _buildMediaButton(
                        icon: Icons.photo,
                        label: 'Gallery',
                        color: kPrimaryColor,
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                      _buildMediaButton(
                        icon: Icons.videocam,
                        label: 'Video',
                        color: kPrimaryColor,
                        onTap: _pickVideo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: darkBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _mediaFile = File(pickedFile.path);
        _mediaType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _mediaFile = File(pickedFile.path);
        _mediaType = 'video';
      });
    }
  }

  Future<void> _postStatus() async {
    // Validate
    if (_textController.text.trim().isEmpty && _mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add text or media for your status'),
          backgroundColor: darkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String? fileUrl;
      String? fileName;

      // Upload media if present
      if (_mediaFile != null) {
        final uploadResult = await _uploadFile(
          _mediaFile!,
          _mediaType == 'image'
              ? AppConstants.messageTypeImage
              : AppConstants.messageTypeVideo,
        );

        fileUrl = uploadResult['fileUrl'];
        fileName = uploadResult['fileName'];
      }

      // Post status
      _socketService.postStatus(
        userId: widget.currentUserId,
        statusType: _mediaFile != null
            ? (_mediaType == 'image'
                ? AppConstants.messageTypeImage
                : AppConstants.messageTypeVideo)
            : AppConstants.messageTypeText,
        content: _textController.text.trim(),
        fileUrl: fileUrl,
        fileName: fileName,
      );

      // Set up callback for when status is posted
      _socketService.onStatusPosted = (statusData) {
        // Navigator.pushReplacement(
        //     context,
        //     MaterialPageRoute(
        //         builder: (context) => StatusScreen(
        //             currentUserId: widget
        //                 .currentUserId))); // Return true to indicate success

        Navigator.pop(context, true);

        // Access the parent Navigator to pop back to ChatScreen1
        // and tell ChatScreen1 to switch to the Status tab (index 1)
        if (Navigator.canPop(context)) {
          Navigator.pop(context, {'switchToTab': 1});
        }
      };
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting status: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _uploadFile(File file, String mediaType) async {
    // Create multipart request
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.serverUrl}/upload/status'),
    );

    // Determine MIME type
    String? extension = file.path.split('.').last.toLowerCase();
    String mimeType;

    if (mediaType == AppConstants.messageTypeImage) {
      mimeType = 'image/$extension';
    } else if (mediaType == AppConstants.messageTypeVideo) {
      mimeType = 'video/$extension';
    } else {
      mimeType = 'application/$extension';
    }

    // Add file to request
    request.files.add(
      http.MultipartFile(
        'file',
        file.readAsBytes().asStream(),
        file.lengthSync(),
        filename: path_helper.basename(file.path),
        contentType: MediaType.parse(mimeType),
      ),
    );

    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload file: ${response.reasonPhrase}');
    }
  }
}
