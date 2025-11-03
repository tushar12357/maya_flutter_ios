// lib/core/services/contacts_permission_service.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// iOS-first Contacts permission service
/// Identical UX to MicPermissionService
class ContactsPermissionService {
  ContactsPermissionService._();

  /// Check if granted right now
  static Future<bool> isGranted() async {
    return await Permission.contacts.isGranted;
  }

  /// Request permission + fetch contacts
  /// Returns `null` if denied, otherwise List<Map<String, String>>
  static Future<List<Map<String, String>>?> requestAndFetch(BuildContext context) async {
    // 1. Fast path: already granted
    if (await isGranted()) {
      return await _fetchContacts();
    }

    // 2. Request → shows iOS native dialog: "Allow" / "Don't Allow"
    final status = await Permission.contacts.request();

    // 3. Handle result
    if (status.isGranted) {
      return await _fetchContacts();
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        _showSnack(
          context,
          'Please enable Contacts in Settings → Maya → Contacts',
          showAction: true,
        );
      }
      return null;
    } else {
      if (context.mounted) {
        _showSnack(
          context,
          'Contacts access needed to sync. Tap again to allow.',
        );
      }
      return null;
    }
  }

  /// Internal: fetch contacts after permission
  static Future<List<Map<String, String>>?> _fetchContacts() async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      return contacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) => {
                'name': c.displayName ?? '',
                'phone': c.phones.first.number ?? '',
              })
          .toList();
    } catch (e) {
      debugPrint('Contacts fetch error: $e');
      return null;
    }
  }

  // SnackBar helper — 100% same as MicPermissionService
  static void _showSnack(
    BuildContext context,
    String message, {
    bool showAction = false,
  }) {
    if (!context.mounted) return;
    try {
      final scaffold = ScaffoldMessenger.maybeOf(context);
      scaffold?.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: showAction ? 6 : 3),
          behavior: SnackBarBehavior.floating,
          action: showAction
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () => openAppSettings(),
                )
              : null,
        ),
      );
    } catch (e) {
      debugPrint('SnackBar error: $e');
    }
  }
}