import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class Web3FormsService {
  static const String _apiKey = '5a6855b2-0368-4eae-a717-0b5c398bd3d1';
  static const String _baseUrl = 'https://api.web3forms.com/submit';

  /// Sends feedback to the support team using Web3Forms API
  ///
  /// Returns a [Map] with 'success' boolean and 'message' string
  static Future<Map<String, dynamic>> sendFeedback({
    required String name,
    required String email,
    required String message,
    required String feedbackType,
  }) async {
    try {
      // Create the subject line
      final subject = '$name sent $feedbackType feedback';

      // Prepare the request body according to Web3Forms format
      final Map<String, dynamic> requestBody = {
        'access_key': _apiKey,
        'name': name,
        'email': email,
        'message': message,
        'subject': subject,
        'feedback_type': feedbackType,
        'from_app': true
      };

      print('Request Body: $requestBody');

      // Make the API request
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode(requestBody),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // Parse the response
      final responseData = json.decode(response.body);

      // Handle the response
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Thank you for your feedback!'
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ??
              'Failed to send feedback. Please try again.'
        };
      }
    } catch (e) {
      print('Exception: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> sendFeedbackWithAttachments({
    required String name,
    required String email,
    required String message,
    required String feedbackType,
    required List<Map<String, dynamic>> attachments,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));

      // Add form fields
      request.fields['access_key'] = _apiKey;
      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['message'] = message;
      request.fields['subject'] = '$name sent $feedbackType feedback';
      request.fields['feedback_type'] = feedbackType;
      request.fields['from_app'] = 'true';

      // Add attachments
      for (var file in attachments) {
        final bytes = file['bytes'] as Uint8List?;
        if (bytes != null) {
          final mimeType = lookupMimeType(file['name'] ?? 'file') ??
              'application/octet-stream';
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file['name'],
            contentType: MediaType.parse(mimeType),
          ));
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Thank you for your feedback!'
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to send feedback.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}
