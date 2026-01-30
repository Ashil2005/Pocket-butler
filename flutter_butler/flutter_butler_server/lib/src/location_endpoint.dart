import 'package:serverpod/serverpod.dart';
import 'generated/protocol.dart';

class LocationEndpoint extends Endpoint {
  /// Pushes a new GPS coordinate associated with an active alert.
  Future<void> pushLocation(
    Session session, 
    int alertId, 
    double lat, 
    double lng, 
    DateTime timestamp
  ) async {
    final location = Location(
      alertId: alertId,
      latitude: lat,
      longitude: lng,
      time: timestamp,
    );

    await Location.db.insertRow(session, location);
  }

  /// Returns the most recent location for a given alert.
  Future<Location?> getLatestLocation(Session session, int alertId) async {
    return await Location.db.findFirstRow(
      session,
      where: (t) => t.alertId.equals(alertId),
      orderBy: (t) => t.time,
      orderDescending: true,
    );
  }
}
