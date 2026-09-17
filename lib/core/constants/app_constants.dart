import 'package:flutter/material.dart';

class AppConstants {
  static const List<String> issueTypes = [
    'Civil',
    'Electrical',
    'Cleaning',
    'Bathroom Related Issues',
    'Others',
  ];

  static const List<String> severities = [
    'Low',
    'Medium',
    'High',
  ];

  static const List<String> statuses = [
    'Submitted',
    'In Progress',
    'Closed Successfully',
    'Invalid Report',
  ];

  static const List<String> naiveUserRoles = [
    'student',
    'faculty',
    'employee',
  ];

  static Color getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade800;
      case 'low':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  static Color getStatusColor(String? status) {
    switch (status) {
      case 'Submitted':
        return Colors.blue.shade700;
      case 'In Progress':
        return Colors.amber.shade900;
      case 'Closed Successfully':
        return Colors.green.shade700;
      case 'Invalid Report':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  static IconData getIssueIcon(String? issueType) {
    switch (issueType) {
      case 'Civil':
        return Icons.construction;
      case 'Electrical':
        return Icons.bolt;
      case 'Cleaning':
        return Icons.cleaning_services;
      case 'Bathroom Related Issues':
        return Icons.water_drop;
      default:
        return Icons.report_problem;
    }
  }
}
