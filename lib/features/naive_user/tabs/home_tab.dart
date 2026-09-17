import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grievance_provider.dart';
import '../screens/report_issue_screen.dart';
import '../screens/issue_detail_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onNavigateToFeed;
  final VoidCallback onNavigateToPastIssues;

  const HomeTab({
    super.key,
    required this.onNavigateToFeed,
    required this.onNavigateToPastIssues,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = Provider.of<GrievanceProvider>(context, listen: false);
      prov.fetchBuildings();
      prov.fetchMyGrievances();
      prov.fetchCommunityFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final prov = Provider.of<GrievanceProvider>(context);
    final user = auth.user;

    final myActiveCount = prov.myGrievances.where((g) => g.status != 'Closed Successfully' && g.status != 'Invalid Report').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Redressal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              prov.fetchMyGrievances();
              prov.fetchCommunityFeed();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await prov.fetchMyGrievances();
          await prov.fetchCommunityFeed();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryBlue, AppTheme.secondaryBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white24,
                          radius: 22,
                          child: Text(
                            user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${user?.name ?? 'Student'}!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${user?.roleDisplayName ?? 'Student'} • ${user?.department ?? 'Anna University'}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Found a physical maintenance issue on campus?',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 14),

                    // Big "Report an Issue" Button (Spec 6.2)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryBlue,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReportIssueScreen()),
                        );
                      },
                      icon: const Icon(Icons.camera_alt, color: AppTheme.primaryBlue),
                      label: const Text(
                        'Report an Issue',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Status Overview
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      title: 'My Active Issues',
                      value: '$myActiveCount',
                      icon: Icons.assignment_late_outlined,
                      color: Colors.amber.shade800,
                      onTap: widget.onNavigateToPastIssues,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      title: 'Campus Feed',
                      value: '${prov.communityFeed.length}',
                      icon: Icons.dynamic_feed,
                      color: AppTheme.secondaryBlue,
                      onTap: widget.onNavigateToFeed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Community Issues Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Campus Issues',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToFeed,
                    child: const Text('View All Feed'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (prov.communityFeed.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Text('No grievances filed on campus yet. Be the first to report!'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: prov.communityFeed.take(3).length,
                  itemBuilder: (context, idx) {
                    final item = prov.communityFeed[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, size: 24),
                            ),
                          ),
                        ),
                        title: Text(item.issueType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(item.buildingName ?? 'Campus Building', style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.thumb_up, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${item.upvoteCount}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IssueDetailScreen(grievanceId: item.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
