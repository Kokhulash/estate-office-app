class StatusLogModel {
  final int id;
  final String? oldStatus;
  final String? newStatus;
  final String? comment;
  final String? actorRole;
  final String? actorName;
  final DateTime createdAt;

  StatusLogModel({
    required this.id,
    this.oldStatus,
    this.newStatus,
    this.comment,
    this.actorRole,
    this.actorName,
    required this.createdAt,
  });

  factory StatusLogModel.fromJson(Map<String, dynamic> json) {
    return StatusLogModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      oldStatus: json['old_status'],
      newStatus: json['new_status'],
      comment: json['comment'],
      actorRole: json['actor_role'],
      actorName: json['actor_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
