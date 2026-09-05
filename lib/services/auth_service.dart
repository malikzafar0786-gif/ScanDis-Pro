import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Gates access to the vault. Tries device biometrics/passcode first
/// (via local_auth, which itself falls back to the OS passcode UI); if the
/// device has nothing enrolled, falls back to an app-level PIN whose hash
/// (never the raw PIN) is kept in Keychain/Keystore.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _pinHashKey = 'scandis_vault_pin_hash_v1';

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> get hasPinSet async => (await _storage.read(key: _pinHashKey)) != null;

  Future<bool> get canUseDeviceAuth async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || deviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Triggers the OS biometric/passcode prompt. Returns false (not throws)
  /// on any failure or cancellation so the caller can offer the PIN fallback.
  Future<bool> authenticateWithDevice() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock your ScanDis vault',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow OS passcode as a fallback too
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    final hash = _hash(pin);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinHashKey);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
  }

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();
}
