import 'dart:io';
import 'package:flutter/material.dart';

class ErrorRecoveryManager {
  static Future<void> handleError(
    BuildContext context, 
    Object error, 
    {StackTrace? stackTrace, String? customMessage}
  ) async {
    debugPrint('Error caught: $error');
    if (stackTrace != null) debugPrint('Stacktrace: $stackTrace');

    String message = customMessage ?? 'An unexpected error occurred.';
    String actionLabel = 'OK';
    VoidCallback? onAction;

    if (error is FileSystemException) {
      message = 'Cannot access file. Please check permissions or if the file exists.';
    } else if (error.toString().contains('format')) {
      message = 'Invalid or unsupported file format.';
    } else if (error is OutOfMemoryError) {
      message = 'The file is too large to load.';
    }

    // Show Snackbar or Dialog based on severity
    // Using Snackbar for non-critical
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: actionLabel,
            onPressed: onAction ?? () {},
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
