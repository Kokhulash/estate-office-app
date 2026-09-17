import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/grievance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grievance_provider.dart';
import '../auth/login_screen.dart';
import 'engineer_ticket_detail.dart';
import 'create_jnr_screen.dart';

class EngineerShellScreen extends StatefulWidget {
  const EngineerShellScreen({super.key});

  @override
  State<EngineerShellScreen> createState() => _EngineerShellScreenState();
}

class _EngineerShellScreenState extends State<EngineerShellScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _filterStatus = 'All';
  String _filterIssueType = 'All';
  String _filterSeverity = 'All';
  int? _filterBuildingId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadQueue();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = Provider.of<GrievanceProvider>(context, listen: false);
      prov.fetchBuildings();
      _loadQueue();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadQueue() {
    final prov = Provider.of<GrievanceProvider>(context, listen: false);
    String? queueType;
    if (_tabController.index == 1) {
      queueType = 'escalated';
    } else if (_tabController.index == 2) {
      queueType = 'all';
    }

    prov.fetchEngineerQueue(
      status: _filterStatus == 'All' ? null : _filterStatus,
      issueType: _filterIssueType == 'All' ? null : _filterIssueType,
      severity: _filterSeverity == 'All' ? null : _filterSeverity,
      buildingId: _filterBuildingId,
      queueType: queueType,
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final prov = Provider.of<GrievanceProvider>(context, listen: false);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter Triage Queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterStatus = 'All';
                            _filterIssueType = 'All';
                            _filterSeverity = 'All';
                            _filterBuildingId = null;
                          });
                          Navigator.pop(ctx);
                          _loadQueue();
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Building Filter
                  DropdownButtonFormField<int?>(
                    value: _filterBuildingId,
                    hint: const Text('All Buildings'),
                    decoration: const InputDecoration(labelText: 'Campus Building'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All Buildings')),
                      ...prov.buildings.map((b) => DropdownMenuItem<int?>(
                            value: b.id,
                            child: Text('${b.name} (${b.code})', overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) => setModalState(() => _filterBuildingId = val),
                  ),
                  const SizedBox(height: 12),

                  // Issue Type Filter
                  DropdownButtonFormField<String>(
                    value: _filterIssueType,
                    decoration: const InputDecoration(labelText: 'Issue Category'),
                    items: ['All', ...AppConstants.issueTypes].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setModalState(() => _filterIssueType = val ?? 'All'),
                  ),
                  const SizedBox(height: 12),

                  // Severity Filter
                  DropdownButtonFormField<String>(
                    value: _filterSeverity,
                    decoration: const InputDecoration(labelText: 'Severity Level'),
                    items: ['All', ...AppConstants.severities].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setModalState(() => _filterSeverity = val ?? 'All'),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(ctx);
                      _loadQueue();
                    },
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final prov = Provider.of<GrievanceProvider>(context);
    final user = auth.user;
    final bool isAe = user?.isAe == true;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isAe ? 'AE Supervise & Escalations' : 'JNR Maintenance Queue'),
            Text(
              '${user?.name ?? "Engineer"} • ${user?.roleDisplayName ?? ""}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: _showFilterModal,
          ),
          // AE Action: Create JNR Staff (Spec 8)
          if (isAe)
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Create JNR Account',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateStaffScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Active Queue'),
            Tab(text: 'Escalated / Overdue'),
            Tab(text: 'All Tickets'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadQueue(),
        child: prov.isLoading && prov.engineerQueue.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : prov.engineerQueue.isEmpty
                ? const Center(child: Text('No tickets found in this queue.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: prov.engineerQueue.length,
                    itemBuilder: (context, index) {
                      final item = prov.engineerQueue[index];
                      return _buildEngineerCard(item);
                    },
                  ),
      ),
    );
  }

  Widget _buildEngineerCard(GrievanceModel item) {
    final statusColor = AppConstants.getStatusColor(item.status);
    final sevColor = AppConstants.getSeverityColor(item.severity);
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EngineerTicketDetailScreen(grievanceId: item.id),
            ),
          );
          _loadQueue();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overdue or Escalated Pill
              if (item.isOverdue || item.escalatedAt != null) ...[
                Row(
                  children: [
                    if (item.isOverdue && item.status != 'Closed Successfully')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'OVERDUE >48H',
                          style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    if (item.escalatedAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ESCALATED',
                          style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Row(
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
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Summary
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
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.buildingName ?? 'Campus Building',
                          style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (item.locationText != null)
                          Text(
                            item.locationText!,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                                style: TextStyle(color: sevColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              dateFormat.format(item.createdAt),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Reporter Line (Section 12: Anonymity Rules)
              Row(
                children: [
                  Icon(
                    item.isAnonymous ? Icons.visibility_off : Icons.person,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.isAnonymous ? 'Reporter: Anonymous' : 'Reporter: ${item.reporterDisplayName ?? "Campus User"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.isAnonymous ? Colors.blueGrey : Colors.black87,
                      fontStyle: item.isAnonymous ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
