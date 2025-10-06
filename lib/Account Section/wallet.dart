import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:leo_app_01/Account%20Section/webx_payment_screen.dart';

class WalletScreen extends material.StatefulWidget {
  final String userId;

  const WalletScreen({super.key, required this.userId});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends material.State<WalletScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String API_BASE_URL = 'http://145.223.21.62:6007';
  String? _selectedPaymentMethod = 'WebXPay'; // Default to WebXPay
  int? _diamondAmount;
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController emailAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDiamondAmount();
  }

  Future<void> _fetchDiamondAmount() async {
    final url = Uri.parse(
        'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final diamondAmount = jsonData['wallet'];

        setState(() {
          _diamondAmount = diamondAmount;
        });
      } else {
        print('Failed to fetch diamond amount: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching diamond amount: $e');
    }
  }

  Future<void> _updateUserDiamonds(int newDiamondAmount) async {
    try {
      var response = await http.patch(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'wallet': newDiamondAmount}),
      );

      if (response.statusCode == 200) {
        _fetchDiamondAmount();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User diamonds updated successfully")),
        );
      } else {
        print('Failed to update user diamonds: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating user diamonds: $e');
    }
  }

  Future<void> _addRechargeHistory(
      int diamonds, int price, String? transactionId) async {
    try {
      var response = await http.post(
        Uri.parse('$API_BASE_URL/api/recharge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'diamond_amount': diamonds,
          'price_of_the_diamond': price,
          'transaction_id': transactionId,
          'payment_method': 'WebXPay',
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Recharge history added successfully")),
        );
      } else {
        print('Failed to add recharge history: ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        print('Error details: ${errorData['details']}');
      }
    } catch (e) {
      print('Error adding recharge history: $e');
    }
  }

  void _processWebXPayRecharge(int diamonds, int price) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebXPayPaymentScreen(
          userId: widget.userId,
          diamonds: diamonds,
          price: price,
          onPaymentComplete: (bool success, String? transactionId) {
            if (success) {
              _handleSuccessfulPayment(diamonds, price, transactionId);
            } else {
              _handleFailedPayment();
            }
          },
        ),
      ),
    );
  }

  void _handleSuccessfulPayment(
      int diamonds, int price, String? transactionId) {
    // Update user diamonds
    int updatedDiamondAmount = (_diamondAmount ?? 0) + diamonds;
    _updateUserDiamonds(updatedDiamondAmount);
    _addRechargeHistory(diamonds, price, transactionId);

    setState(() {
      _diamondAmount = updatedDiamondAmount;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Payment successful! $diamonds diamonds added to your wallet.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleFailedPayment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment failed. Please try again.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade300,
              Colors.blue.shade800,
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 46, right: 46),
                  height: 200,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 150,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/wallet_img.png'),
                              opacity: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                  title: const Text(
                    'Wallet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  alignment: Alignment.topLeft,
                  margin: const EdgeInsets.only(left: 20),
                  child: _diamondAmount != null
                      ? _buildBalanceWidget(_diamondAmount!)
                      : const CircularProgressIndicator(),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade200,
                          Colors.blue.shade800,
                        ],
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recharge Channel',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: [
                                Text('Sri Lanka',
                                    style: TextStyle(color: Colors.white)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_drop_down,
                                    color: Colors.white),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // _buildRechargeChannel('WebXPay',
                        //     'assets/images/webxpay_logo.png', 'WebXPay'),
                        _buildRechargeChannel('Google Pay',
                            'assets/images/google_pay.png', 'GPay'),
                        _buildRechargeChannel('VISA/MASTERCARD',
                            'assets/images/visa_mastercard.png', 'Visa'),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            children: [
                              _buildDiamondPackage(
                                  context, 50, 100), // LKR pricing
                              _buildDiamondPackage(context, 100, 500),
                              _buildDiamondPackage(context, 200, 1500),
                              _buildDiamondPackage(context, 500, 3000),
                              _buildDiamondPackage(context, 63000, 5000),
                              _buildDiamondPackage(context, 126000, 10000),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceWidget(int diamondAmount) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Balance',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            diamondAmount.toString(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRechargeChannel(String name, String asset, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _selectedPaymentMethod,
        onChanged: (String? newValue) {
          setState(() {
            _selectedPaymentMethod = newValue;
          });
        },
        title: Text(
          name,
          style: const TextStyle(color: Colors.blue),
        ),
        secondary: Image.asset(asset, width: 40, height: 40,
            errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.payment, color: Colors.blue, size: 40);
        }),
        activeColor: Colors.blue,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildDiamondPackage(BuildContext context, int diamonds, int price) {
    // Get screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive sizes
    final imageSize =
        screenWidth < 360 ? 35.0 : (screenWidth < 600 ? 45.0 : 50.0);
    final diamondFontSize =
        screenWidth < 360 ? 14.0 : (screenWidth < 600 ? 16.0 : 18.0);
    final priceFontSize =
        screenWidth < 360 ? 12.0 : (screenWidth < 600 ? 13.0 : 14.0);
    final verticalSpacing = screenWidth < 360 ? 4.0 : 8.0;
    final cardPadding = screenWidth < 360 ? 8.0 : 12.0;

    return GestureDetector(
      onTap: () {
        _processWebXPayRecharge(diamonds, price);
      },
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/diamond.png',
                width: imageSize,
                height: imageSize,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.diamond,
                    color: Colors.blue,
                    size: imageSize,
                  );
                },
              ),
              SizedBox(height: verticalSpacing),
              Text(
                '$diamonds',
                style: TextStyle(
                  fontSize: diamondFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: verticalSpacing / 2),
              Text(
                'LKR $price',
                style: TextStyle(
                  fontSize: priceFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
