import 'package:flutter/material.dart';
import 'data/datasources/local_database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Test Database - FIXED
  final dbHelper = LocalDatabaseHelper();
  final db = await dbHelper.database;
  final products = await db.query('products');  // ✅ Added await
  print('✅ Database ready: ${products.length} products');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billing App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'Database Ready!\nCheck console for ✅\nSay "db ready"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
