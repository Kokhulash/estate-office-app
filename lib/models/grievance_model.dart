import 'status_log_model.dart';

class GrievanceModel {
  final String id;
  final String? reporterId;
  final bool isAnonymous;
  final String imageUrl;
  final String? description;
  final int? buildingId;
  final String? buildingName;
  final String? buildingCode;
  final String? locationText;
  final String issueType;
  final String severity;
  final String status;
  final DateTime? escalatedAt;
  final String? escalatedBy;
  final String? closingPhotoUrl;
  final int upvoteCount;
  final bool hasUpvoted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? reporterDisplayName;
  final String? reporterEmail;
  final String? reporterPhone;
  final String? reporterDepartment;
  final List<StatusLogModel> statusHistory;
  final bool isOverdue;

  GrievanceModel({
    required this.id,
    this.reporterId,
    this.isAnonymous = false,
    required this.imageUrl,
    this.description,
    this.buildingId,
    this.buildingName,
    this.buildingCode,
    this.locationText,
    required this.issueType,
    required this.severity,
    required this.status,
    this.escalatedAt,
    this.escalatedBy,
    this.closingPhotoUrl,
    this.upvoteCount = 0,
    this.hasUpvoted = false,
    required this.createdAt,
    this.updatedAt,
    this.reporterDisplayName,
    this.reporterEmail,
    this.reporterPhone,
    this.reporterDepartment,
    this.statusHistory = const [],
    this.isOverdue = false,
  });

  GrievanceModel copyWith({
    bool? hasUpvoted,
    int? upvoteCount,
    String? status,
    String? closingPhotoUrl,
  }) {
    return GrievanceModel(
      id: id,
      reporterId: reporterId,
      isAnonymous: isAnonymous,
      imageUrl: imageUrl,
      description: description,
      buildingId: buildingId,
      buildingName: buildingName,
      buildingCode: buildingCode,
      locationText: locationText,
      issueType: issueType,
      severity: severity,
      status: status ?? this.status,
      escalatedAt: escalatedAt,
      escalatedBy: escalatedBy,
      closingPhotoUrl: closingPhotoUrl ?? this.closingPhotoUrl,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      hasUpvoted: hasUpvoted ?? this.hasUpvoted,
      createdAt: createdAt,
      updatedAt: updatedAt,
      reporterDisplayName: reporterDisplayName,
      reporterEmail: reporterEmail,
      reporterPhone: reporterPhone,
      reporterDepartment: reporterDepartment,
      statusHistory: statusHistory,
      isOverdue: isOverdue,
    );
  }

  factory GrievanceModel.fromJson(Map<String, dynamic> json) {
    var history = <StatusLogModel>[];
    if (json['status_history'] != null && json['status_history'] is List) {
      history = (json['status_history'] as List)
          .map((item) => StatusLogModel.fromJson(item))
          .toList();
    }

    return GrievanceModel(
      id: json['id'] ?? '',
      reporterId: json['reporter_id'],
      isAnonymous: json['is_anonymous'] == true,
      imageUrl: json['image_url'] ?? '',
      description: json['description'],
      buildingId: json['building_id'] != null ? int.tryParse(json['building_id'].toString()) : null,
      buildingName: json['building_name'],
      buildingCode: json['building_code'],
      locationText: json['location_text'],
      issueType: json['issue_type'] ?? 'Others',
      severity: json['severity'] ?? 'Medium',
      status: json['status'] ?? 'Submitted',
      escalatedAt: json['escalated_at'] != null ? DateTime.tryParse(json['escalated_at']) : null,
      escalatedBy: json['escalated_by'],
      closingPhotoUrl: json['closing_photo_url'],
      upvoteCount: json['upvote_count'] is int ? json['upvote_count'] : int.tryParse(json['upvote_count']?.toString() ?? '0') ?? 0,
      hasUpvoted: json['has_upvoted'] == true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      reporterDisplayName: json['reporter_display_name'] ?? json['reporter_name'],
      reporterEmail: json['reporter_email'],
      reporterPhone: json['reporter_phone'],
      reporterDepartment: json['reporter_department'],
      statusHistory: history,
      isOverdue: json['is_overdue'] == true,
    );
  }
}
