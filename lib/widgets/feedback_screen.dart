import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:leo_app_01/Account%20Section/constants.dart';
import 'package:leo_app_01/Account%20Section/edit%20profile/widgets/back_button.dart';
import 'package:leo_app_01/services/feedback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Account Section/edit profile/widgets/body_container.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  // List of feedback types
  final List<String> _feedbackTypes = [
    'Bug Report',
    'Feature Request',
    'General Feedback',
    'Account Issue',
    'Other'
  ];
  String _selectedFeedbackType = 'General Feedback';

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

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Use the Web3Forms service to send the feedback
      final result = await Web3FormsService.sendFeedback(
        name: _nameController.text,
        email: _emailController.text,
        message: _messageController.text,
        feedbackType: _selectedFeedbackType,
      );

      print('Feedback result: $result');

      if (result['success']) {
        setState(() {
          _successMessage = result['message'];
          _messageController.clear(); // Only clear the message, keep name/email
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
      print('Error submitting feedback: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        centerTitle: true,
        title: Text(
          'Feedback',
          style: TextStyle(
            fontSize: 16.sp,
            color: darkModeEnabled ? kDarkTextColor : kTextColor,
          ),
        ),
      ),
      body: BodyContainer(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        enableScroll: true,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We value your feedback',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: darkModeEnabled ? kDarkTextColor : kTextColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Let us know how we can improve your experience',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: kAltTextColor,
                ),
              ),
              SizedBox(height: 25.h),

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
              SizedBox(height: 20.h),

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
              SizedBox(height: 20.h),

              // Feedback type dropdown
              Text(
                'Feedback Type',
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
                  value: _selectedFeedbackType,
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
                  items: _feedbackTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedFeedbackType = newValue;
                      });
                    }
                  },
                ),
              ),
              SizedBox(height: 20.h),

              // Message field
              Text(
                'Message',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: darkModeEnabled ? kDarkTextColor : kTextColor,
                ),
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _messageController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Please describe your feedback in detail',
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
                    return 'Please enter your feedback message';
                  }
                  if (value.trim().length < 10) {
                    return 'Please provide more details in your message';
                  }
                  return null;
                },
              ),
              SizedBox(height: 25.h),

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
                  onPressed: _isSubmitting ? null : _submitFeedback,
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
                          'Submit Feedback',
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
      ),
    );
  }
}
