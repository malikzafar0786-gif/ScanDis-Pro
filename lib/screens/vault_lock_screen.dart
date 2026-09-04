import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';
import 'dashboard_screen.dart'; // for ScanDisColors

class VaultLockScreen extends StatefulWidget {
  const VaultLockScreen({super.key});

  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen> {
  final _pinController = TextEditingController();
  bool _checkingDeviceAuth = true;
  bool _unlocked = false;
  bool _needsPinSetup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final deviceAuthAvailable = await AuthService.instance.canUseDeviceAuth;
    final pinAlreadySet = await AuthService.instance.hasPinSet;

    if (deviceAuthAvailable) {
      final ok = await AuthService.instance.authenticateWithDevice();
      if (ok) {
        setState(() => _unlocked = true);
        return;
      }
    }

    // No device auth, or the user cancelled/failed it — offer the PIN path.
    setState(() {
      _checkingDeviceAuth = false;
      _needsPinSetup = !pinAlreadySet;
    });
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }

    if (_needsPinSetup) {
      await AuthService.instance.setPin(pin);
      setState(() => _unlocked = true);
      return;
    }

    final ok = await AuthService.instance.verifyPin(pin);
    if (ok) {
      setState(() => _unlocked = true);
    } else {
      setState(() {
        _error = 'Incorrect PIN.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const AppShell();

    return Scaffold(
      backgroundColor: ScanDisColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _checkingDeviceAuth
                ? const CircularProgressIndicator(color: ScanDisColors.accent)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: ScanDisColors.accent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _needsPinSetup ? 'Set a vault PIN' : 'Enter your PIN',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your documents stay encrypted on this device only.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 8,
                        style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 8),
                        decoration: const InputDecoration(counterText: '', hintText: '••••'),
                        onSubmitted: (_) => _submitPin(),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitPin,
                          child: Text(_needsPinSetup ? 'Set PIN' : 'Unlock'),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
