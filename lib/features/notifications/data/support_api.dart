import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import 'models/support.dart';

/// Transport over the support-ticket endpoints (D7).
class SupportApi {
  SupportApi(this._dio);

  final Dio _dio;

  /// Opens a support ticket.
  Future<Ticket> createTicket({
    required TicketCategory category,
    required String subject,
    required String description,
    String? tripId,
  }) async {
    final res = await _dio.post<dynamic>(
      '/support/tickets',
      data: {
        'category': category.wireValue,
        'subject': subject,
        'description': description,
        'tripId': ?tripId,
      },
    );
    return res.unwrap(Ticket.fromJson);
  }

  /// Reports a lost item (a LOST_ITEM ticket).
  Future<Ticket> reportLostItem({
    required String subject,
    required String description,
    String? tripId,
  }) async {
    final res = await _dio.post<dynamic>(
      '/support/lost-item',
      data: {'subject': subject, 'description': description, 'tripId': ?tripId},
    );
    return res.unwrap(Ticket.fromJson);
  }

  /// My tickets, newest first, optionally filtered by status.
  Future<List<Ticket>> myTickets({
    int page = 1,
    int pageSize = 20,
    TicketStatus? status,
  }) async {
    final res = await _dio.get<dynamic>(
      '/support/tickets/me',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'status': _statusWire(status),
      },
    );
    return res.unwrapList(Ticket.fromJson);
  }

  /// Ticket detail with its message thread.
  Future<Ticket> ticket(String id) async {
    final res = await _dio.get<dynamic>('/support/tickets/$id');
    return res.unwrap(Ticket.fromJson);
  }

  /// Adds a reply to a ticket; returns the updated ticket (with the new message).
  Future<Ticket> reply(String id, String body) async {
    final res = await _dio.post<dynamic>(
      '/support/tickets/$id/messages',
      data: {'body': body},
    );
    return res.unwrap(Ticket.fromJson);
  }

  static String _statusWire(TicketStatus status) => switch (status) {
    TicketStatus.open => 'OPEN',
    TicketStatus.pending => 'PENDING',
    TicketStatus.resolved => 'RESOLVED',
    TicketStatus.closed => 'CLOSED',
    TicketStatus.unknown => 'OPEN',
  };
}
