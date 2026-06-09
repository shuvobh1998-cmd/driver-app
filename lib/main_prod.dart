import 'app/di/bootstrap.dart';
import 'core/config/app_config.dart';

/// Production entrypoint. Run with:
///   flutter run -t lib/main_prod.dart --dart-define=ENV=prod
void main() => bootstrap(AppFlavor.prod);
