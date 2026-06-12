import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/api_envelope.dart';
import '../../auth/data/models/user_profile.dart';
import 'models/driver_profile.dart';
import 'models/kyc_document.dart';
import 'models/kyc_status_summary.dart';
import 'models/onboarding_enums.dart';
import 'models/vehicle.dart';

/// Transport over the `/users/me/upgrade-to-driver` and `/drivers/me/*`
/// onboarding endpoints (driver profile, KYC documents, vehicles). Returns
/// typed models; error normalization is handled by the interceptor stack.
class DriverApi {
  DriverApi(this._dio);

  final Dio _dio;

  /// Adds the DRIVER role to the signed-in user. Returns the updated profile.
  Future<UserProfile> upgradeToDriver() async {
    final res = await _dio.post<dynamic>('/users/me/upgrade-to-driver');
    return res.unwrap(UserProfile.fromJson);
  }

  // ── Driver profile ──────────────────────────────────────────────────────
  Future<DriverProfile> createProfile({
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    final res = await _dio.post<dynamic>(
      '/drivers/me/profile',
      data: {
        'emergencyContactName': ?emergencyContactName,
        'emergencyContactPhone': ?emergencyContactPhone,
      },
    );
    return res.unwrap(DriverProfile.fromJson);
  }

  Future<DriverProfile> getProfile() async {
    final res = await _dio.get<dynamic>('/drivers/me/profile');
    return res.unwrap(DriverProfile.fromJson);
  }

  Future<DriverProfile> updateProfile(Map<String, dynamic> patch) async {
    final res = await _dio.patch<dynamic>('/drivers/me/profile', data: patch);
    return res.unwrap(DriverProfile.fromJson);
  }

  // ── KYC documents ─────────────────────────────────────────────────────────
  /// Uploads (or replaces) a KYC document. Sends the file under the multipart
  /// `file` field with the `docType` (and optional `docNumber`). [onProgress]
  /// reports 0.0–1.0 while the bytes upload.
  Future<KycDocument> uploadDocument({
    required KycDocType docType,
    required String filePath,
    String? docNumber,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'docType': docType.wireValue,
      if (docNumber != null && docNumber.trim().isNotEmpty)
        'docNumber': docNumber.trim(),
      'file': await MultipartFile.fromFile(
        filePath,
        filename: p.basename(filePath),
      ),
    });
    final res = await _dio.post<dynamic>(
      '/drivers/me/kyc/documents',
      data: form,
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
    return res.unwrap(KycDocument.fromJson);
  }

  Future<List<KycDocument>> listDocuments() async {
    final res = await _dio.get<dynamic>('/drivers/me/kyc/documents');
    return res.unwrapList(KycDocument.fromJson);
  }

  Future<void> deleteDocument(String id) =>
      _dio.delete<dynamic>('/drivers/me/kyc/documents/$id');

  Future<KycStatusSummary> getKycStatus() async {
    final res = await _dio.get<dynamic>('/drivers/me/kyc/status');
    return res.unwrap(KycStatusSummary.fromJson);
  }

  // ── Vehicles ──────────────────────────────────────────────────────────────
  Future<Vehicle> createVehicle({
    required VehicleType vehicleType,
    required String registrationNumber,
    required int seatCount,
    String? make,
    String? model,
    int? year,
    String? color,
  }) async {
    final res = await _dio.post<dynamic>(
      '/drivers/me/vehicles',
      data: {
        'vehicleType': vehicleType.wireValue,
        'registrationNumber': registrationNumber,
        'seatCount': seatCount,
        if (make != null && make.isNotEmpty) 'make': make,
        if (model != null && model.isNotEmpty) 'model': model,
        'year': ?year,
        if (color != null && color.isNotEmpty) 'color': color,
      },
    );
    return res.unwrap(Vehicle.fromJson);
  }

  Future<List<Vehicle>> listVehicles() async {
    final res = await _dio.get<dynamic>('/drivers/me/vehicles');
    return res.unwrapList(Vehicle.fromJson);
  }

  Future<Vehicle> updateVehicle(String id, Map<String, dynamic> patch) async {
    final res = await _dio.patch<dynamic>(
      '/drivers/me/vehicles/$id',
      data: patch,
    );
    return res.unwrap(Vehicle.fromJson);
  }

  Future<void> deleteVehicle(String id) =>
      _dio.delete<dynamic>('/drivers/me/vehicles/$id');

  Future<Vehicle> uploadVehiclePhoto({
    required String id,
    required String filePath,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        filePath,
        filename: p.basename(filePath),
      ),
    });
    final res = await _dio.post<dynamic>(
      '/drivers/me/vehicles/$id/photo',
      data: form,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
    return res.unwrap(Vehicle.fromJson);
  }
}
