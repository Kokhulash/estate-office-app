import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/grievance_provider.dart';
import '../screens/issue_detail_screen.dart';
import '../screens/report_issue_screen.dart';

class PastIssuesTab extends StatefulWidget {
  const PastIssuesTab({super.key});

  @override
  State<PastIssuesTab> createState() => _PastIssuesTabState();
}

class _PastIssuesTabState extends State<PastIssuesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GrievanceProvider>(context, listen: false).fetchMyGrievances();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<GrievanceProvider>(context);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Past Issues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.fetchMyGrievances(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => prov.fetchMyGrievances(),
        child: prov.isLoading && prov.myGrievances.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : prov.myGrievances.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No Issues Filed Yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "You haven't reported any campus problems yet. Whenever you spot broken infrastructure, report it here!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 46)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ReportIssueScreen()),
                              );
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Report an Issue'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: prov.myGrievances.length,
                    itemBuilder: (context, index) {
                      final item = prov.myGrievances[index];
                      final statusColor = AppConstants.getStatusColor(item.status);
                      final sevColor = AppConstants.getSeverityColor(item.severity);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => IssueDetailScreen(grievanceId: item.id)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: item.imageUrl,
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.grey.shade200),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, size: 28),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item.issueType,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: statusColor, width: 1),
                                            ),
                                            child: Text(
                                              item.status,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.buildingName ?? 'Campus Building',
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                      ),
                                      if (item.locationText != null)
                                        Text(
                                          item.locationText!,
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                        ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: sevColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.severity,
                                              style: TextStyle(color: sevColor, fontWeight: FontWeight.bold, fontSize: 10),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            dateFormat.format(item.createdAt),
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                          ),
                                          const Spacer(),
                                          if (item.isAnonymous)
                                            const Text(
                                              'Anonymous',
                                              style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
