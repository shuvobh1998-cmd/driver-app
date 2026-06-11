import 'package:flutter/material.dart';

import '../../core/error/app_failure.dart';
import '../../core/error/error_messages.dart';

/// Resolves any caught error into a user-facing message: an [AppFailure] is
/// already mapped from its `error.code`; anything else falls back to the
/// generic message (we never surface raw exception text).
String messageForError(Object error) {
  if (error is AppFailure) return error.message;
  return errorMessageFor(AppFailure.unknownCode);
}

extension FailureSnackBar on BuildContext {
  /// Shows a dismissible error snackbar for a caught failure.
  void showErrorSnack(Object error) {
    final messenger = ScaffoldMessenger.of(this);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(messageForError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void showInfoSnack(String message) {
    final messenger = ScaffoldMessenger.of(this);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}
