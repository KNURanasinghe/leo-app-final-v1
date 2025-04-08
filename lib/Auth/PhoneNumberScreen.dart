import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
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
                            onPressed: () async {
                              String fullPhoneNumber =
                                  '$_selectedCountryCode${_phoneController.text}';
                              String otp = generateOTP();
                              print(
                                  'Generated OTP: $otp'); // Print OTP to console

                              // Notify.lk API credentials (Replace these with your actual credentials)
                              const String userId = '29316';
                              const String apiKey = 'RH9L1weIpJJODyQkFfSe';
                              const String senderId = 'NotifyDEMO';

                              // Notify.lk API endpoint
                              const String url =
                                  'https://app.notify.lk/api/v1/send';

                              // Prepare the message content
                              String message =
                                  'Your verification code is $otp. Please use this to verify your account.';

                              // API call parameters
                              final Map<String, String> queryParams = {
                                'user_id': userId,
                                'api_key': apiKey,
                                'sender_id': senderId,
                                'to': fullPhoneNumber.replaceAll('+',
                                    ''), // Ensure the phone number is in 947XXXXXXXX format
                                'message': message,
                              };

                              try {
                                // Send OTP via Notify.lk API
                                final response = await http.post(
                                  Uri.parse(url)
                                      .replace(queryParameters: queryParams),
                                );
                                print("response");
                                print(response);
                                // Handle API response
                                if (response.statusCode == 200) {
                                  final responseData = response.body;
                                  print(
                                      'Response from Notify.lk: $responseData');

                                  // Check if OTP was sent successfully
                                  if (responseData
                                      .contains('"status":"success"')) {
                                    print('otp: $otp');
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OtpScreen(
                                          phoneNumber: fullPhoneNumber,
                                          otp: otp,
                                        ),
                                      ),
                                    );
                                    // Navigate to OTP screen on success
                                    // Navigator.push(
                                    //   context,
                                    //   MaterialPageRoute(
                                    //     builder: (context) => OtpScreen(
                                    //       phoneNumber: fullPhoneNumber,
                                    //       otp: otp,
                                    //     ),
                                    //   ),
                                    // );
                                  } else {
                                    // Display error if OTP failed to send
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Failed to send OTP. Please try again.')),
                                    );
                                  }
                                } else {
                                  // Handle non-200 response
                                  print(
                                      'Failed to send OTP. Status code: ${response.statusCode}');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Failed to send OTP. Please try again later.')),
                                  );
                                }
                              } catch (e) {
                                // Handle exceptions
                                print('Error occurred while sending OTP: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'An error occurred. Please try again later.')),
                                );
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
