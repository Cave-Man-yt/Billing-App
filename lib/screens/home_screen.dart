// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'billing_screen.dart';
import 'history_screen.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';
import '../utils/app_theme.dart';

/// Main home screen with bottom navigation for tablet interface
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();  // ← CHANGE: Remove underscore to make it public
}

class HomeScreenState extends State<HomeScreen> {  // ← CHANGE: Remove underscore
  int _currentIndex = 0;

  // Navigation screens
  final List<Widget> _screens = const [
    BillingScreen(),
    HistoryScreen(),
    CustomersScreen(),
    SettingsScreen(),
  ];

  // ← NEW: Method to switch tabs programmatically
  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppTheme.cardBackground,
        indicatorColor: AppTheme.primaryLight.withAlpha((0.3 * 255).round()),
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'New Bill',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}