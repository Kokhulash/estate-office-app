import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/grievance_provider.dart';

class AdminBuildingsTab extends StatefulWidget {
  const AdminBuildingsTab({super.key});

  @override
  State<AdminBuildingsTab> createState() => _AdminBuildingsTabState();
}

class _AdminBuildingsTabState extends State<AdminBuildingsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GrievanceProvider>(context, listen: false).fetchBuildings();
    });
  }

  void _showAddBuildingDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Campus Building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Building Name', hintText: 'e.g. Bio-Tech Block'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Building Code', hintText: 'e.g. BT-01'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final code = codeController.text.trim();
              if (name.isEmpty || code.isEmpty) return;

              final prov = Provider.of<GrievanceProvider>(context, listen: false);
              final ok = await prov.createBuilding(name, code);
              if (ctx.mounted) Navigator.pop(ctx);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Building added successfully!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Add Building'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<GrievanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Buildings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Building',
            onPressed: _showAddBuildingDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.fetchBuildings(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => prov.fetchBuildings(),
        child: prov.buildings.isEmpty
            ? const Center(child: Text('No buildings found.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: prov.buildings.length,
                itemBuilder: (context, index) {
                  final b = prov.buildings[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.apartment, color: AppTheme.primaryBlue),
                      ),
                      title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Code: ${b.code}'),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        onPressed: _showAddBuildingDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
