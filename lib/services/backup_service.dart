import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/app_theme.dart';
import 'database_service.dart';

class BackupService {
  static const String _dbName = 'wholesale_billing.db';

  /// Export the current database to a file selected by the user
  static Future<void> backupData(BuildContext context) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, _dbName);
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No database found to backup!'), backgroundColor: AppTheme.errorColor),
          );
        }
        return;
      }

      // Use Share to export the file
      final xFile = XFile(sourcePath, name: 'Backup_${DateTime.now().toIso8601String().split('T')[0]}.db');
      
      await Share.shareXFiles(
        [xFile],
        text: 'Billing App Backup - ${DateTime.now().toString()}',
      );
      
    } catch (e) {
      debugPrint('Backup Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  /// Restore database from a file selected by the user
  static Future<void> restoreData(BuildContext context) async {
    try {
      // Pick a file
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Backup Database',
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        return; // User canceled
      }

      final pickedPath = result.files.single.path!;
      final pickedFile = File(pickedPath);

      // Verify it's a valid SQLite DB
      try {
        final checkDb = await openDatabase(pickedPath, readOnly: true);
        await checkDb.close();
      } catch (e) {
         if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid backup file!'), backgroundColor: AppTheme.errorColor),
          );
        }
        return;
      }

      // Confirm with user
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Backup?'),
          content: const Text('This will overwrite all current data. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              child: const Text('Restore'),
            ),
          ],
        ),
      ) ?? false;

      if (!confirm) return;

      final dbPath = await getDatabasesPath();
      final targetPath = join(dbPath, _dbName);

      // Close current DB connection
      await DatabaseService.instance.close();

      // Copy file
      await pickedFile.copy(targetPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data restored! Please restart the app for changes to take effect.'),
            duration: Duration(seconds: 4),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

    } catch (e) {
      debugPrint('Restore Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}
