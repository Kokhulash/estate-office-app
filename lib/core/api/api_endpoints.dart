import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  // Configurable base URL
  static String? _customBaseUrl;

  static void setBaseUrl(String url) {
    _customBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    // With 'adb reverse tcp:5000 tcp:5000' enabled, localhost:5000 connects directly
    // to the PC from both physical devices and desktop!
    return 'http://localhost:5000/api';
  }

  // Auth endpoints
  static String get sendRegisterOtp => '$baseUrl/auth/register/send-otp';
  static String get verifyAndRegister => '$baseUrl/auth/register/verify-and-register';
  static String get login => '$baseUrl/auth/login';
  static String get refreshToken => '$baseUrl/auth/refresh-token';
  static String get sendForgotPasswordOtp => '$baseUrl/auth/forgot-password/send-otp';
  static String get resetPassword => '$baseUrl/auth/forgot-password/reset';
  static String get me => '$baseUrl/auth/me';

  // Buildings
  static String get buildings => '$baseUrl/buildings';
  static String buildingById(int id) => '$baseUrl/buildings/$id';

  // Grievances
  static String get grievances => '$baseUrl/grievances';
  static String get grievanceFeed => '$baseUrl/grievances/feed';
  static String get myGrievances => '$baseUrl/grievances/my';
  static String grievanceById(String id) => '$baseUrl/grievances/$id';
  static String upvoteGrievance(String id) => '$baseUrl/grievances/$id/upvote';

  // Engineer
  static String get engineerQueue => '$baseUrl/engineer/queue';
  static String engineerStatus(String id) => '$baseUrl/engineer/$id/status';
  static String engineerEscalate(String id) => '$baseUrl/engineer/$id/escalate';
  static String engineerComment(String id) => '$baseUrl/engineer/$id/comment';

  // Admin
  static String get adminAnalytics => '$baseUrl/admin/analytics';
  static String get adminStaff => '$baseUrl/admin/users';
}
