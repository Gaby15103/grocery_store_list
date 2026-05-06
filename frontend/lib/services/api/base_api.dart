// lib/services/base_api.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../../config.dart';
import '../../utils.dart';

abstract class BaseApi {
  final Utils _utils = Utils();
  final String baseUrl = AppConfig.apiUrl;

  // This is shared by every service that extends BaseApi
  Future<Map<String, String>> get headers async {
    final email = Hive.box<String>('metadata').get('userEmail');
    return {
      'Content-Type': 'application/json',
      'x-user-email': email ?? '',
      'x-device-id': await _utils.getUniqueDeviceId()
    };
  }

  /// The Universal Request Wrapper
  /// [method]: 'GET', 'POST', 'PUT', 'DELETE'
  /// [path]: The endpoint (e.g., '/items')
  /// [body]: The data to send (optional)
  /// [fromJson]: A function to convert the JSON response into your Model
  Future<T> request<T>({
    required String method,
    required String path,
    dynamic body,
    required T Function(dynamic json) fromJson,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = http.Client();

    try {
      http.Response response;

      switch (method.toUpperCase()) {
        case 'POST':
          response = await client.post(uri, headers: await headers, body: jsonEncode(body));
          break;
        case 'PUT':
          response = await client.put(uri, headers: await headers, body: jsonEncode(body));
          break;
        case 'DELETE':
        // Some APIs expect a body in DELETE, others don't
          response = await client.delete(uri, headers: await headers, body: body != null ? jsonEncode(body) : null);
          break;
        default: // GET
          response = await client.get(uri, headers: await headers);
      }

      return handleResponse<T>(response, fromJson);
    } finally {
      client.close();
    }
  }

  T handleResponse<T>(http.Response response, T Function(dynamic json) fromJson) {
    final int statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return null as T;
      }

      try {
        final dynamic decodedJson = jsonDecode(response.body);
        return fromJson(decodedJson);
      } catch (e) {
        throw Exception("Failed to parse server response: $e");
      }
    }

    String errorMessage;
    try {

      final errorBody = jsonDecode(response.body);
      errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Unknown server error';
    } catch (_) {
      errorMessage = 'Server returned status code $statusCode';
    }

    switch (statusCode) {
      case 400:
        throw Exception("Bad Request: $errorMessage");
      case 401:
        throw Exception("Unauthorized: Please log in again.");
      case 403:
        throw Exception("Forbidden: You don't have permission for this.");
      case 404:
        throw Exception("Not Found: $errorMessage");
      case 409:
        throw Exception("Conflict: $errorMessage");
      case 500:
        throw Exception("Server Error: Your Arch server might be down. $errorMessage");
      default:
        throw Exception("Error $statusCode: $errorMessage");
    }
  }
}
