import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Service responsible for detecting sudden device movement using the accelerometer.
class MotionService {
  static final MotionService _instance = MotionService._internal();
  factory MotionService() => _instance;
  MotionService._internal();

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final _movementController = StreamController<bool>.broadcast();
  
  /// Stream that emits true when sudden movement (a snatch) is detected.
  Stream<bool> get movementDetectedStream => _movementController.stream;

  /// The threshold for considering acceleration as "sudden movement".
  /// Value in m/s^2.
  double threshold = 12.0; 

  /// Starts listening to accelerometer data.
  void startListening() {
    _subscription?.cancel();
    _subscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      // Calculate Euclidean norm (magnitude) of the acceleration vector.
      final magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      
      if (magnitude > threshold) {
        _movementController.add(true);
      }
    });
  }

  /// Stops listening to accelerometer data.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopListening();
    _movementController.close();
  }
}
