import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/error/app_failure.dart';
import '../../core/error/error_messages.dart';
import 'image_pick.dart';

/// Resolves any caught error into a user-facing message: an [AppFailure] is
/// already mapped from its `error.code`; the [ErrorInterceptor] hands callers a
/// [DioException] whose `error` is that [AppFailure], so unwrap it; anything
/// else falls back to the generic message (we never surface raw exception text).
String messageForError(Object error) {
  // Client-side upload guard — never reaches the server, so it has no
  // `error.code` to map. Names the actual size so the driver knows how far over
  // they are.
  if (error is FileTooLargeException) {
    return 'That file is ${error.sizeMb}MB — the limit is 5MB. '
        'Try a photo instead of a scan, or crop it tighter.';
  }
  // The saved draft is gone (temp dir reclaimed by the OS) — retrying the same
  // path can't work, so ask for a fresh capture.
  if (error is FileMissingException) {
    return 'That file is no longer on your device. Please capture it again.';
  }
  final failure = error is AppFailure
      ? error
      : (error is DioException && error.error is AppFailure
            ? error.error as AppFailure
            : null);
  return failure?.message ?? errorMessageFor(AppFailure.unknownCode);
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
