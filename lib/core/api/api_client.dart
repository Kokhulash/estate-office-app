import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_endpoints.dart';

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    required this.statusCode,
  });
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'jwt_access_token';
  static const String _refreshTokenKey = 'jwt_refresh_token';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final token = await getAccessToken();
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final refresh = await getRefreshToken();
      if (refresh == null) return false;

      final res = await http.post(
        Uri.parse(ApiEndpoints.refreshToken),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['tokens'] != null) {
          final newAccess = body['tokens']['accessToken'];
          final newRefresh = body['tokens']['refreshToken'];
          await saveTokens(accessToken: newAccess, refreshToken: newRefresh);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<ApiResponse> get(String url, {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse(url);
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      var headers = await _getHeaders();
      var response = await http.get(uri, headers: headers);

      if (response.statusCode == 401) {
        // Try refresh token
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          headers = await _getHeaders();
          response = await http.get(uri, headers: headers);
        }
      }

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  Future<ApiResponse> post(String url, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse(url);
      var headers = await _getHeaders();
      var response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          headers = await _getHeaders();
          response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
        }
      }

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  Future<ApiResponse> patch(String url, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse(url);
      var headers = await _getHeaders();
      var response = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          headers = await _getHeaders();
          response = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
        }
      }

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  Future<ApiResponse> delete(String url) async {
    try {
      final uri = Uri.parse(url);
      var headers = await _getHeaders();
      var response = await http.delete(uri, headers: headers);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          headers = await _getHeaders();
          response = await http.delete(uri, headers: headers);
        }
      }

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  /// Multipart POST (for Grievance submission with camera image)
  Future<ApiResponse> postMultipart({
    required String url,
    required Map<String, String> fields,
    required File imageFile,
    required String fileField,
  }) async {
    try {
      final uri = Uri.parse(url);
      var token = await getAccessToken();

      var request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields.addAll(fields);
      final ext = imageFile.path.split('.').last.toLowerCase();
      final subType = (ext == 'png') ? 'png' : 'jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        fileField,
        imageFile.path,
        contentType: MediaType('image', subType),
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          request = http.MultipartRequest('POST', uri);
          if (token != null) {
            request.headers['Authorization'] = 'Bearer $token';
          }
          request.fields.addAll(fields);
          request.files.add(await http.MultipartFile.fromPath(fileField, imageFile.path));
          streamedResponse = await request.send();
          response = await http.Response.fromStream(streamedResponse);
        }
      }

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  /// Multipart PATCH (for Engineer ticket closure with resolution photo)
  Future<ApiResponse> patchMultipart({
    required String url,
    required Map<String, String> fields,
    File? imageFile,
    String? fileField,
  }) async {
    try {
      final uri = Uri.parse(url);
      var token = await getAccessToken();

      var request = http.MultipartRequest('PATCH', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields.addAll(fields);
      if (imageFile != null && fileField != null) {
        final ext = imageFile.path.split('.').last.toLowerCase();
        final subType = (ext == 'png') ? 'png' : 'jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          fileField,
          imageFile.path,
          contentType: MediaType('image', subType),
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          request = http.MultipartRequest('PATCH', uri);
          if (token != null) {
            request.headers['Authorization'] = 'Bearer $token';
          }
          request.fields.addAll(fields);
          if (imageFile != null && fileField != null) {
            request.files.add(await http.MultipartFile.fromPath(fileField, imageFile.path));
          }
          streamedResponse = await request.send();
          response = await http.Response.fromStream(streamedResponse);
        }
      }

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  ApiResponse _handleResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      return ApiResponse(
        success: isSuccess,
        data: body,
        message: body is Map ? body['message'] : null,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        data: response.body,
        message: response.reasonPhrase,
        statusCode: response.statusCode,
      );
    }
  }
}
