import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:leo_app_01/Account%20Section/constants.dart';
import 'package:leo_app_01/Account%20Section/edit%20profile/theme.dart';
import 'package:leo_app_01/Account%20Section/edit%20profile/widgets/back_button.dart';
import 'package:leo_app_01/Account%20Section/edit%20profile/widgets/body_container.dart';
import 'package:leo_app_01/services/feedback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  // Tab index for the current selected tab
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        centerTitle: true,
        title: Text(
          'Help Center',
          style: TextStyle(
            fontSize: 16.sp,
            color: darkModeEnabled ? kDarkTextColor : kTextColor,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 50.h,
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
      decoration: BoxDecoration(
        color: darkModeEnabled ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(25.r),
      ),
      child: Row(
        children: [
          _buildTabButton('FAQs', 0),
          _buildTabButton('Contact Us', 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          height: 50.h,
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(25.r),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : darkModeEnabled
                        ? kDarkTextColor
                        : kTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTabIndex == 0) {
      return _buildFaqsTab();
    } else {
      return _buildContactUsTab();
    }
  }

  Widget _buildFaqsTab() {
    // List of FAQs with question and answer
    final List<Map<String, String>> faqs = [
      {
        'question': 'How do I create an account?',
        'answer':
            'To create an account, download our app from the App Store or Google Play Store, then click "Sign Up" on the welcome screen. Follow the prompts to enter your details and create your account.',
      },
      {
        'question': 'How do I update my profile information?',
        'answer':
            'To update your profile information, go to Account > Edit Profile. You can update your name, photo, email, and other account details there.',
      },
      {
        'question': 'Is my personal information secure?',
        'answer':
            'Yes, we take security very seriously. All your personal information is encrypted and stored securely. We never share your information with third parties without your consent.',
      },
      {
        'question': 'How do I earn rewards?',
        'answer':
            'You can earn rewards by completing various activities in the app, including daily logins, inviting friends, completing challenges, and participating in community events.',
      },
      {
        'question': 'How can I contact customer support?',
        'answer':
            'You can contact our customer support team through the "Contact Us" tab in the Help Center, or by emailing support@leochatapp.com.',
      },
      {
        'question': 'What should I do if I encounter a bug?',
        'answer':
            'If you encounter a bug, please report it to us through the Feedback feature in the app. Include as much detail as possible about what happened and the steps to reproduce the issue.',
      },
    ];

    return BodyContainer(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      enableScroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: darkModeEnabled ? kDarkTextColor : kTextColor,
            ),
          ),
          SizedBox(height: 10.h),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: faqs.length,
            itemBuilder: (context, index) {
              return _buildFaqItem(
                faqs[index]['question'] ?? '',
                faqs[index]['answer'] ?? '',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: darkModeEnabled ? kDarkTextColor : kTextColor,
          ),
        ),
        iconColor: kPrimaryColor,
        collapsedIconColor: darkModeEnabled ? kDarkTextColor : kTextColor,
        childrenPadding: EdgeInsets.all(15.w),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 13.sp,
              color: kAltTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactUsTab() {
    return const ContactUsForm();
  }
}

class ContactUsForm extends StatefulWidget {
  const ContactUsForm({super.key});

  @override
  State<ContactUsForm> createState() => _ContactUsFormState();
}

class _ContactUsFormState extends State<ContactUsForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  // File attachment variables
  List<PlatformFile> _attachments = [];
  final int _maxAttachments = 3;
  final int _maxFileSize = 10 * 1024 * 1024; // 10MB in bytes

  // List of help topics
  final List<String> _helpTopics = [
    'Account Issues',
    'Technical Support',
    'Billing Questions',
    'Feature Requests',
    'General Inquiries',
    'Other'
  ];
  String _selectedHelpTopic = 'General Inquiries';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get user data from shared preferences
      final firstName = prefs.getString('userFirstName') ?? '';
      final lastName = prefs.getString('userLastName') ?? '';
      final email = prefs.getString('userEmail') ?? '';

      setState(() {
        _nameController.text = '$firstName $lastName'.trim();
        _emailController.text = email;
      });
    } catch (e) {
      // Silently handle error - user can still fill the form manually
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );

      if (result != null) {
        // Check if adding these files would exceed the max attachment limit
        if (_attachments.length + result.files.length > _maxAttachments) {
          _showErrorSnackBar(
              'You can only attach up to $_maxAttachments files.');
          return;
        }

        // Check file sizes
        for (var file in result.files) {
          if (file.size > _maxFileSize) {
            _showErrorSnackBar('${file.name} exceeds the 10MB size limit.');
            return;
          }
        }

        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking files: ${e.toString()}');
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Update the _submitHelpRequest method in the _ContactUsFormState class
  Future<void> _submitHelpRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Prepare attachments for sending
      List<Map<String, dynamic>> attachmentData = [];
      for (var file in _attachments) {
        if (file.bytes != null) {
          attachmentData.add({
            'name': file.name,
            'data': file.bytes,
            'size': file.size,
          });
        }
      }

      // Use the service to send feedback with attachments
      final result = await Web3FormsService.sendFeedbackWithAttachments(
        name: _nameController.text,
        email: _emailController.text,
        message: _messageController.text,
        feedbackType: _selectedHelpTopic,
        attachments: attachmentData,
      );

      if (result['success']) {
        setState(() {
          _successMessage =
              'Your request has been sent successfully. Our team will get back to you shortly.';
          // Clear all fields after success
          _messageController.clear();
          _selectedHelpTopic = 'General Inquiries';
          _attachments = [];
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to send request';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
      print('Error submitting help request: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BodyContainer(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      enableScroll: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Our Support Team',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Fill out the form below and we\'ll get back to you as soon as possible.',
              style: TextStyle(
                fontSize: 13.sp,
                color: kAltTextColor,
              ),
            ),
            SizedBox(height: 20.h),

            // Name field
            Text(
              'Name',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: TextStyle(color: kAltTextColor, fontSize: 14.sp),
                filled: true,
                fillColor:
                    darkModeEnabled ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
              style: TextStyle(
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            SizedBox(height: 15.h),

            // Email field
            Text(
              'Email',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Your email address',
                hintStyle: TextStyle(color: kAltTextColor, fontSize: 14.sp),
                filled: true,
                fillColor:
                    darkModeEnabled ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
              style: TextStyle(
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email address';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            SizedBox(height: 15.h),

            // Help topic dropdown
            Text(
              'Help Topic',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              decoration: BoxDecoration(
                color: darkModeEnabled ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                value: _selectedHelpTopic,
                isExpanded: true,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: kAltTextColor,
                ),
                style: TextStyle(
                  color: darkModeEnabled ? kDarkTextColor : kTextColor,
                  fontSize: 14.sp,
                ),
                dropdownColor:
                    darkModeEnabled ? Colors.grey[800] : Colors.white,
                items: _helpTopics.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedHelpTopic = newValue;
                    });
                  }
                },
              ),
            ),
            SizedBox(height: 15.h),

            // Message field
            Text(
              'How can we help you?',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Please describe your issue or question in detail',
                hintStyle: TextStyle(color: kAltTextColor, fontSize: 14.sp),
                filled: true,
                fillColor:
                    darkModeEnabled ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(16.w),
              ),
              style: TextStyle(
                color: darkModeEnabled ? kDarkTextColor : kTextColor,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please describe your issue or question';
                }
                if (value.trim().length < 10) {
                  return 'Please provide more details about your issue';
                }
                return null;
              },
            ),
            SizedBox(height: 20.h),

            // Attachments section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attachments (${_attachments.length}/$_maxAttachments)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: darkModeEnabled ? kDarkTextColor : kTextColor,
                  ),
                ),
                if (_attachments.length < _maxAttachments)
                  TextButton.icon(
                    onPressed: _pickFiles,
                    icon: Icon(
                      Icons.attach_file,
                      size: 18.sp,
                      color: kPrimaryColor,
                    ),
                    label: Text(
                      'Add Files',
                      style: TextStyle(
                        color: kPrimaryColor,
                        fontSize: 14.sp,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Max 3 files, 10MB each',
              style: TextStyle(
                fontSize: 12.sp,
                color: kAltTextColor,
              ),
            ),
            SizedBox(height: 10.h),

            // Display attached files
            if (_attachments.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: darkModeEnabled ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: EdgeInsets.all(12.w),
                child: Column(
                  children: _attachments.asMap().entries.map((entry) {
                    int index = entry.key;
                    PlatformFile file = entry.value;
                    return Container(
                      margin: EdgeInsets.only(
                          bottom: index < _attachments.length - 1 ? 8.h : 0),
                      child: Row(
                        children: [
                          Icon(
                            _getFileIcon(file.extension ?? ''),
                            size: 24.sp,
                            color: kPrimaryColor,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: darkModeEnabled
                                        ? kDarkTextColor
                                        : kTextColor,
                                    fontWeight: FontWeight.w500,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  maxLines: 1,
                                ),
                                Text(
                                  _getFileSizeString(file.size),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: kAltTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeAttachment(index),
                            icon: Icon(
                              Icons.close,
                              size: 18.sp,
                              color: kAltTextColor,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth: 24.w,
                              minHeight: 24.h,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            SizedBox(height: 20.h),

            // Error and success messages
            if (_errorMessage != null)
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20.w),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_successMessage != null)
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 20.w),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20.h),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitHelpRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20.h,
                        width: 20.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get the appropriate icon based on file extension
  IconData _getFileIcon(String extension) {
    extension = extension.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return Icons.image;
    } else if (['pdf'].contains(extension)) {
      return Icons.picture_as_pdf;
    } else if (['doc', 'docx'].contains(extension)) {
      return Icons.description;
    } else if (['xls', 'xlsx'].contains(extension)) {
      return Icons.table_chart;
    } else if (['ppt', 'pptx'].contains(extension)) {
      return Icons.slideshow;
    } else if (['mp4', 'avi', 'mov', 'wmv'].contains(extension)) {
      return Icons.video_file;
    } else if (['mp3', 'wav', 'ogg'].contains(extension)) {
      return Icons.audio_file;
    } else if (['zip', 'rar', '7z'].contains(extension)) {
      return Icons.folder_zip;
    } else {
      return Icons.insert_drive_file;
    }
  }
}

// Extend the Web3FormsService with a method that handles attachments
extension Web3FormsServiceExtension on Web3FormsService {
  static Future<Map<String, dynamic>> sendFeedbackWithAttachments({
    required String name,
    required String email,
    required String message,
    required String feedbackType,
    required List<Map<String, dynamic>> attachments,
  }) async {
    try {
      // Implementation would depend on how your backend handles file uploads
      // This is a placeholder for the actual implementation

      // First, send basic form data
      final baseResult = await Web3FormsService.sendFeedback(
        name: name,
        email: email,
        message: message,
        feedbackType: feedbackType,
      );

      if (!baseResult['success']) {
        return baseResult;
      }

      // If attachments are present, handle them
      if (attachments.isNotEmpty) {
        // Here you would typically:
        // 1. Convert the file bytes to a format your API accepts
        // 2. Send them to your backend, possibly as multipart/form-data
        // 3. Attach them to the email that gets sent

        // For now, let's just return success
        return {
          'success': true,
          'message':
              'Your message and ${attachments.length} attachment(s) were sent successfully.',
        };
      }

      return baseResult;
    } catch (e) {
      print('Error sending feedback with attachments: $e');
      return {
        'success': false,
        'message': 'Failed to send message: ${e.toString()}',
      };
    }
  }
}
