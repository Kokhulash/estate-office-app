import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/grievance_model.dart';
import '../../../providers/grievance_provider.dart';

class IssueDetailScreen extends StatefulWidget {
  final String grievanceId;
  const IssueDetailScreen({super.key, required this.grievanceId});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  GrievanceModel? _grievance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final prov = Provider.of<GrievanceProvider>(context, listen: false);
    final detail = await prov.fetchGrievanceDetail(widget.grievanceId);
    if (mounted) {
      setState(() {
        _grievance = detail;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Issue Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_grievance == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Issue Details')),
        body: const Center(child: Text('Grievance ticket not found.')),
      );
    }

    final g = _grievance!;
    final statusColor = AppConstants.getStatusColor(g.status);
    final severityColor = AppConstants.getSeverityColor(g.severity);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(g.issueType),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Problem Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: g.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & Severity Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor, width: 1.2),
                        ),
                        child: Text(
                          g.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: severityColor, width: 1.2),
                        ),
                        child: Text(
                          '${g.severity} Severity',
                          style: TextStyle(
                            color: severityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (g.isAnonymous)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_off, size: 14, color: Colors.grey),
                              SizedBox(width: 4),
                              Text('Anonymous', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location Information
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.apartment, color: AppTheme.primaryBlue, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.buildingName ?? 'Campus Building',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (g.locationText != null && g.locationText!.isNotEmpty)
                              Text(
                                g.locationText!,
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date Reported
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.grey.shade600, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Reported: ${dateFormat.format(g.createdAt)}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (g.description != null && g.description!.isNotEmpty)
                        ? g.description!
                        : 'No description provided.',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 14, height: 1.4),
                  ),

                  // Resolution Photo (if closed)
                  if (g.closingPhotoUrl != null && g.closingPhotoUrl!.isNotEmpty) ...[
                    const Divider(height: 32),
                    const Text(
                      'Resolution Proof (Work Completed)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: g.closingPhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 36)),
                        ),
                      ),
                    ),
                  ],

                  const Divider(height: 32),

                  // Status History Timeline
                  const Text(
                    'Status History & Timeline',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (g.statusHistory.isEmpty)
                    Text('No status logs recorded.', style: TextStyle(color: Colors.grey.shade600))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: g.statusHistory.length,
                      itemBuilder: (context, index) {
                        final log = g.statusHistory[index];
                        final isLast = index == g.statusHistory.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 48,
                                    color: Colors.grey.shade300,
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.newStatus ?? 'Status Log',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (log.comment != null && log.comment!.isNotEmpty)
                                      Text(
                                        log.comment!,
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dateFormat.format(log.createdAt)}${log.actorRole != null ? " • ${log.actorRole!.toUpperCase()}" : ""}',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
