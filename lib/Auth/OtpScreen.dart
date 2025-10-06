import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'ProfileCreationScreen.dart';
import 'package:leo_app_01/services/firebase_service.dart'; // Import your FirebaseService

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String otp;

  const OtpScreen({super.key, required this.phoneNumber, required this.otp});

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  // Add FirebaseService instance
  final FirebaseService _firebaseService = FirebaseService();

  // Resend OTP related variables
  bool _canResend = true;
  int _remainingSeconds = 0;
  Timer? _resendTimer;
  String _currentOtp = '';
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.otp; // Initialize with the original OTP

    for (int i = 0; i < 5; i++) {
      _focusNodes[i].addListener(() {
        if (_controllers[i].text.length == 1) {
          FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  // Generate a new OTP
  String generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Start the resend cooldown timer
  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _remainingSeconds = 60; // 1 minute cooldown
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  // Resend OTP function
  Future<void> _resendOTP() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      // Generate new OTP
      String newOtp = generateOTP();
      print('Generated new OTP: $newOtp'); // For debugging

      // Clean the phone number to match the format needed for the API
      String cleanedNumber =
          widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      // Send OTP via Notify.lk API (same as in PhoneNumberScreen)
      const String userId = '29316';
      const String apiKey = 'RH9L1weIpJJODyQkFfSe';
      const String senderId = 'NotifyDEMO';
      const String url = 'https://app.notify.lk/api/v1/send';

      String message =
          'Your verification code is $newOtp. Please use this to verify your account.';

      final Map<String, String> queryParams = {
        'user_id': userId,
        'api_key': apiKey,
        'sender_id': senderId,
        'to': cleanedNumber,
        'message': message,
      };

      // Send OTP via Notify.lk API
      final response = await http.post(
        Uri.parse(url).replace(queryParameters: queryParams),
      );

      print("Resend API Response: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Update the current OTP
        setState(() {
          _currentOtp = newOtp;
        });

        // Clear all OTP input fields
        for (var controller in _controllers) {
          controller.clear();
        }

        // Focus on the first field
        FocusScope.of(context).requestFocus(_focusNodes[0]);

        // Start the cooldown timer
        _startResendTimer();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend OTP. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error resending OTP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  Future<void> updatePhoneNumber() async {
    try {
      // First, check if the phone number already exists
      final checkUrl =
          Uri.parse('http://145.223.21.62:8090/api/collections/users/records');
      final phoneNumberInt = int.parse(widget.phoneNumber.replaceAll('+', ''));

      final checkResponse = await http.get(
        Uri.parse(
            '${checkUrl.toString()}?filter=(phonenumber=$phoneNumberInt)'),
        headers: {'Content-Type': 'application/json'},
      );

      String userId;
      bool isExistingUser = false;

      if (checkResponse.statusCode == 200) {
        final checkData = json.decode(checkResponse.body);

        // If phone number exists
        if (checkData['items'] != null && checkData['items'].length > 0) {
          final existingUser = checkData['items'][0];
          userId = existingUser['id'];
          isExistingUser = true;
        } else {
          // If phone number doesn't exist, create new user
          final createResponse = await http.post(
            checkUrl,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'phonenumber': phoneNumberInt,
            }),
          );

          if (createResponse.statusCode == 200) {
            final responseData = json.decode(createResponse.body);
            userId = responseData['id'];
          } else {
            throw Exception('Failed to create user');
          }
        }

        // Save user ID to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);

        // **IMPORTANT: Update FCM token after successful verification**
        await _updateFCMToken(userId);

        // Navigate to appropriate screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => ProfileCreationScreen(userId: userId)),
        );
      } else {
        throw Exception('Failed to check user existence');
      }
    } catch (e) {
      print('Error updating phone number: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update phone number. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to update FCM token
  Future<void> _updateFCMToken(String userId) async {
    try {
      // Set the user ID in FirebaseService which will automatically update the token
      _firebaseService.setUserId(userId);

      print('FCM token update initiated for user: $userId');
    } catch (e) {
      print('Error updating FCM token: $e');
      // Don't show error to user as this is not critical for the flow
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue[700]),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Hero(
                            tag: 'logo',
                            child: Image.asset(
                              'assets/otp.png',
                              width: constraints.maxWidth * 0.8,
                              height: constraints.maxHeight * 0.3,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Enter verification code',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'ve sent a code to ${widget.phoneNumber}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            6,
                            (index) => SizedBox(
                              width: 50,
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                onKey: (RawKeyEvent event) {
                                  if (event is RawKeyDownEvent) {
                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.backspace) {
                                      if (_controllers[index].text.isEmpty &&
                                          index > 0) {
                                        // Clear the previous field and move focus back
                                        _controllers[index - 1].clear();
                                        FocusScope.of(context).requestFocus(
                                            _focusNodes[index - 1]);
                                      }
                                    }
                                  }
                                },
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(1),
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (value) {
                                    if (value.length == 1 && index < 5) {
                                      FocusScope.of(context)
                                          .requestFocus(_focusNodes[index + 1]);
                                    }
                                    // If field is cleared and not the first field, move focus back
                                    if (value.isEmpty && index > 0) {
                                      FocusScope.of(context)
                                          .requestFocus(_focusNodes[index - 1]);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: _isResending
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: _canResend ? _resendOTP : null,
                                  child: Text(
                                    _canResend
                                        ? 'Didn\'t receive the code? Resend'
                                        : 'Resend in ${_remainingSeconds}s',
                                    style: TextStyle(
                                      color: _canResend
                                          ? Colors.blue[700]
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                        const Spacer(),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 48, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              String enteredOtp = _controllers
                                  .map((controller) => controller.text)
                                  .join();
                              if (enteredOtp == _currentOtp) {
                                updatePhoneNumber();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Invalid OTP. Please try again.')),
                                );
                              }
                            },
                            child: const Text(
                              'Verify',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
