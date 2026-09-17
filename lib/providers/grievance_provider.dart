import 'dart:io';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/building_model.dart';
import '../models/grievance_model.dart';
import '../models/analytics_model.dart';

class GrievanceProvider extends ChangeNotifier {
  final ApiClient _client = ApiClient();

  List<BuildingModel> _buildings = [];
  List<GrievanceModel> _communityFeed = [];
  List<GrievanceModel> _myGrievances = [];
  List<GrievanceModel> _engineerQueue = [];
  AnalyticsModel? _analytics;
  List<dynamic> _staffList = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<BuildingModel> get buildings => _buildings;
  List<GrievanceModel> get communityFeed => _communityFeed;
  List<GrievanceModel> get myGrievances => _myGrievances;
  List<GrievanceModel> get engineerQueue => _engineerQueue;
  AnalyticsModel? get analytics => _analytics;
  List<dynamic> get staffList => _staffList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch campus buildings for dropdown
  Future<void> fetchBuildings() async {
    try {
      final res = await _client.get(ApiEndpoints.buildings);
      if (res.success && res.data != null && res.data['buildings'] != null) {
        final list = (res.data['buildings'] as List)
            .map((item) => BuildingModel.fromJson(item))
            .toList();
        _buildings = list;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Submit new grievance (Camera photo required)
  Future<bool> submitGrievance({
    required File imageFile,
    required int buildingId,
    required String issueType,
    required String severity,
    String? description,
    String? locationText,
    bool isAnonymous = false,
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fields = <String, String>{
        'building_id': buildingId.toString(),
        'issue_type': issueType,
        'severity': severity,
        'is_anonymous': isAnonymous.toString(),
        'image_captured_at': DateTime.now().toIso8601String(),
      };

      if (description != null && description.isNotEmpty) {
        fields['description'] = description;
      }
      if (locationText != null && locationText.isNotEmpty) {
        fields['location_text'] = locationText;
      }
      if (latitude != null) {
        fields['image_gps_lat'] = latitude.toString();
      }
      if (longitude != null) {
        fields['image_gps_lng'] = longitude.toString();
      }

      final res = await _client.postMultipart(
        url: ApiEndpoints.grievances,
        fields: fields,
        imageFile: imageFile,
        fileField: 'image',
      );

      _isLoading = false;
      if (res.success) {
        // Refresh feed & my issues
        await fetchCommunityFeed();
        await fetchMyGrievances();
        notifyListeners();
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to submit grievance.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Fetch Community Feed
  Future<void> fetchCommunityFeed({String? status, int? buildingId, String? issueType}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (status != null && status != 'All') queryParams['status'] = status;
      if (buildingId != null) queryParams['building_id'] = buildingId.toString();
      if (issueType != null && issueType != 'All') queryParams['issue_type'] = issueType;

      final res = await _client.get(ApiEndpoints.grievanceFeed, queryParams: queryParams);
      _isLoading = false;

      if (res.success && res.data != null && res.data['feed'] != null) {
        _communityFeed = (res.data['feed'] as List)
            .map((item) => GrievanceModel.fromJson(item))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Fetch My Grievances
  Future<void> fetchMyGrievances() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _client.get(ApiEndpoints.myGrievances);
      _isLoading = false;

      if (res.success && res.data != null && res.data['grievances'] != null) {
        _myGrievances = (res.data['grievances'] as List)
            .map((item) => GrievanceModel.fromJson(item))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Fetch single grievance by ID with status timeline
  Future<GrievanceModel?> fetchGrievanceDetail(String id) async {
    try {
      final res = await _client.get(ApiEndpoints.grievanceById(id));
      if (res.success && res.data != null && res.data['grievance'] != null) {
        return GrievanceModel.fromJson(res.data['grievance']);
      }
    } catch (_) {}
    return null;
  }

  /// Toggle Upvote
  Future<void> toggleUpvote(String grievanceId) async {
    // Optimistic UI update in feed
    final index = _communityFeed.indexWhere((g) => g.id == grievanceId);
    if (index != -1) {
      final current = _communityFeed[index];
      final newHasUpvoted = !current.hasUpvoted;
      final newCount = newHasUpvoted ? current.upvoteCount + 1 : (current.upvoteCount > 0 ? current.upvoteCount - 1 : 0);
      _communityFeed[index] = current.copyWith(hasUpvoted: newHasUpvoted, upvoteCount: newCount);
      notifyListeners();
    }

    try {
      final res = await _client.post(ApiEndpoints.upvoteGrievance(grievanceId));
      if (res.success && res.data != null && index != -1) {
        final serverUpvoted = res.data['has_upvoted'] == true;
        final serverCount = res.data['upvote_count'] ?? 0;
        _communityFeed[index] = _communityFeed[index].copyWith(
          hasUpvoted: serverUpvoted,
          upvoteCount: serverCount,
        );
        notifyListeners();
      }
    } catch (_) {
      // Revert if error
      await fetchCommunityFeed();
    }
  }

  /// Fetch Engineer Triage Queue
  Future<void> fetchEngineerQueue({
    String? status,
    int? buildingId,
    String? issueType,
    String? severity,
    String? queueType,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (status != null && status != 'All') queryParams['status'] = status;
      if (buildingId != null) queryParams['building_id'] = buildingId.toString();
      if (issueType != null && issueType != 'All') queryParams['issue_type'] = issueType;
      if (severity != null && severity != 'All') queryParams['severity'] = severity;
      if (queueType != null) queryParams['queue_type'] = queueType;

      final res = await _client.get(ApiEndpoints.engineerQueue, queryParams: queryParams);
      _isLoading = false;

      if (res.success && res.data != null && res.data['queue'] != null) {
        _engineerQueue = (res.data['queue'] as List)
            .map((item) => GrievanceModel.fromJson(item))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Update Ticket Status (with required resolution photo if Closed Successfully)
  Future<bool> updateStatus({
    required String grievanceId,
    required String status,
    String? comment,
    String? severity,
    File? resolutionPhoto,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fields = <String, String>{
        'status': status,
      };
      if (comment != null && comment.isNotEmpty) fields['comment'] = comment;
      if (severity != null && severity.isNotEmpty) fields['severity'] = severity;

      ApiResponse res;
      if (resolutionPhoto != null) {
        res = await _client.patchMultipart(
          url: ApiEndpoints.engineerStatus(grievanceId),
          fields: fields,
          imageFile: resolutionPhoto,
          fileField: 'resolution_photo',
        );
      } else {
        res = await _client.patch(
          ApiEndpoints.engineerStatus(grievanceId),
          body: fields,
        );
      }

      _isLoading = false;
      if (res.success) {
        await fetchEngineerQueue();
        notifyListeners();
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to update status.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Escalate ticket with reason
  Future<bool> escalateTicket({required String grievanceId, required String reason}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _client.post(
        ApiEndpoints.engineerEscalate(grievanceId),
        body: {'reason': reason},
      );

      _isLoading = false;
      if (res.success) {
        await fetchEngineerQueue();
        notifyListeners();
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to escalate ticket.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Add comment to ticket
  Future<bool> addComment({required String grievanceId, required String comment}) async {
    try {
      final res = await _client.post(
        ApiEndpoints.engineerComment(grievanceId),
        body: {'comment': comment},
      );
      return res.success;
    } catch (_) {
      return false;
    }
  }

  /// Admin: Fetch Analytics
  Future<void> fetchAnalytics() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _client.get(ApiEndpoints.adminAnalytics);
      _isLoading = false;

      if (res.success && res.data != null && res.data['analytics'] != null) {
        _analytics = AnalyticsModel.fromJson(res.data['analytics']);
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Admin/AE: Fetch Staff list
  Future<void> fetchStaffList() async {
    try {
      final res = await _client.get(ApiEndpoints.adminStaff);
      if (res.success && res.data != null && res.data['staff'] != null) {
        _staffList = res.data['staff'] as List;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Admin/AE: Create Staff Account
  Future<bool> createStaffAccount({
    required String name,
    required String email,
    required String phone,
    required String department,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _client.post(
        ApiEndpoints.adminStaff,
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'department': department,
          'password': password,
          'role': role,
        },
      );

      _isLoading = false;
      if (res.success) {
        await fetchStaffList();
        notifyListeners();
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to create staff account.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Admin: Create Building
  Future<bool> createBuilding(String name, String code) async {
    try {
      final res = await _client.post(
        ApiEndpoints.buildings,
        body: {'name': name, 'code': code},
      );
      if (res.success) {
        await fetchBuildings();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
