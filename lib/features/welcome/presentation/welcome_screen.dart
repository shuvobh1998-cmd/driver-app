import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/l10n.dart';

/// First-launch intro tour — three glanceable slides that frame the app
/// (drive & earn, stay safe, get paid) before a new user reaches login. Shown
/// once; the `onboarding_seen` flag is set on Get-started / Skip and the
/// router never routes here again.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Slide> _slides(AppLocalizations l10n) => [
    _Slide(
      icon: Icons.directions_car_filled_outlined,
      title: l10n.welcomeDriveTitle,
      body: l10n.welcomeDriveBody,
    ),
    _Slide(
      icon: Icons.shield_outlined,
      title: l10n.welcomeSafetyTitle,
      body: l10n.welcomeSafetyBody,
    ),
    _Slide(
      icon: Icons.account_balance_wallet_outlined,
      title: l10n.welcomeEarnTitle,
      body: l10n.welcomeEarnBody,
    ),
  ];

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go(Routes.login);
  }

  void _next(int count) {
    if (_page >= count - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slides = _slides(l10n);
    final isLast = _page == slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: TextButton(onPressed: _finish, child: Text(l10n.skip)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(slide: slides[i]),
              ),
            ),
            _Dots(count: slides.length, active: _page),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PrimaryButton(
                label: isLast ? l10n.getStarted : l10n.next,
                onPressed: () => _next(slides.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 64, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
