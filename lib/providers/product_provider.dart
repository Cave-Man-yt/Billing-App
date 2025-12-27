// lib/providers/product_provider.dart

import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/database_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  ProductProvider() {
    loadProducts();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await DatabaseService.instance.getAllProducts();
    } catch (e) {
      debugPrint('Error loading products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<Product>> searchProducts(String query) async {
  final lower = query.toLowerCase().trim();

  // Always try in-memory first — even if query empty or short
  if (_products.isNotEmpty) {
    final matches = _products.where((p) => p.name.toLowerCase().contains(lower)).toList();
    if (matches.isNotEmpty) {
      return matches.take(10).toList();
    }
  }

  // Only fallback to DB if no in-memory matches
  if (lower.isEmpty) return [];
  return await DatabaseService.instance.searchProducts(lower);
}

  Future<void> addOrUpdateProduct(Product product) async {
    try {
      await DatabaseService.instance.upsertProduct(product);
      await loadProducts();
    } catch (e) {
      debugPrint('Error adding/updating product: $e');
    }
  }
}