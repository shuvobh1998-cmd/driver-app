import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core_providers.dart';
import '../../../core/network/network_providers.dart';
import '../../../shared/utils/image_pick.dart';
import 'driver_api.dart';
import 'kyc_draft_store.dart';
import 'models/driver_profile.dart';
import 'models/kyc_document.dart';
import 'models/kyc_status_summary.dart';
import 'models/vehicle.dart';

final driverApiProvider = Provider<DriverApi>(
  (ref) => DriverApi(ref.watch(apiClientProvider).dio),
);

final kycDraftStoreProvider = Provider<KycDraftStore>(
  (ref) => KycDraftStore(ref.watch(appDatabaseProvider)),
);

/// The shared image picker + compressor used by KYC and vehicle uploads.
final imagePickServiceProvider = Provider<ImagePickService>(
  (ref) => ImagePickService(),
);

/// The driver profile (`/drivers/me/profile`). Invalidate after creating the
/// profile or editing the emergency contact.
final driverProfileProvider = FutureProvider<DriverProfile>(
  (ref) => ref.watch(driverApiProvider).getProfile(),
);

/// The overall KYC status summary. Invalidate after an upload/delete.
final kycStatusProvider = FutureProvider<KycStatusSummary>(
  (ref) => ref.watch(driverApiProvider).getKycStatus(),
);

/// The driver's uploaded KYC documents. Invalidate after an upload/delete.
final kycDocumentsProvider = FutureProvider<List<KycDocument>>(
  (ref) => ref.watch(driverApiProvider).listDocuments(),
);

/// The driver's registered vehicles (excludes soft-deleted).
final vehiclesProvider = FutureProvider<List<Vehicle>>(
  (ref) => ref.watch(driverApiProvider).listVehicles(),
);
