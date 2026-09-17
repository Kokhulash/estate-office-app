import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _client = ApiClient();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<bool> checkAuthStatus() async {
    try {
      final token = await _client.getAccessToken();
      if (token == null || token.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await _client.get(ApiEndpoints.me);
      if (response.success && response.data != null && response.data['user'] != null) {
        _user = UserModel.fromJson(response.data['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        await _client.clearTokens();
        _user = null;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendRegistrationOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _client.post(ApiEndpoints.sendRegisterOtp, body: {'email': email});
    _isLoading = false;

    if (response.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Failed to send OTP.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyAndRegister({
    required String name,
    required String department,
    required String email,
    required String phone,
    required String password,
    required String role,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _client.post(
      ApiEndpoints.verifyAndRegister,
      body: {
        'name': name,
        'department': department,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
        'otp': otp,
      },
    );

    _isLoading = false;
    if (response.success && response.data != null) {
      final userData = response.data['user'];
      final tokens = response.data['tokens'];

      await _client.saveTokens(
        accessToken: tokens['accessToken'],
        refreshToken: tokens['refreshToken'],
      );

      _user = UserModel.fromJson(userData);
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Registration failed.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String identifier, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _client.post(
      ApiEndpoints.login,
      body: {
        'email': identifier.contains('@') ? identifier : null,
        'username': !identifier.contains('@') ? identifier : null,
        'password': password,
      },
    );

    _isLoading = false;
    if (response.success && response.data != null) {
      final userData = response.data['user'];
      final tokens = response.data['tokens'];

      await _client.saveTokens(
        accessToken: tokens['accessToken'],
        refreshToken: tokens['refreshToken'],
      );

      _user = UserModel.fromJson(userData);
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Login failed. Please check credentials.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendForgotPasswordOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _client.post(ApiEndpoints.sendForgotPasswordOtp, body: {'email': email});
    _isLoading = false;

    if (response.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Failed to send reset code.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _client.post(
      ApiEndpoints.resetPassword,
      body: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      },
    );

    _isLoading = false;
    if (response.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Password reset failed.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _client.clearTokens();
    _user = null;
    notifyListeners();
  }
}
