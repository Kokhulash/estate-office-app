import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/grievance_provider.dart';

class EscalateDialog extends StatefulWidget {
  final String grievanceId;
  const EscalateDialog({super.key, required this.grievanceId});

  @override
  State<EscalateDialog> createState() => _EscalateDialogState();
}

class _EscalateDialogState extends State<EscalateDialog> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitEscalation() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an escalation reason')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final prov = Provider.of<GrievanceProvider>(context, listen: false);
    final success = await prov.escalateTicket(
      grievanceId: widget.grievanceId,
      reason: reason,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prov.errorMessage ?? 'Failed to escalate ticket.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text('Escalate Ticket'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This ticket will be moved immediately into the Assistant Engineer (AE) priority queue.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Escalation Reason *',
              hintText: 'e.g. Requires external contractor, budget approval needed, specialized equipment required',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
          onPressed: _isSubmitting ? null : _submitEscalation,
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Escalate to AE'),
        ),
      ],
    );
  }
}
