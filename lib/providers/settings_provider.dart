// lib/providers/settings_provider.dart

import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SettingsProvider with ChangeNotifier {
  String _shopName = 'Your Shop Name';
  String _shopAddress = '';
  String _shopPhone = '';
  String _shopEmail = '';
  double _taxPercentage = 0.0;

  String get shopName => _shopName;
  String get shopAddress => _shopAddress;
  String get shopPhone => _shopPhone;
  String get shopEmail => _shopEmail;
  double get taxPercentage => _taxPercentage;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final settings = await DatabaseService.instance.getSettings();
      _shopName = settings['shop_name'] ?? 'Your Shop Name';
      _shopAddress = settings['shop_address'] ?? '';
      _shopPhone = settings['shop_phone'] ?? '';
      _shopEmail = settings['shop_email'] ?? '';
      _taxPercentage = (settings['tax_percentage'] as num?)?.toDouble() ?? 0.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> updateShopName(String name) async {
    _shopName = name;
    await DatabaseService.instance.updateSettings({'shop_name': name});
    notifyListeners();
  }

  Future<void> updateShopDetails({
    String? name,
    String? address,
    String? phone,
    String? email,
    double? taxPercentage,
  }) async {
    final updates = <String, dynamic>{};
    
    if (name != null) {
      _shopName = name;
      updates['shop_name'] = name;
    }
    if (address != null) {
      _shopAddress = address;
      updates['shop_address'] = address;
    }
    if (phone != null) {
      _shopPhone = phone;
      updates['shop_phone'] = phone;
    }
    if (email != null) {
      _shopEmail = email;
      updates['shop_email'] = email;
    }
    if (taxPercentage != null) {
      _taxPercentage = taxPercentage;
      updates['tax_percentage'] = taxPercentage;
    }

    if (updates.isNotEmpty) {
      await DatabaseService.instance.updateSettings(updates);
      notifyListeners();
    }
  }
}