// First, add this to your pubspec.yaml:
// dependencies:
//   webview_flutter: ^4.4.2
//   http: ^1.1.0

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// 1. WebXPay Payment Screen
class WebXPayPaymentScreen extends StatefulWidget {
  final String userId;
  final int diamonds;
  final int price;
  final Function(bool success, String? transactionId) onPaymentComplete;

  const WebXPayPaymentScreen({
    super.key,
    required this.userId,
    required this.diamonds,
    required this.price,
    required this.onPaymentComplete,
  });

  @override
  State<WebXPayPaymentScreen> createState() => _WebXPayPaymentScreenState();
}

class _WebXPayPaymentScreenState extends State<WebXPayPaymentScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  String? paymentUrl;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    try {
      // Get payment URL from your backend
      final url = await _getPaymentUrl();
      if (url != null) {
        setState(() {
          paymentUrl = url;
        });
        _initializeWebView();
      } else {
        _showError('Failed to initialize payment');
      }
    } catch (e) {
      _showError('Error initializing payment: $e');
    }
  }

  Future<String?> _getPaymentUrl() async {
    try {
      final response = await http.post(
        Uri.parse(
            '${widget.userId.contains('145.223.21.62') ? 'http://145.223.21.62:6008' : 'http://82.25.180.10:6008'}/api/webxpay/initiate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'amount': widget.price,
          'diamonds': widget.diamonds,
          'currency': 'LKR', // Sri Lankan Rupees for WebXPay
          'description': '${widget.diamonds} Diamond Recharge',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['paymentUrl'];
      }
      return null;
    } catch (e) {
      print('Error getting payment URL: $e');
      return null;
    }
  }

  void _initializeWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            _checkPaymentStatus(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Handle redirects and check for success/failure URLs
            if (request.url.contains('success') ||
                request.url.contains('payment-success')) {
              _handlePaymentSuccess(request.url);
              return NavigationDecision.prevent;
            } else if (request.url.contains('cancel') ||
                request.url.contains('failure')) {
              _handlePaymentFailure(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'PaymentChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(paymentUrl!));
  }

  void _checkPaymentStatus(String url) {
    // Inject JavaScript to listen for payment completion
    controller.runJavaScript('''
      // Listen for WebXPay completion events
      if (typeof window.webxpayCompleted !== 'undefined') {
        PaymentChannel.postMessage('payment_completed:' + window.webxpayCompleted);
      }
      
      // Check for success indicators in the page
      setTimeout(function() {
        var successElement = document.querySelector('.success, .payment-success, [class*="success"]');
        var failureElement = document.querySelector('.error, .payment-error, [class*="error"], [class*="fail"]');
        
        if (successElement) {
          PaymentChannel.postMessage('payment_success:detected');
        } else if (failureElement) {
          PaymentChannel.postMessage('payment_failure:detected');
        }
      }, 2000);
    ''');
  }

  void _handleJavaScriptMessage(String message) {
    if (message.startsWith('payment_success:')) {
      String? transactionId = _extractTransactionId(message);
      _handlePaymentSuccess(transactionId);
    } else if (message.startsWith('payment_failure:')) {
      _handlePaymentFailure(message);
    }
  }

  String? _extractTransactionId(String message) {
    // Extract transaction ID from the message if available
    final parts = message.split(':');
    return parts.length > 1 ? parts[1] : null;
  }

  void _handlePaymentSuccess(String? transactionId) {
    Navigator.of(context).pop();
    widget.onPaymentComplete(true, transactionId);
  }

  void _handlePaymentFailure(String? error) {
    Navigator.of(context).pop();
    widget.onPaymentComplete(false, null);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    Navigator.of(context).pop();
    widget.onPaymentComplete(false, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebXPay Payment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onPaymentComplete(false, null);
          },
        ),
      ),
      body: Stack(
        children: [
          if (paymentUrl != null)
            WebViewWidget(controller: controller)
          else
            const Center(child: CircularProgressIndicator()),
          if (isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading Payment...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 2. Updated WalletScreen with WebXPay Integration
