import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grievance_provider.dart';

class CreateStaffScreen extends StatefulWidget {
  const CreateStaffScreen({super.key});

  @override
  State<CreateStaffScreen> createState() => _CreateStaffScreenState();
}

class _CreateStaffScreenState extends State<CreateStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController(text: 'Estate Office');
  final _passwordController = TextEditingController();

  String _selectedRole = 'jnr';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final prov = Provider.of<GrievanceProvider>(context, listen: false);
    final success = await prov.createStaffAccount(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      department: _departmentController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedRole.toUpperCase()} account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.errorMessage ?? 'Failed to create staff account.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final prov = Provider.of<GrievanceProvider>(context);
    final currentUser = auth.user;
    final bool isAdmin = currentUser?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Create Engineer Account' : 'Create JNR Engineer Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Staff Onboarding',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  isAdmin
                      ? 'Super Admin can register new AE and JNR engineer accounts directly.'
                      : 'As an Assistant Engineer, you can create new Junior Engineer (JNR) accounts.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // Role selector (if admin, can choose AE or JNR; if AE, locked to JNR)
                if (isAdmin)
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Engineer Role',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'jnr', child: Text('Junior Engineer (JNR)')),
                      DropdownMenuItem(value: 'ae', child: Text('Assistant Engineer (AE)')),
                    ],
                    onChanged: (val) => setState(() => _selectedRole = val ?? 'jnr'),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.engineering, color: AppTheme.primaryBlue),
                        SizedBox(width: 10),
                        Text('Role: Junior Engineer (JNR)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Engineer Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter full name' : null,
                ),
                const SizedBox(height: 16),

                // Username / Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Username or Email',
                    hintText: 'e.g. jnr_ramesh or ramesh@annauniv.edu',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter username or email' : null,
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Department
                TextFormField(
                  controller: _departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Department / Section',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Temporary Password
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Initial Password',
                    hintText: 'Minimum 6 characters',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 28),

                // Submit button
                ElevatedButton(
                  onPressed: prov.isLoading ? null : _handleCreate,
                  child: prov.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Engineer Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
