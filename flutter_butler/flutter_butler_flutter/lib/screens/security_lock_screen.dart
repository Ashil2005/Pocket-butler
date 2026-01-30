import 'package:flutter/material.dart';
import 'package:flutter_butler_flutter/services/security_service.dart';
import 'package:flutter_butler_flutter/services/alert_manager.dart';

enum LockScreenMode { setup, verify }

/// Screen for PIN setup and verification.
/// This screen is designed to be robber-resistant:
/// - No back navigation.
/// - Mandatory entry to access protected features.
class SecurityLockScreen extends StatefulWidget {
  final LockScreenMode mode;
  final String title;
  final String subtitle;

  const SecurityLockScreen({
    super.key,
    required this.mode,
    this.title = 'Security PIN Required',
    this.subtitle = 'Please enter your 4-6 digit PIN to proceed.',
  });

  @override
  State<SecurityLockScreen> createState() => _SecurityLockScreenState();
}

class _SecurityLockScreenState extends State<SecurityLockScreen> {
  final List<String> _enteredPin = [];
  String? _firstPin; // Used during setup to confirm PIN
  bool _isConfirming = false;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
  }

  void _onNumberPressed(int number) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin.add(number.toString());
        _errorText = '';
      });
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin.removeLast();
        _errorText = '';
      });
    }
  }

  Future<void> _submitPin() async {
    if (_enteredPin.length < 4) {
      setState(() {
        _errorText = 'PIN must be at least 4 digits.';
      });
      return;
    }

    final pinString = _enteredPin.join();

    if (widget.mode == LockScreenMode.setup) {
      if (!_isConfirming) {
        // First step of setup
        setState(() {
          _firstPin = pinString;
          _isConfirming = true;
          _enteredPin.clear();
        });
      } else {
        // Second step: confirmation
        if (pinString == _firstPin) {
          await SecurityService().setPin(pinString);
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _errorText = 'PINs do not match. Try again.';
            _enteredPin.clear();
            _isConfirming = false;
            _firstPin = null;
          });
        }
      }
    } else {
      // Verification mode
      final isValid = await SecurityService().verifyPin(pinString);
      if (isValid) {
        debugPrint('[SECURITY] PIN verified - stopping alarm');
        AlertManager().stopAlert();
        if (mounted) Navigator.pop(context, true);
      } else {
        debugPrint('[SECURITY] Incorrect PIN — alarm continues');
        setState(() {
          _errorText = 'Incorrect PIN. Try again.';
          _enteredPin.clear();
        });
        // Alarm MUST continue - do not stop it
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = _isConfirming ? 'Confirm PIN' : widget.title;
    final displaySubtitle = _isConfirming 
        ? 'Please enter the PIN again to confirm.' 
        : widget.subtitle;

    return PopScope(
      canPop: false, // ROBBER-RESISTANT: Block back button
      child: Scaffold(
        backgroundColor: Colors.black, // High contrast for security
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.lock, size: 80, color: Colors.deepPurpleAccent),
              const SizedBox(height: 24),
              Text(
                displayTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  displaySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                ),
              ),
              const SizedBox(height: 48),

              // PIN Indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? Colors.deepPurpleAccent : Colors.white24,
                      border: Border.all(color: Colors.white38),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),
              if (_errorText.isNotEmpty)
                Text(
                  _errorText,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),

              const Spacer(),

              // Numpad
              _buildNumpad(),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildRow([1, 2, 3]),
          const SizedBox(height: 20),
          _buildRow([4, 5, 6]),
          const SizedBox(height: 20),
          _buildRow([7, 8, 9]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(Icons.backspace, _onBackspace),
              _buildNumberButton(0),
              _buildActionButton(Icons.check_circle, _submitPin, color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<int> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberButton(n)).toList(),
    );
  }

  Widget _buildNumberButton(int n) {
    return InkWell(
      onTap: () => _onNumberPressed(n),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          n.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed, {Color color = Colors.white54}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}
