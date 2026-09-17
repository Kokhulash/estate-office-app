import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/grievance_model.dart';
import '../../providers/grievance_provider.dart';
import 'close_ticket_modal.dart';
import 'escalate_dialog.dart';

class EngineerTicketDetailScreen extends StatefulWidget {
  final String grievanceId;
  const EngineerTicketDetailScreen({super.key, required this.grievanceId});

  @override
  State<EngineerTicketDetailScreen> createState() => _EngineerTicketDetailScreenState();
}

class _EngineerTicketDetailScreenState extends State<EngineerTicketDetailScreen> {
  GrievanceModel? _grievance;
  bool _isLoading = true;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    final prov = Provider.of<GrievanceProvider>(context, listen: false);
    final detail = await prov.fetchGrievanceDetail(widget.grievanceId);
    if (mounted) {
      setState(() {
        _grievance = detail;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final prov = Provider.of<GrievanceProvider>(context, listen: false);
    final success = await prov.updateStatus(
      grievanceId: widget.grievanceId,
      status: newStatus,
      comment: 'Status updated to $newStatus by engineer.',
    );

    if (success) {
      await _loadTicket();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _markInvalid() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Invalid Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('State the reason why this grievance is marked invalid:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'e.g. Duplicate issue, false report'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Invalid'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prov = Provider.of<GrievanceProvider>(context, listen: false);
      await prov.updateStatus(
        grievanceId: widget.grievanceId,
        status: 'Invalid Report',
        comment: reasonController.text.trim().isNotEmpty
            ? 'INVALID: ${reasonController.text.trim()}'
            : 'Ticket marked as invalid report.',
      );
      await _loadTicket();
    }
  }

  Future<void> _handleAddComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final prov = Provider.of<GrievanceProvider>(context, listen: false);
    final success = await prov.addComment(grievanceId: widget.grievanceId, comment: text);
    if (success) {
      _commentController.clear();
      await _loadTicket();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Triage Ticket')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_grievance == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Triage Ticket')),
        body: const Center(child: Text('Ticket not found')),
      );
    }

    final g = _grievance!;
    final statusColor = AppConstants.getStatusColor(g.status);
    final severityColor = AppConstants.getSeverityColor(g.severity);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket #${g.id.substring(0, 8)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTicket,
          ),
        ],
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
                placeholder: (_, __) => Container(color: Colors.grey.shade200),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image, size: 40)),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overdue / Escalated Alert Banners
                  if (g.isOverdue && g.status != 'Closed Successfully')
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.timer_off_outlined, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'OVERDUE (>48 Hours): Auto-escalated to AE priority queue.',
                              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (g.escalatedAt != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ESCALATED: ${g.escalatedBy ?? "Engineer"} • ${dateFormat.format(g.escalatedAt!)}',
                              style: TextStyle(color: Colors.orange.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Status and Severity chips
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
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
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
                          style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location & Building
                  Text(
                    g.buildingName ?? 'Campus Building',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (g.locationText != null && g.locationText!.isNotEmpty)
                    Text(
                      g.locationText!,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Category: ${g.issueType} • Reported: ${dateFormat.format(g.createdAt)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const Divider(height: 28),

                  // Reporter Information (Section 12: Anonymity Rules)
                  const Text('Reporter Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: g.isAnonymous
                        ? const Row(
                            children: [
                              Icon(Icons.visibility_off, color: Colors.blueGrey, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Reported Anonymously (Contact hidden by student request)',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey, fontSize: 13),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 16, color: AppTheme.primaryBlue),
                                  const SizedBox(width: 6),
                                  Text(
                                    g.reporterDisplayName ?? 'Campus User',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  if (g.reporterDepartment != null)
                                    Text(
                                      ' (${g.reporterDepartment})',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                    ),
                                ],
                              ),
                              if (g.reporterEmail != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 15, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(g.reporterEmail!, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ],
                              if (g.reporterPhone != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 15, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(g.reporterPhone!, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                  ),
                  const Divider(height: 28),

                  // Description
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    (g.description != null && g.description!.isNotEmpty) ? g.description! : 'None provided',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                  ),

                  // Closing resolution photo if closed
                  if (g.closingPhotoUrl != null && g.closingPhotoUrl!.isNotEmpty) ...[
                    const Divider(height: 28),
                    const Text('Resolution Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: g.closingPhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ],

                  const Divider(height: 32),

                  // ENGINEER ACTIONS (Spec Section 7 & 8)
                  const Text('Triage & Management Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),

                  if (g.status != 'Closed Successfully' && g.status != 'Invalid Report') ...[
                    // Action 1: Move to In Progress
                    if (g.status == 'Submitted')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                        onPressed: () => _updateStatus('In Progress'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Work (Mark In Progress)'),
                      ),
                    const SizedBox(height: 10),

                    // Action 2: Close Successfully (Requires Photo!)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                      onPressed: () async {
                        final closed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => CloseTicketModal(grievanceId: g.id),
                        );
                        if (closed == true) {
                          await _loadTicket();
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Resolve & Close (Attach Photo)'),
                    ),
                    const SizedBox(height: 10),

                    // Action 3: Escalate to AE queue (with reason)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade800),
                      ),
                      onPressed: () async {
                        final escalated = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => EscalateDialog(grievanceId: g.id),
                        );
                        if (escalated == true) {
                          await _loadTicket();
                        }
                      },
                      icon: const Icon(Icons.trending_up),
                      label: const Text('Escalate to AE Queue'),
                    ),
                    const SizedBox(height: 10),

                    // Action 4: Reject as Invalid Report
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade400),
                      ),
                      onPressed: _markInvalid,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Mark as Invalid Report'),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            g.status == 'Closed Successfully' ? Icons.check_circle : Icons.cancel,
                            color: g.status == 'Closed Successfully' ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'This ticket has been finalized as ${g.status}.',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                  const Divider(height: 32),

                  // Comments & Notes
                  const Text('Internal Activity & Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Add an engineer note...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send),
                        onPressed: _handleAddComment,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Timeline logs
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: g.statusHistory.length,
                    itemBuilder: (context, idx) {
                      final log = g.statusHistory[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.circle, size: 10, color: AppTheme.primaryBlue),
                        title: Text(log.comment ?? log.newStatus ?? 'Update', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          '${dateFormat.format(log.createdAt)}${log.actorRole != null ? " • ${log.actorRole!.toUpperCase()}" : ""}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
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
