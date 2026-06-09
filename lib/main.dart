import 'app/di/bootstrap.dart';
import 'core/config/app_config.dart';

/// Convenience default entrypoint (`flutter run` with no `-t`) — boots the dev
/// flavor. Prefer the explicit `main_dev` / `main_staging` / `main_prod`
/// entrypoints for real builds.
void main() => bootstrap(AppFlavor.dev);
