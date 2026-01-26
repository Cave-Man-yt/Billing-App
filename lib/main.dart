// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/bill_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/product_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force landscape orientation for 
  // 01tablet
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
  
  // Initialize database
  await DatabaseService.instance.database;
  
  runApp(const WholesaleBillingApp());
}

class WholesaleBillingApp extends StatelessWidget {
  const WholesaleBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProxyProvider<CustomerProvider, BillProvider>(
          create: (context) => BillProvider(
            Provider.of<CustomerProvider>(context, listen: false),
          ),
          update: (context, customerProvider, billProvider) =>
              billProvider!..update(customerProvider),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Wholesale Billing',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}