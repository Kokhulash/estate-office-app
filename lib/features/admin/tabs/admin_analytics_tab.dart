import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/grievance_provider.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GrievanceProvider>(context, listen: false).fetchAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<GrievanceProvider>(context);
    final a = prov.analytics;

    if (prov.isLoading && a == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (a == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Unable to load analytics data.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => prov.fetchAnalytics(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final s = a.summary;

    return RefreshIndicator(
      onRefresh: () async => prov.fetchAnalytics(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Campus Executive Analytics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => prov.fetchAnalytics(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Metric Cards (Spec Section 9 & 14)
            Row(
              children: [
                Expanded(
                  child: _metricCard('Total Volume', '${s['total_issues'] ?? 0}', Icons.bar_chart, Colors.indigo),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricCard('Open Active', '${(s['submitted_count'] ?? 0) + (s['in_progress_count'] ?? 0)}', Icons.pending_actions, Colors.amber.shade800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _metricCard('Closed Resolved', '${s['closed_count'] ?? 0}', Icons.check_circle_outline, Colors.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricCard('Escalation Rate', '${s['escalation_rate_percent'] ?? 0}%', Icons.trending_up, Colors.red.shade700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _metricCard(
              'Avg Resolution Time',
              '${s['overall_avg_resolution_hours'] ?? 0} Hours',
              Icons.timelapse,
              AppTheme.primaryBlue,
            ),
            const SizedBox(height: 24),

            // Average Resolution Time Breakdown by Category
            _sectionHeader('Average Resolution Time (Hours)'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: a.resolutionByType.isEmpty
                    ? const Text('No closed tickets data available yet for resolution benchmarks.', style: TextStyle(color: Colors.grey))
                    : Column(
                        children: a.resolutionByType.map<Widget>((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(item['issue_type'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                Text(
                                  '${item['avg_hours']} hrs (${item['count']} resolved)',
                                  style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Breakdown by Issue Category
            _sectionHeader('Complaints Breakdown by Category'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: a.breakdownByType.isEmpty
                    ? const Text('No complaints logged yet.', style: TextStyle(color: Colors.grey))
                    : Column(
                        children: a.breakdownByType.map<Widget>((item) {
                          final count = item['count'] ?? 0;
                          final total = s['total_issues'] ?? 1;
                          final pct = total > 0 ? (count / total) : 0.0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['issue_type'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                    Text('$count issues', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: pct.toDouble(),
                                  backgroundColor: Colors.grey.shade200,
                                  color: AppTheme.primaryBlue,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Top Buildings by Incident Volume
            _sectionHeader('Top Buildings by Maintenance Volume'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: a.topBuildings.isEmpty
                    ? const Text('No building data available.', style: TextStyle(color: Colors.grey))
                    : Column(
                        children: a.topBuildings.map<Widget>((b) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.apartment, color: AppTheme.primaryBlue),
                            title: Text(b['building_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Code: ${b['building_code']}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${b['volume']} reports',
                                style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Engineer Performance (Tickets closed per JNR/AE)
            _sectionHeader('Engineer Resolution Performance (Audit Log)'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: a.engineerPerformance.isEmpty
                    ? const Text('No closed tickets attributed to engineers yet.', style: TextStyle(color: Colors.grey))
                    : Column(
                        children: a.engineerPerformance.map<Widget>((e) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(e['engineer_role']?.toString().toUpperCase() ?? 'ENG', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(e['engineer_name'] ?? 'Engineer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Role: ${e['engineer_role']?.toString().toUpperCase()}'),
                            trailing: Text(
                              '${e['tickets_closed']} Resolved',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
