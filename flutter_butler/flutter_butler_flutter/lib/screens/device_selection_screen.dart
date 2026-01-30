import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_butler_flutter/services/app_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

/// Screen for scanning and selecting a trusted Bluetooth device.
/// This is UI-only - no connection or monitoring logic.
class DeviceSelectionScreen extends StatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  // Lists of devices
  List<BluetoothDevice> _connectedDevices = [];
  List<BluetoothDevice> _bondedDevices = [];
  
  String? _selectedDeviceId;
  
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  Timer? _refreshTimer;
  
  bool _permissionsGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDeviceId = AppState().selectedDeviceId;
    
    // Listen to adapter state
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _adapterState = state;
        });
      }
    });

    // Start periodic refresh of devices
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchDevices());

    // Initial permission check and device fetch
    _checkPermissionsAndFetchDevices();
  }

  Future<void> _checkPermissionsAndFetchDevices() async {
    setState(() => _isLoading = true);
    
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (mounted) {
      setState(() {
        _permissionsGranted = statuses.values.every((s) => s.isGranted);
      });

      if (_permissionsGranted) {
        await _fetchDevices();
      }
      
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDevices() async {
    try {
      // Fetch bonded devices (Android specific)
      if (Platform.isAndroid) {
        final bonded = await FlutterBluePlus.bondedDevices;
        if (mounted) {
          setState(() {
            _bondedDevices = bonded;
          });
        }
      }
      
      // Also trigger a refresh of connected devices
      final connected = await FlutterBluePlus.systemDevices([]);
      if (mounted) {
        setState(() {
          _connectedDevices = connected;
        });
      }
    } catch (e) {
      debugPrint('Error fetching devices: $e');
    }
  }


  Future<void> _requestPermissions() async {
    await _checkPermissionsAndFetchDevices();
    if (!_permissionsGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth and Location permissions are required to scan for devices.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Combined list of connected and bonded devices, with duplicates removed.
  List<BluetoothDevice> get _allDevices {
    final Map<String, BluetoothDevice> deviceMap = {};
    
    // Add bonded devices first (will be overridden by connected if both apply)
    for (var device in _bondedDevices) {
      deviceMap[device.remoteId.str] = device;
    }
    
    // Add connected devices (takes precedence)
    for (var device in _connectedDevices) {
      deviceMap[device.remoteId.str] = device;
    }
    
    final list = deviceMap.values.toList();
    
    // Sort: Connected first, then alphabetically
    list.sort((a, b) {
      final aConnected = _connectedDevices.any((d) => d.remoteId == a.remoteId);
      final bConnected = _connectedDevices.any((d) => d.remoteId == b.remoteId);
      
      if (aConnected && !bConnected) return -1;
      if (!aConnected && bConnected) return 1;
      
      return a.platformName.compareTo(b.platformName);
    });
    
    return list;
  }

  /// Select a device and save to AppState with trust confirmation.
  Future<void> _selectDevice(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    final deviceName = device.platformName.isEmpty 
        ? 'Unknown Device' 
        : device.platformName;

    // Show trust confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trust this device?'),
        content: Text(
          'This device ($deviceName) will be used to guard your phone.\n\n'
          'If it disconnects or moves away while armed, an alarm will trigger.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('TRUST DEVICE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _selectedDeviceId = deviceId;
    });

    // Save to persistent state
    await AppState().setSelectedDevice(deviceName, deviceId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trusted: $deviceName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Return to previous screen after a brief delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Devices'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _permissionsGranted ? _fetchDevices : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Permissions and Adapter Status
          if (!_permissionsGranted)
            _buildPermissionWarning()
          else if (_adapterState != BluetoothAdapterState.on)
            _buildBluetoothDisabledWarning(),

          const Divider(height: 1),

          // Device list
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _allDevices.isEmpty
                    ? _buildEmptyState()
                    : _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Column(
        children: [
          const Text(
            'Bluetooth permissions are required to find your devices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _requestPermissions,
            icon: const Icon(Icons.security),
            label: const Text('Grant Permissions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothDisabledWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.red.withValues(alpha: 0.1),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bluetooth is disabled. Please enable it in Settings.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            !_permissionsGranted ? Icons.security_outlined : Icons.bluetooth_searching,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            !_permissionsGranted 
                ? 'Permissions missing' 
                : 'No paired devices found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Pocket Butler works with your existing connected devices, like headphones or a watch.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          if (_permissionsGranted)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: TextButton.icon(
                onPressed: _fetchDevices,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh List'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      itemCount: _allDevices.length,
      itemBuilder: (context, index) {
        final device = _allDevices[index];
        final deviceId = device.remoteId.str;
        final deviceName = device.platformName.isEmpty ? 'Unknown Device' : device.platformName;
        final isSelected = deviceId == _selectedDeviceId;
        final isConnected = _connectedDevices.any((d) => d.remoteId == device.remoteId);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Colors.deepPurple.withValues(alpha: 0.1) : null,
          child: ListTile(
            leading: Stack(
              children: [
                Icon(
                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                  color: isSelected ? Colors.deepPurple : Colors.grey,
                  size: 32,
                ),
                if (isConnected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              deviceName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              deviceId,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: _buildStatusBadge(isConnected, isSelected),
            onTap: () => _selectDevice(device),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool isConnected, bool isSelected) {
    if (isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
        ),
        child: const Text(
          'CONNECTED',
          style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
        ),
        child: const Text(
          'PAIRED',
          style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }
  }
}
