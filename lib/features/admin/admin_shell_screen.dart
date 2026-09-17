import 'package:flutter/material.dart';
import '../engineer/engineer_shell_screen.dart';
import 'tabs/admin_analytics_tab.dart';
import 'tabs/admin_buildings_tab.dart';
import 'tabs/admin_staff_tab.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {

    final tabs = [
      const AdminAnalyticsTab(),
      const EngineerShellScreen(), // Action Queue (AE & Admin filtered queue)
      const AdminStaffTab(),
      const AdminBuildingsTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_late_outlined),
            activeIcon: Icon(Icons.assignment_late),
            label: 'Action Queue',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment_outlined),
            activeIcon: Icon(Icons.apartment),
            label: 'Buildings',
          ),
        ],
      ),
    );
  }
}
