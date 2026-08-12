import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AppNetworkImage cache mode', () {
    testWidgets('a public URL goes through the disk cache', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppNetworkImage(
            url: 'https://res.cloudinary.com/demo/public/car.jpg',
            width: 64,
            height: 64,
          ),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('a signed URL bypasses the disk cache', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppNetworkImage(
            url: 'https://res.cloudinary.com/demo/authenticated/kyc.jpg?sig=x',
            width: 56,
            height: 56,
            cache: AppImageCache.signed,
          ),
        ),
      );

      // CachedNetworkImage always persists to disk, which would replay an
      // expired 1h signature forever — so signed URLs must not use it.
      expect(find.byType(CachedNetworkImage), findsNothing);

      // ...and the plain Image it falls back to must carry no disk cache.
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
    });
  });

  testWidgets('a failed load shows a retry affordance that fires onRetry', (
    tester,
  ) async {
    var refreshes = 0;

    await tester.pumpWidget(
      _host(
        AppNetworkImage(
          url: 'https://invalid.invalid/expired.jpg',
          width: 56,
          height: 56,
          cache: AppImageCache.signed,
          onRetry: () => refreshes++,
        ),
      ),
    );
    // Let the (failing) image request settle into the error builder.
    await tester.pump(const Duration(seconds: 1));

    final retry = find.byIcon(Icons.refresh);
    expect(
      retry,
      findsOneWidget,
      reason: 'an expired signed URL must degrade to a tappable retry',
    );

    await tester.tap(retry);
    await tester.pump();

    // The caller's invalidation ran, so the next attempt uses a fresh URL.
    expect(refreshes, 1);
  });

  testWidgets('a public image exposes its semantic label', (tester) async {
    await tester.pumpWidget(
      _host(
        const AppNetworkImage(
          url: 'https://res.cloudinary.com/demo/public/car.jpg',
          width: 64,
          height: 64,
          semanticLabel: 'Vehicle photo',
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Vehicle photo')),
      isNotNull,
    );
  });
}
