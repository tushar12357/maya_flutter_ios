import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// A reusable service for handling microphone permissions
class MicPermissionService {
  MicPermissionService._();

  /// Returns `true` if we have permission **right now**.
  static Future<bool> isGranted() async {
    return await Permission.microphone.isGranted;
  }

  /// Request permission.
  /// Returns `true` **only** when the user finally grants it.
  /// 
  /// This will automatically show the iOS system permission dialog
  /// with "Allow" and "Don't Allow" buttons on first request.
  static Future<bool> request(BuildContext context) async {
    // 1. Already granted → fast path
    if (await isGranted()) return true;

    // 2. Request permission - this shows iOS system dialog automatically
    //    The system dialog has "Allow" and "Don't Allow" buttons
    final status = await Permission.microphone.request();

    // 3. Handle the result
    if (status.isGranted) {
      // Permission granted!
      return true;
    } else if (status.isPermanentlyDenied) {
      // User denied twice - can only be enabled via Settings now
      if (context.mounted) {
        _showSnack(
          context,
          'Please enable microphone in Settings → Maya → Microphone',
          showAction: true,
        );
      }
      return false;
    } else {
      // User denied once - they can try again
      if (context.mounted) {
        _showSnack(
          context,
          'Microphone access is needed. Tap the orb again to allow.',
        );
      }
      return false;
    }
  }

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
      debugPrint('Error showing snackbar: $e');
    }
  }
}