import 'package:flutter/material.dart';
import 'package:flutter_butler_flutter/services/app_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Screen for selecting an alarm sound.
/// This is UI-only - no AlertManager modifications.
class AlarmSelectionScreen extends StatefulWidget {
  const AlarmSelectionScreen({super.key});

  @override
  State<AlarmSelectionScreen> createState() => _AlarmSelectionScreenState();
}

class _AlarmSelectionScreenState extends State<AlarmSelectionScreen> {
  String _selectedType = 'default';

  @override
  void initState() {
    super.initState();
    // Load current selection from state
    _selectedType = AppState().alarmSoundType;
  }

  /// Select the default alarm sound.
  Future<void> _selectDefaultAlarm() async {
    setState(() {
      _selectedType = 'default';
    });

    // Clear custom path when switching to default
    await AppState().setAlarmSound('default', path: null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default alarm selected'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Pick a custom sound file from device storage
  Future<void> _pickCustomSound() async {
    // Request storage permissions
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to select custom alarm sounds'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        setState(() {
          _selectedType = 'custom';
        });

        await AppState().setAlarmSound('custom', path: filePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom alarm selected: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Request storage permission for file access
  Future<bool> _requestStoragePermission() async {
    // Android 13+ uses READ_MEDIA_AUDIO
    if (await Permission.audio.isGranted) {
      return true;
    }
    
    // Android 12 and below use READ_EXTERNAL_STORAGE
    if (await Permission.storage.isGranted) {
      return true;
    }

    // Request appropriate permission
    final status = await Permission.audio.request();
    if (status.isGranted) {
      return true;
    }

    // Fallback to storage permission for older Android versions
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Sound'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Choose the alarm sound that will play when theft is detected.',
              style: TextStyle(color: Colors.grey),
            ),
          ),

          // Default Alarm Option
          Card(
            elevation: _selectedType == 'default' ? 4 : 1,
            color: _selectedType == 'default'
                ? Colors.deepPurple.withValues(alpha: 0.1)
                : null,
            child: ListTile(
              leading: Icon(
                Icons.volume_up,
                color: _selectedType == 'default' ? Colors.deepPurple : Colors.grey,
                size: 32,
              ),
              title: const Text(
                'Default Alarm',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Built-in alarm sound'),
              trailing: _selectedType == 'default'
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: _selectDefaultAlarm,
            ),
          ),

          const SizedBox(height: 16),

          // Custom Sound Option (Enabled)
          Card(
            elevation: _selectedType == 'custom' ? 4 : 1,
            color: _selectedType == 'custom'
                ? Colors.deepPurple.withValues(alpha: 0.1)
                : null,
            child: ListTile(
              leading: Icon(
                Icons.audio_file,
                color: _selectedType == 'custom' ? Colors.deepPurple : Colors.grey,
                size: 32,
              ),
              title: const Text(
                'Custom Sound',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: _selectedType == 'custom' && AppState().alarmSoundPath != null
                  ? Text(
                      'Selected: ${AppState().alarmSoundPath!.split('/').last}',
                      style: const TextStyle(color: Colors.green),
                    )
                  : const Text('Choose your own audio file'),
              trailing: _selectedType == 'custom'
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.folder_open, color: Colors.grey),
              onTap: _pickCustomSound,
            ),
          ),

          const SizedBox(height: 32),

          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The alarm will play at maximum volume when theft is detected, '
                    'regardless of your device\'s current volume settings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
