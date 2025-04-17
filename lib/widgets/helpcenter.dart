import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:leo_app_01/Account%20Section/constants.dart';
import 'package:leo_app_01/Account%20Section/edit%20profile/theme.dart';
import 'package:leo_app_01/Account%20Section/edit%20profile/widgets/back_button.dart';
import 'package:leo_app_01/Account%20Section/edit%20profile/widgets/body_container.dart';
import 'package:leo_app_01/services/feedback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      // {
      //   'question': 'How can I reset my password?',
      //   'answer':
      //       'To reset your password, go to the login screen and tap "Forgot Password". Enter your email address and follow the instructions sent to your email to create a new password.',
      // },
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
      // Use the same service but for help requests
      final result = await Web3FormsService.sendFeedback(
        name: _nameController.text,
        email: _emailController.text,
        message: _messageController.text,
        feedbackType: _selectedHelpTopic,
      );

      print('Help request result: $result');

      if (result['success']) {
        setState(() {
          _successMessage =
              'Your request has been sent successfully. Our team will get back to you shortly.';
          // Clear all fields after success
          _nameController.clear();
          _emailController.clear();
          _messageController.clear();
          _selectedHelpTopic = 'General Inquiries';
        });
      } else {
        setState(() {
          _errorMessage = result['message'];
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
              style: const TextStyle(
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
              style: const TextStyle(
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
              style: const TextStyle(
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
}
