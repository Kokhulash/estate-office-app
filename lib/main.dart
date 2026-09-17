import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/grievance_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/naive_user/user_shell_screen.dart';
import 'features/engineer/engineer_shell_screen.dart';
import 'features/admin/admin_shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GrievanceRedressalApp());
}

class GrievanceRedressalApp extends StatelessWidget {
  const GrievanceRedressalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GrievanceProvider()),
      ],
      child: MaterialApp(
        title: 'Campus Grievance Redressal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.checkAuthStatus();
    if (mounted) {
      setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Campus Grievance Redressal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isAuthenticated || auth.user == null) {
      return const LoginScreen();
    }

    final user = auth.user!;
    if (user.isAdmin) {
      return const AdminShellScreen();
    } else if (user.isEngineer) {
      return const EngineerShellScreen();
    } else {
      return const UserShellScreen();
    }
  }
}
