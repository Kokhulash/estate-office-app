import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/grievance_provider.dart';
import '../../../models/grievance_model.dart';
import '../screens/issue_detail_screen.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  String _selectedStatus = 'All';
  final String _selectedIssueType = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFeed();
    });
  }

  void _fetchFeed() {
    final prov = Provider.of<GrievanceProvider>(context, listen: false);
    prov.fetchCommunityFeed(
      status: _selectedStatus == 'All' ? null : _selectedStatus,
      issueType: _selectedIssueType == 'All' ? null : _selectedIssueType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<GrievanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Community Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFeed,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips (Status)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: ['All', 'Submitted', 'In Progress', 'Closed Successfully', 'Invalid Report'].map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryBlue.withOpacity(0.15),
                    checkmarkColor: AppTheme.primaryBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryBlue : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedStatus = selected ? status : 'All');
                      _fetchFeed();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Feed List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _fetchFeed(),
              child: prov.isLoading && prov.communityFeed.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : prov.communityFeed.isEmpty
                      ? const Center(
                          child: Text(
                            'No grievances match the selected filter.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: prov.communityFeed.length,
                          itemBuilder: (context, index) {
                            final item = prov.communityFeed[index];
                            return _buildFeedCard(item, prov);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCard(GrievanceModel item, GrievanceProvider prov) {
    final statusColor = AppConstants.getStatusColor(item.status);
    final severityColor = AppConstants.getSeverityColor(item.severity);
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => IssueDetailScreen(grievanceId: item.id)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges: Issue Type, Status, Severity
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(AppConstants.getIssueIcon(item.issueType), size: 14, color: AppTheme.primaryBlue),
                            const SizedBox(width: 4),
                            Text(
                              item.issueType,
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.severity,
                          style: TextStyle(
                            color: severityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateFormat.format(item.createdAt),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Building & Location
                  Row(
                    children: [
                      const Icon(Icons.apartment, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item.buildingName ?? 'Campus Building'}${item.locationText != null ? " • ${item.locationText}" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Short Description
                  if (item.description != null && item.description!.isNotEmpty)
                    Text(
                      item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                    ),
                  const SizedBox(height: 12),

                  // Footer: Anonymity enforced (no reporter name) + Upvote Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Campus Reporter (Anonymous)',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),

                      // Upvote Button (Spec 6.4: One vote per user, prevents duplicate complaints)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => prov.toggleUpvote(item.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: item.hasUpvoted ? AppTheme.primaryBlue : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: item.hasUpvoted ? AppTheme.primaryBlue : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.hasUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                                size: 15,
                                color: item.hasUpvoted ? Colors.white : Colors.grey.shade800,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${item.upvoteCount}',
                                style: TextStyle(
                                  color: item.hasUpvoted ? Colors.white : Colors.grey.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
