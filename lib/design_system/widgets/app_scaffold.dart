import 'package:flutter/material.dart';

import '../spacing.dart';

/// Standard page chrome. Every screen builds on this instead of a bare
/// [Scaffold] so padding, app-bar style and safe-area handling stay uniform.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.bottomBar,
    this.padded = true,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;

  /// A persistent bottom action area (e.g. the primary button).
  final Widget? bottomBar;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions),
      body: SafeArea(
        child: Padding(
          padding: padded ? AppSpacing.screen : EdgeInsets.zero,
          child: body,
        ),
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              child: Padding(padding: AppSpacing.screen, child: bottomBar),
            ),
    );
  }
}
