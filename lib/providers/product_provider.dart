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

Future<void> upsertProductPrice(String name, double price) async {
  final lowerName = name.toLowerCase().trim();
  final existing = _products.where((p) => p.name.toLowerCase() == lowerName).toList();

  if (existing.isNotEmpty) {
    final product = existing.first;

    final updatedProduct = product.copyWith(
      price: price,
      lastUsed: DateTime.now(),
      usageCount: product.usageCount + 1,
    );

    // Replace in the list
    final index = _products.indexOf(product);
    if (index != -1) {
      _products[index] = updatedProduct;
    }

    // Update DB
    await DatabaseService.instance.upsertProduct(updatedProduct);
  } else {
    // New product
    final newProduct = Product(
      name: name.trim(),
      price: price,
      lastUsed: DateTime.now(),
      usageCount: 1,
    );
    await DatabaseService.instance.upsertProduct(newProduct);
    _products.add(newProduct);
  }

  notifyListeners();
}

  Future<void> addOrUpdateProduct(Product product) async {
    try {
      await DatabaseService.instance.upsertProduct(product);
      final index = _products.indexWhere((p) => p.name == product.name);
      if (index != -1) {
        _products[index] = product;
      } else {
        _products.add(product);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding/updating product: $e');
      // Fallback to reload all products in case of error
      await loadProducts();
    }
  }
}