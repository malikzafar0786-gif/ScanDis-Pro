import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _changePin(BuildContext context) async {
    final controller = TextEditingController();
    final newPin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ScanDisColors.bgElevated,
        title: const Text('Set a new vault PIN', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Enter new PIN (4-8 digits)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newPin == null) return;
    if (newPin.length < 4) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN must be at least 4 digits.')),
        );
      }
      return;
    }
    await AuthService.instance.setPin(newPin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault PIN updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScanDisColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change vault PIN',
            subtitle: 'Used as a fallback when biometrics aren\'t available',
            onTap: () => _changePin(context),
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: '100% on-device',
            subtitle: 'No cloud sync, no backend server, no ads, no analytics',
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About ScanDis',
            subtitle: 'Version 1.0.0',
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ScanDisColors.glassFill,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ScanDisColors.glassBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: ScanDisColors.accent),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        onTap: onTap,
      ),
    );
  }
}
