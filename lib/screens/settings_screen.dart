// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:billing_app/providers/settings_provider.dart';
import 'package:billing_app/utils/app_theme.dart';
import 'package:billing_app/services/pdf_service.dart';

/// Screen for managing application settings.
/// Includes shop details and print preferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _shopAddressController = TextEditingController();
  final TextEditingController _shopPhoneController = TextEditingController();
  final TextEditingController _shopEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _shopNameController.text = settings.shopName;
    _shopAddressController.text = settings.shopAddress;
    _shopPhoneController.text = settings.shopPhone;
    _shopEmailController.text = settings.shopEmail;
  }

  Future<void> _saveSettings() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    await settings.updateShopDetails(
      name: _shopNameController.text,
      address: _shopAddressController.text,
      phone: _shopPhoneController.text,
      email: _shopEmailController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Shop Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _shopNameController,
              decoration: const InputDecoration(
                labelText: 'Shop Name *',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _shopAddressController,
              decoration: const InputDecoration(
                labelText: 'Shop Address',
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _shopPhoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _shopEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 32),
            
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('SAVE SETTINGS'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            
            // PDF Print Settings Section
            Text(
              'Print Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Default PDF Size',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose your preferred bill size. You can change this anytime when printing.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<PdfPageSize>(
                      value: PdfPageSize.a5,
                      // ignore: deprecated_member_use
                      groupValue: PdfService.preferredSize,
                      // ignore: deprecated_member_use
                      onChanged: (value) {
                        PdfService.preferredSize = value!;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Default size set to A5'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      title: const Text('A5 (148mm × 210mm)'),
                      subtitle: const Text('Recommended for invoices'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<PdfPageSize>(
                      value: PdfPageSize.a4,
                      // ignore: deprecated_member_use
                      groupValue: PdfService.preferredSize,
                      // ignore: deprecated_member_use
                      onChanged: (value) {
                        PdfService.preferredSize = value!;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Default size set to A4'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      title: const Text('A4 (210mm × 297mm)'),
                      subtitle: const Text('Standard letter size'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _shopEmailController.dispose();
    super.dispose();
  }
}
