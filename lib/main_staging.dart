import 'app/di/bootstrap.dart';
import 'core/config/app_config.dart';

/// Staging entrypoint. Run with:
///   flutter run -t lib/main_staging.dart --dart-define=ENV=staging
void main() => bootstrap(AppFlavor.staging);
