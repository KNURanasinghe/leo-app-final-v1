import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ProfileCreationScreen.dart';

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

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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

      if (checkResponse.statusCode == 200) {
        final checkData = json.decode(checkResponse.body);

        // If phone number exists
        if (checkData['items'] != null && checkData['items'].length > 0) {
          final existingUser = checkData['items'][0];
          final existingUserId = existingUser['id'];

          // Save existing user ID to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userId', existingUserId);

          // Navigate to appropriate screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    ProfileCreationScreen(userId: existingUserId)),
          );
          return;
        }
      }

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
        String userId = responseData['id'];

        // Save new user ID to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);

        // Navigate to profile creation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => ProfileCreationScreen(userId: userId)),
        );
      } else {
        throw Exception('Failed to create user');
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
                          child: TextButton(
                            onPressed: () {
                              // Resend OTP logic
                              print('Resending OTP: ${widget.otp}');
                            },
                            child: Text(
                              'Didn\'t receive the code? Resend',
                              style: TextStyle(color: Colors.blue[700]),
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
                              if (enteredOtp == widget.otp) {
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
