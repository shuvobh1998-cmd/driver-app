import 'package:dio/dio.dart';
import 'package:driver_app/features/onboarding_kyc/data/driver_api.dart';
import 'package:driver_app/features/onboarding_kyc/data/models/onboarding_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canned-response adapter so the API parses without a network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

DriverApi _apiWith(String body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _StubAdapter(body);
  return DriverApi(dio);
}

void main() {
  test('getKycStatus maps enums and the required/missing lists', () async {
    final api = _apiWith(
      '{"success":true,"data":{'
      '"status":"IN_REVIEW",'
      '"uploaded":["AADHAAR"],'
      '"required":["AADHAAR","DL"],'
      '"missing":["DL"],'
      '"rejectedReason":null,"approvedAt":null}}',
    );

    final status = await api.getKycStatus();

    expect(status.status, KycStatus.inReview);
    expect(status.uploaded, [KycDocType.aadhaar]);
    expect(status.requiredDocs, [KycDocType.aadhaar, KycDocType.dl]);
    expect(status.missing, [KycDocType.dl]);
    expect(status.allRequiredUploaded, isFalse);
  });

  test('listVehicles parses type, status and nullable fields', () async {
    final api = _apiWith(
      '{"success":true,"data":[{'
      '"publicId":"veh_1","vehicleType":"CAR","registrationNumber":"WB12AB1234",'
      '"seatCount":4,"make":"Maruti","model":null,"year":2022,"color":null,'
      '"photoUrl":null,"status":"PENDING_APPROVAL","rejectedReason":null,'
      '"approvedAt":null,"createdAt":"2026-05-29T18:00:00.000Z",'
      '"updatedAt":"2026-05-29T18:00:00.000Z"}]}',
    );

    final vehicles = await api.listVehicles();

    expect(vehicles, hasLength(1));
    final v = vehicles.single;
    expect(v.vehicleType, VehicleType.car);
    expect(v.status, VehicleStatus.pendingApproval);
    expect(v.seatCount, 4);
    expect(v.model, isNull);
    expect(v.title, 'Maruti');
  });

  test('getKycStatus tolerates absent list fields', () async {
    final api = _apiWith('{"success":true,"data":{"status":"PENDING"}}');

    final status = await api.getKycStatus();

    expect(status.status, KycStatus.pending);
    expect(status.uploaded, isEmpty);
    expect(status.missing, isEmpty);
  });
}
