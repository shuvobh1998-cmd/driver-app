import 'package:driver_app/app/app.dart';
import 'package:driver_app/core/config/app_config.dart';
import 'package:driver_app/core/config/config_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the placeholder home screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(AppFlavor.dev),
          ),
        ],
        child: const DriverApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Themed placeholder is on screen, with the active flavor badge.
    expect(find.text('Scaffold ready'), findsOneWidget);
    expect(find.text('DEV'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
