/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:flutter_butler_client/src/protocol/greeting.dart' as _i3;
import 'package:flutter_butler_client/src/protocol/location.dart' as _i4;
import 'protocol.dart' as _i5;

/// {@category Endpoint}
class EndpointAlert extends _i1.EndpointRef {
  EndpointAlert(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'alert';

  /// Creates a new alert record on the backend.
  /// Returns the ID of the created alert.
  _i2.Future<int> createAlert(
    int deviceId,
    DateTime timestamp,
  ) => caller.callServerEndpoint<int>(
    'alert',
    'createAlert',
    {
      'deviceId': deviceId,
      'timestamp': timestamp,
    },
  );

  /// Marks an existing alert as resolved.
  _i2.Future<void> resolveAlert(int alertId) => caller.callServerEndpoint<void>(
    'alert',
    'resolveAlert',
    {'alertId': alertId},
  );
}

/// This is an example endpoint that returns a greeting message through
/// its [hello] method.
/// {@category Endpoint}
class EndpointGreeting extends _i1.EndpointRef {
  EndpointGreeting(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'greeting';

  /// Returns a personalized greeting message: "Hello {name}".
  _i2.Future<_i3.Greeting> hello(String name) =>
      caller.callServerEndpoint<_i3.Greeting>(
        'greeting',
        'hello',
        {'name': name},
      );
}

/// {@category Endpoint}
class EndpointLocation extends _i1.EndpointRef {
  EndpointLocation(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'location';

  /// Pushes a new GPS coordinate associated with an active alert.
  _i2.Future<void> pushLocation(
    int alertId,
    double lat,
    double lng,
    DateTime timestamp,
  ) => caller.callServerEndpoint<void>(
    'location',
    'pushLocation',
    {
      'alertId': alertId,
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp,
    },
  );

  /// Returns the most recent location for a given alert.
  _i2.Future<_i4.Location?> getLatestLocation(int alertId) =>
      caller.callServerEndpoint<_i4.Location?>(
        'location',
        'getLatestLocation',
        {'alertId': alertId},
      );
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    _i1.AuthenticationKeyManager? authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i5.Protocol(),
         securityContext: securityContext,
         authenticationKeyManager: authenticationKeyManager,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    alert = EndpointAlert(this);
    greeting = EndpointGreeting(this);
    location = EndpointLocation(this);
  }

  late final EndpointAlert alert;

  late final EndpointGreeting greeting;

  late final EndpointLocation location;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'alert': alert,
    'greeting': greeting,
    'location': location,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
