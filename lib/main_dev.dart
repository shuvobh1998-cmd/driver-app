import 'app/di/bootstrap.dart';
import 'core/config/app_config.dart';

/// Dev entrypoint. Run with:
///   flutter run -t lib/main_dev.dart --dart-define=ENV=dev
void main() => bootstrap(AppFlavor.dev);
