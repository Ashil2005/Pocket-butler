import 'package:serverpod/serverpod.dart';
import 'generated/protocol.dart';

class AlertEndpoint extends Endpoint {
  /// Creates a new alert record on the backend.
  /// Returns the ID of the created alert.
  Future<int> createAlert(Session session, int deviceId, DateTime timestamp) async {
    // In a real app, we'd fetch the userId from the session or device metadata.
    // For this prototype, we use a placeholder userId.
    final alert = Alert(
      userId: 1, 
      deviceId: deviceId,
      time: timestamp,
      alertType: 'theft_suspected',
      isResolved: false,
    );

    await Alert.db.insertRow(session, alert);
    
    // Return the generated ID.
    return alert.id!;
  }

  /// Marks an existing alert as resolved.
  Future<void> resolveAlert(Session session, int alertId) async {
    final alert = await Alert.db.findById(session, alertId);
    if (alert != null) {
      alert.isResolved = true;
      await Alert.db.updateRow(session, alert);
    }
  }
}
