import 'package:flutter/material.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // TODO: Implement Bluetooth device picker
  // TODO: Implement Sensitivity settings
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Setup'),
      ),
      body: const Center(
        child: Text('Setup Screen Placeholder'),
      ),
    );
  }
}
