import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'scan_screen.dart';
import 'pdf_tools_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _dashboardKey = GlobalKey<DashboardBodyState>();

  Future<void> _openScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    _dashboardKey.currentState?.reload();
  }

  Future<void> _openTools() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PdfToolsScreen()),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScanDisColors.bg,
      body: SafeArea(child: DashboardBody(key: _dashboardKey)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _ScanFab(onTap: _openScan),
      bottomNavigationBar: _BottomBar(onToolsTap: _openTools, onSettingsTap: _openSettings),
    );
  }
}

class _ScanFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [ScanDisColors.accent, ScanDisColors.accentDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ScanDisColors.accent.withOpacity(0.55),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: ScanDisColors.bg, width: 4),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Icon(Icons.document_scanner_outlined, color: ScanDisColors.bg, size: 30),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onToolsTap;
  final VoidCallback onSettingsTap;
  const _BottomBar({required this.onToolsTap, required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: ScanDisColors.bgElevated,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      height: 66,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(icon: Icons.grid_view_rounded, label: 'Vault', selected: true, onTap: () {}),
          _NavIcon(icon: Icons.build_outlined, label: 'Tools', selected: false, onTap: onToolsTap),
          const SizedBox(width: 56), // reserved space under the notch/FAB
          _NavIcon(icon: Icons.settings_outlined, label: 'Settings', selected: false, onTap: onSettingsTap),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? ScanDisColors.accent : Colors.white54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
