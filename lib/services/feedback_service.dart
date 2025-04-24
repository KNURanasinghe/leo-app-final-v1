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

  /// Sends feedback with attachments to the support team using Web3Forms API
  ///
  /// Returns a [Map] with 'success' boolean and 'message' string
  static Future<Map<String, dynamic>> sendFeedbackWithAttachments({
    required String name,
    required String email,
    required String message,
    required String feedbackType,
    required List<Map<String, dynamic>> attachments,
  }) async {
    try {
      // Create a multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));

      // Add form fields
      request.fields['access_key'] = _apiKey;
      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['message'] = message;
      request.fields['subject'] = '$name sent $feedbackType feedback';
      request.fields['feedback_type'] = feedbackType;
      request.fields['from_app'] = 'true';

      print('Preparing ${attachments.length} attachments for upload');

      // Add attachments
      for (int i = 0; i < attachments.length; i++) {
        final file = attachments[i];
        final bytes = file['data'] as Uint8List?;

        if (bytes != null) {
          // Determine the MIME type based on the file name, defaulting to octet-stream if unknown
          final fileName = file['name'] as String? ?? 'file_$i';
          final mimeType =
              lookupMimeType(fileName) ?? 'application/octet-stream';

          // Create the multipart file
          final multipartFile = http.MultipartFile.fromBytes(
            'attachment', // The field name that Web3Forms expects for attachments
            bytes,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          );

          // Add the file to the request
          request.files.add(multipartFile);
          print(
              'Added file: $fileName (${bytes.length} bytes, type: $mimeType)');
        }
      }

      print('Sending request with ${request.files.length} files');

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

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
      print('Exception in sendFeedbackWithAttachments: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection and try again.'
      };
    }
  }
}
