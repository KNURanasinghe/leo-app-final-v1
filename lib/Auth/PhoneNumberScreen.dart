import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../HomeScreen.dart';
import '../services/api_service.dart';
import 'OtpScreen.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  _PhoneNumberScreenState createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  String _selectedCountryCode = '+1';
  String _selectedCountryFlag = '🇺🇸';
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

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
                              'assets/phone.png',
                              width: constraints.maxWidth * 0.8,
                              height: constraints.maxHeight * 0.3,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Enter your phone number',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'ll send you a verification code',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                showCountryPicker(
                                  context: context,
                                  showPhoneCode: true,
                                  onSelect: (Country country) {
                                    setState(() {
                                      _selectedCountryCode =
                                          '+${country.phoneCode}';
                                      _selectedCountryFlag = country.flagEmoji;
                                    });
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(_selectedCountryFlag,
                                        style: const TextStyle(fontSize: 24)),
                                    const SizedBox(width: 8),
                                    Text(_selectedCountryCode,
                                        style: const TextStyle(fontSize: 16)),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 18),
                                decoration: InputDecoration(
                                  hintText: 'Phone Number',
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                            // Modify the onPressed method of your Next button in PhoneNumberScreen
                            onPressed: () async {
                              // Show loading indicator
                              setState(() {
                                _isLoading = true;
                              });

                              String fullPhoneNumber =
                                  '$_selectedCountryCode${_phoneController.text}';
                              // Clean the phone number to match the format in the database
                              String cleanedNumber = fullPhoneNumber.replaceAll(
                                  RegExp(r'[^0-9]'), '');
                              print('cleanedNumber: $cleanedNumber');
                              try {
                                // Initialize the UserApiService
                                final userApiService = UserApiService(
                                  baseUrl:
                                      'http://145.223.21.62:8090', // Replace with your actual base URL
                                );

                                // Check if user exists
                                final existingUser = await userApiService
                                    .getUserByPhoneNumber(cleanedNumber);

                                if (existingUser != null) {
                                  final prefs =
                                      await SharedPreferences.getInstance();

                                  String userId = existingUser.id;
                                  prefs.setString('userId', userId);
                                  String username = existingUser.firstname;
                                  print('Found user with ID: $userId');
                                  print('Found user with username: $username');
                                  // User exists, navigate directly to home
                                  print(
                                      'User found! Navigating to Home Screen');
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HomeScreen(
                                        userId: userId,
                                        username: username,
                                      ),
                                    ),
                                  );
                                } else {
                                  // User doesn't exist, continue with OTP process
                                  String otp = generateOTP();
                                  print('Generated OTP: $otp'); // For debugging

                                  // Continue with your existing OTP sending logic
                                  const String userId = '29316';
                                  const String apiKey = 'RH9L1weIpJJODyQkFfSe';
                                  const String senderId = 'NotifyDEMO';
                                  const String url =
                                      'https://app.notify.lk/api/v1/send';

                                  String message =
                                      'Your verification code is $otp. Please use this to verify your account.';

                                  final Map<String, String> queryParams = {
                                    'user_id': userId,
                                    'api_key': apiKey,
                                    'sender_id': senderId,
                                    'to':
                                        cleanedNumber, // Using the cleaned number format
                                    'message': message,
                                  };

                                  // Send OTP via Notify.lk API
                                  final response = await http.post(
                                    Uri.parse(url)
                                        .replace(queryParameters: queryParams),
                                  );

                                  print("API Response: ${response.statusCode}");

                                  if (response.statusCode == 200) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OtpScreen(
                                          phoneNumber: fullPhoneNumber,
                                          otp: otp,
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Show error message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Failed to send OTP. Please try again.')),
                                    );
                                  }
                                }
                              } catch (e) {
                                // Handle error
                                print('Error: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Error: ${e.toString()}')),
                                );
                              } finally {
                                // Hide loading indicator
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                            child: const Text(
                              'Next',
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

  String generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }
}
