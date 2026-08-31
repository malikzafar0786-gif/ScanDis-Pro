import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../services/db_service.dart';
import 'scan_screen.dart';
import 'document_detail_screen.dart';

class ScanDisColors {
  static const bg = Color(0xFF0B131F);
  static const accent = Color(0xFF00F2FE);
  static const glassFill = Color(0x1AFFFFFF); // white @ 10% for frosted panels
  static const glassBorder = Color(0x33FFFFFF);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ScanDocument> _docs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await DbService.instance.getAllDocuments();
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your local vault. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScanDisColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ScanDisColors.accent,
        foregroundColor: ScanDisColors.bg,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan', style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScanScreen()),
          );
          _load(); // refresh grid after a scan session completes
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'My Vault',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          _GlassChip(icon: Icons.lock_outline, label: '${_docs.length} docs'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ScanDisColors.accent),
      );
    }
    if (_error != null) {
      return _CenteredMessage(text: _error!, onRetry: _load);
    }
    if (_docs.isEmpty) {
      return const _CenteredMessage(
        text: 'No documents yet.\nTap Scan to create your first one — everything stays on this device.',
      );
    }

    return RefreshIndicator(
      color: ScanDisColors.accent,
      backgroundColor: const Color(0xFF14202E),
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: _docs.length,
        itemBuilder: (context, index) {
          final doc = _docs[index];
          return GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DocumentDetailScreen(doc: doc)),
              );
              _load(); // refresh in case pdfPath/title changed
            },
            child: _DocumentCard(doc: doc),
          );
        },
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final ScanDocument doc;
  const _DocumentCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final thumbPath = doc.pages.isNotEmpty ? doc.pages.first.localImagePath : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: ScanDisColors.glassFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ScanDisColors.glassBorder),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: thumbPath != null && File(thumbPath).existsSync()
                    ? Image.file(File(thumbPath), fit: BoxFit.cover)
                    : Container(
                        color: Colors.white.withOpacity(0.03),
                        child: const Icon(Icons.description_outlined,
                            color: Colors.white24, size: 40),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              if (doc.isInSecureVault)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: _GlassBadge(icon: Icons.shield_outlined),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GlassChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ScanDisColors.glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ScanDisColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: ScanDisColors.accent, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final IconData icon;
  const _GlassBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: ScanDisColors.accent.withOpacity(0.6)),
      ),
      child: Icon(icon, color: ScanDisColors.accent, size: 14),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _CenteredMessage({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
