import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Represents a security-critical event logged by the system.
class SecurityEvent {
  final DateTime timestamp;
  final String eventType;
  final String details;

  SecurityEvent({
    required this.timestamp,
    required this.eventType,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
    't': timestamp.toIso8601String(),
    'e': eventType,
    'd': details,
  };

  factory SecurityEvent.fromJson(Map<String, dynamic> json) => SecurityEvent(
    timestamp: DateTime.parse(json['t']),
    eventType: json['e'],
    details: json['d'],
  );
}

/// Service to securely log security events locally for audit and analysis.
class SecurityEventLogger {
  static final SecurityEventLogger _instance = SecurityEventLogger._internal();
  factory SecurityEventLogger() => _instance;
  SecurityEventLogger._internal();

  static const String _logKey = 'security_audit_logs';
  static const int _maxLogs = 100;

  /// Logs a new security event.
  Future<void> logEvent(String eventType, String details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList(_logKey) ?? [];
      
      final event = SecurityEvent(
        timestamp: DateTime.now(),
        eventType: eventType,
        details: details,
      );

      logs.insert(0, jsonEncode(event.toJson()));
      
      // Keep only the most recent logs to save space
      if (logs.length > _maxLogs) {
        logs.removeRange(_maxLogs, logs.length);
      }

      await prefs.setStringList(_logKey, logs);
      debugPrint('SECURITY LOG: [$eventType] $details');
    } catch (e) {
      debugPrint('Error logging security event: $e');
    }
  }

  /// Retrieves all logged security events.
  Future<List<SecurityEvent>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList(_logKey) ?? [];
      return logs.map((l) => SecurityEvent.fromJson(jsonDecode(l))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Clears all security logs.
  Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
  }
}
