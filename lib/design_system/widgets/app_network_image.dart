import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../spacing.dart';
import 'skeleton_loader.dart';

/// How long a server image may live in the on-disk cache.
///
/// Backend storage is Cloudinary (backend Sprint 11). The two delivery modes
/// need opposite caching:
///
/// * [AppImageCache.public] — avatars and vehicle photos come back as stable
///   `secure_url`s from Cloudinary's public folder. Safe to cache hard.
/// * [AppImageCache.signed] — KYC documents use Cloudinary *authenticated*
///   delivery: the URL carries a signature that expires after **1 hour**.
///   Caching one past its TTL leaves a thumbnail that 401s forever, so these
///   are never written to the cache and are refetched instead.
enum AppImageCache {
  public,

  /// Short-lived signed URL — bypasses the cache entirely.
  signed,
}

/// A cached [ImageProvider] for a **public** server image.
///
/// For the handful of places that need a provider rather than a widget —
/// notably [CircleAvatar.backgroundImage] — so avatars still come from the cache
/// instead of a fresh fetch per build. Do **not** use this for signed KYC URLs:
/// providers give no error hook, so an expired signature would fail silently.
/// Use [AppNetworkImage] there.
ImageProvider appCachedImageProvider(String url) =>
    CachedNetworkImageProvider(url);

/// The single sanctioned way to render a server image.
///
/// Wraps [CachedNetworkImage] with a shimmer placeholder (reusing D8's
/// [SkeletonBox]) and an error state that offers a retry, so an expired signed
/// URL or a flaky network degrades to something tappable instead of a silently
/// broken box.
///
/// Never use a bare `Image.network` for server content — it has no cache, no
/// loading state, and no way to recover from an expired URL.
class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.cache = AppImageCache.public,
    this.onRetry,
    this.semanticLabel,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final AppImageCache cache;

  /// Called when the user taps the error state, *in addition* to the internal
  /// re-fetch. Signed-URL callers pass a provider invalidation here so the
  /// retry fetches a freshly signed URL rather than re-requesting the dead one.
  final VoidCallback? onRetry;

  final String? semanticLabel;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  /// Bumped on retry to force [CachedNetworkImage] to rebuild its request even
  /// when the URL string is unchanged.
  int _attempt = 0;

  void _retry() {
    widget.onRetry?.call();
    setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(AppSpacing.sm);
    final signed = widget.cache == AppImageCache.signed;

    final placeholder = SkeletonBox(
      width: widget.width,
      height: widget.height ?? 16,
      borderRadius: radius,
    );
    final errorTile = _ErrorTile(
      width: widget.width,
      height: widget.height,
      onTap: _retry,
    );
    // Distinct key per attempt so a retry re-issues the request even though the
    // URL string is unchanged.
    final key = ValueKey('${widget.url}#$_attempt');

    // Signed URLs deliberately skip CachedNetworkImage: it always persists to a
    // disk cache, and a KYC signature that outlives its 1h TTL would then be
    // replayed from disk and 401 forever. Image.network keeps nothing on disk.
    Widget image = signed
        ? Image.network(
            widget.url,
            key: key,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
            errorBuilder: (context, _, _) => errorTile,
          )
        : CachedNetworkImage(
            imageUrl: widget.url,
            key: key,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            placeholder: (_, _) => placeholder,
            errorWidget: (context, _, _) => errorTile,
          );

    if (widget.semanticLabel != null) {
      image = Semantics(label: widget.semanticLabel, image: true, child: image);
    }

    return ClipRRect(borderRadius: radius, child: image);
  }
}

/// Tappable "image didn't load" tile. Deliberately quiet — these appear inline
/// in lists next to real content, so it reads as a retry affordance rather than
/// an alarm.
class _ErrorTile extends StatelessWidget {
  const _ErrorTile({this.width, this.height, required this.onTap});

  final double? width;
  final double? height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Tooltip(
        message: 'Tap to retry',
        child: Container(
          width: width,
          height: height,
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(Icons.refresh, size: 20, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
