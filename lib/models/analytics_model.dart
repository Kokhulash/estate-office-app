class AnalyticsModel {
  final Map<String, dynamic> summary;
  final List<dynamic> volumeOverTime;
  final List<dynamic> topBuildings;
  final List<dynamic> breakdownByType;
  final List<dynamic> breakdownBySeverity;
  final List<dynamic> resolutionByType;
  final List<dynamic> resolutionByBuilding;
  final List<dynamic> resolutionBySeverity;
  final List<dynamic> engineerPerformance;

  AnalyticsModel({
    required this.summary,
    required this.volumeOverTime,
    required this.topBuildings,
    required this.breakdownByType,
    required this.breakdownBySeverity,
    required this.resolutionByType,
    required this.resolutionByBuilding,
    required this.resolutionBySeverity,
    required this.engineerPerformance,
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsModel(
      summary: json['summary'] ?? {},
      volumeOverTime: json['volume_over_time'] ?? [],
      topBuildings: json['top_buildings'] ?? [],
      breakdownByType: json['breakdown_by_type'] ?? [],
      breakdownBySeverity: json['breakdown_by_severity'] ?? [],
      resolutionByType: json['resolution_by_type'] ?? [],
      resolutionByBuilding: json['resolution_by_building'] ?? [],
      resolutionBySeverity: json['resolution_by_severity'] ?? [],
      engineerPerformance: json['engineer_performance'] ?? [],
    );
  }
}
