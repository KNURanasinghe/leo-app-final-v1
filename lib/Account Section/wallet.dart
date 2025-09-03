import 'package:flutter/material.dart' as material;
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class WalletScreen extends material.StatefulWidget {
  final String userId;

  const WalletScreen({super.key, required this.userId});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends material.State<WalletScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String API_BASE_URL = 'http://145.223.21.62:6007';
  String? _selectedPaymentMethod;
  int? _diamondAmount;
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController emailAddressController = TextEditingController();

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
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(
              content: material.Text("User diamonds updated successfully")),
        );
      } else {
        print('Failed to update user diamonds: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating user diamonds: $e');
    }
  }

  Future<void> _addRechargeHistory(int diamonds, int price) async {
    try {
      var response = await http.post(
        Uri.parse('$API_BASE_URL/api/recharge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'diamond_amount': diamonds,
          'price_of_the_diamond': price,
        }),
      );

      if (response.statusCode == 200) {
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(
              content: Text("Recharge history added successfully")),
        );
      } else {
        print('Failed to add recharge history: ${response.statusCode}');
        // Parse error message from Node.js server
        final errorData = jsonDecode(response.body);
        print('Error details: ${errorData['details']}');
      }
    } catch (e) {
      print('Error adding recharge history: $e');
    }
  }

  Future<void> _processRecharge(int diamonds, int price) async {
    int updatedDiamondAmount = (_diamondAmount ?? 0) + diamonds;

    await _updateUserDiamonds(updatedDiamondAmount);
    await _addRechargeHistory(diamonds, price);

    setState(() {
      _diamondAmount = updatedDiamondAmount;
    });
  }

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

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      body: material.Container(
        decoration: material.BoxDecoration(
          gradient: material.LinearGradient(
            begin: material.Alignment.topLeft,
            end: material.Alignment.bottomRight,
            colors: [
              material.Colors.blue.shade300,
              material.Colors.blue.shade800,
            ],
          ),
        ),
        child: material.Stack(
          children: [
            material.Column(
              children: [
                material.Container(
                  margin: const material.EdgeInsets.only(top: 46, right: 46),
                  height: 200,
                  child: material.Stack(
                    children: [
                      material.Align(
                        alignment: material.Alignment.centerRight,
                        child: material.Container(
                          width: 150,
                          decoration: const material.BoxDecoration(
                            image: material.DecorationImage(
                              image: material.AssetImage(
                                  'assets/images/wallet_img.png'),
                              opacity: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                material.Expanded(
                  child: material.Container(
                    color: material.Colors.transparent,
                  ),
                ),
              ],
            ),
            material.Column(
              children: [
                material.AppBar(
                  backgroundColor: material.Colors.transparent,
                  elevation: 0,
                  leading: material.IconButton(
                    icon: const material.Icon(material.Icons.arrow_back,
                        color: material.Colors.white),
                    onPressed: () {
                      material.Navigator.pop(context);
                    },
                  ),
                  actions: [
                    material.IconButton(
                      icon: const material.Icon(material.Icons.menu_rounded,
                          color: material.Colors.white),
                      onPressed: () {},
                    ),
                  ],
                  title: const material.Text(
                    'Wallet',
                    style: material.TextStyle(
                      color: material.Colors.white,
                      fontWeight: material.FontWeight.bold,
                    ),
                  ),
                ),
                material.Container(
                  alignment: material.Alignment.topLeft,
                  margin: const material.EdgeInsets.only(left: 20),
                  child: _diamondAmount != null
                      ? _buildBalanceWidget(_diamondAmount!)
                      : const material.CircularProgressIndicator(),
                ),
                material.Expanded(
                  child: material.Container(
                    padding: const material.EdgeInsets.all(16),
                    decoration: material.BoxDecoration(
                      gradient: material.LinearGradient(
                        begin: material.Alignment.topLeft,
                        end: material.Alignment.bottomRight,
                        colors: [
                          material.Colors.blue.shade200,
                          material.Colors.blue.shade800,
                        ],
                      ),
                      borderRadius: const material.BorderRadius.vertical(
                          top: material.Radius.circular(30)),
                    ),
                    child: material.Column(
                      crossAxisAlignment: material.CrossAxisAlignment.start,
                      children: [
                        const material.SizedBox(height: 16),
                        const material.Row(
                          mainAxisAlignment:
                              material.MainAxisAlignment.spaceBetween,
                          children: [
                            material.Text(
                              'Recharge Channel',
                              style: material.TextStyle(
                                fontSize: 18,
                                fontWeight: material.FontWeight.bold,
                                color: material.Colors.white,
                              ),
                            ),
                            material.Row(
                              children: [
                                material.Text('Saudi Arabia',
                                    style: material.TextStyle(
                                        color: material.Colors.white)),
                                material.SizedBox(width: 8),
                                material.Icon(material.Icons.arrow_drop_down,
                                    color: material.Colors.white),
                              ],
                            ),
                          ],
                        ),
                        const material.SizedBox(height: 8),
                        _buildRechargeChannel('Google Pay',
                            'assets/images/google_pay.png', 'GPay'),
                        _buildRechargeChannel('VISA/MASTERCARD',
                            'assets/images/visa_mastercard.png', 'Visa'),
                        const material.SizedBox(height: 16),
                        material.Expanded(
                          child: material.GridView.count(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            children: [
                              _buildDiamondPackage(context, 50, 10),
                              _buildDiamondPackage(context, 100, 50),
                              _buildDiamondPackage(context, 200, 150),
                              _buildDiamondPackage(context, 500, 300),
                              _buildDiamondPackage(context, 63000, 500),
                              _buildDiamondPackage(context, 126000, 1000),
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

  material.Widget _buildBalanceWidget(int diamondAmount) {
    return material.Container(
      color: material.Colors.transparent,
      padding: const material.EdgeInsets.all(16),
      child: material.Column(
        crossAxisAlignment: material.CrossAxisAlignment.start,
        children: [
          const material.Text(
            'Balance',
            style: material.TextStyle(
              fontSize: 32,
              fontWeight: material.FontWeight.bold,
              color: material.Colors.white,
            ),
          ),
          const material.SizedBox(height: 8),
          material.Text(
            diamondAmount.toString(),
            style: const material.TextStyle(
              fontSize: 32,
              fontWeight: material.FontWeight.bold,
              color: material.Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  material.Widget _buildRechargeChannel(
      String name, String asset, String value) {
    return material.Container(
      margin: const material.EdgeInsets.symmetric(vertical: 4),
      decoration: material.BoxDecoration(
        color: material.Colors.white,
        borderRadius: material.BorderRadius.circular(8),
      ),
      child: material.RadioListTile<String>(
        value: value,
        groupValue: _selectedPaymentMethod,
        onChanged: (String? newValue) {
          setState(() {
            _selectedPaymentMethod = newValue;
          });
        },
        title: material.Text(
          name,
          style: const material.TextStyle(color: material.Colors.blue),
        ),
        secondary: material.Image.asset(asset, width: 40),
        activeColor: material.Colors.blue,
        contentPadding: const material.EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  material.Widget _buildDiamondPackage(
      material.BuildContext context, int diamonds, int price) {
    return material.GestureDetector(
      onTap: () => _processRecharge(diamonds, price),
      child: material.Card(
        color: material.Colors.white,
        child: material.Column(
          mainAxisAlignment: material.MainAxisAlignment.center,
          crossAxisAlignment: material.CrossAxisAlignment.center,
          children: [
            material.Image.asset(
              'assets/images/diamond.png',
              width: 50,
            ),
            const material.SizedBox(height: 2),
            material.Text(
              '$diamonds',
              style: const material.TextStyle(
                fontSize: 18,
                fontWeight: material.FontWeight.bold,
              ),
            ),
            const material.SizedBox(height: 2),
            material.Text(
              'USD $price',
              style: const material.TextStyle(
                fontSize: 14,
                fontWeight: material.FontWeight.w600,
                color: material.Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
