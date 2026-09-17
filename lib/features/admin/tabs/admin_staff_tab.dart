import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/grievance_provider.dart';
import '../../engineer/create_jnr_screen.dart';

class AdminStaffTab extends StatefulWidget {
  const AdminStaffTab({super.key});

  @override
  State<AdminStaffTab> createState() => _AdminStaffTabState();
}

class _AdminStaffTabState extends State<AdminStaffTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GrievanceProvider>(context, listen: false).fetchStaffList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<GrievanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff & Engineers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Create Engineer',
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreateStaffScreen()),
              );
              if (created == true) {
                prov.fetchStaffList();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.fetchStaffList(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => prov.fetchStaffList(),
        child: prov.staffList.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: prov.staffList.length,
                itemBuilder: (context, index) {
                  final staff = prov.staffList[index];
                  final role = staff['role']?.toString().toUpperCase() ?? 'STAFF';
                  Color roleColor = Colors.blueGrey;
                  if (role == 'ADMIN') roleColor = Colors.purple;
                  if (role == 'AE') roleColor = Colors.indigo;
                  if (role == 'JNR') roleColor = Colors.teal;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: roleColor.withOpacity(0.15),
                        child: Text(
                          role,
                          style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      title: Text(staff['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email/Username: ${staff['email'] ?? ''}', style: const TextStyle(fontSize: 12)),
                          if (staff['phone'] != null)
                            Text('Phone: ${staff['phone']}', style: const TextStyle(fontSize: 12)),
                          if (staff['department'] != null)
                            Text('Dept: ${staff['department']}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: roleColor),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateStaffScreen()),
          );
          if (created == true) {
            prov.fetchStaffList();
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Engineer'),
      ),
    );
  }
}
