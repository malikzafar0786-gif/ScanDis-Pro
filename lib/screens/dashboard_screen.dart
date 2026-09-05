import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../services/db_service.dart';
import 'document_detail_screen.dart';

class ScanDisColors {
  static const bg = Color(0xFF0B131F);
  static const bgElevated = Color(0xFF101C2B);
  static const accent = Color(0xFF00F2FE);
  static const accentDeep = Color(0xFF00B4D8);
  static const glassFill = Color(0x1AFFFFFF); // white @ 10% for frosted panels
  static const glassBorder = Color(0x33FFFFFF);
}

/// The gallery grid + search bar. No Scaffold of its own — it's embedded
/// inside [AppShell] so the bottom nav / scan FAB can sit above it.
class DashboardBody extends StatefulWidget {
  const DashboardBody({super.key});

  @override
  State<DashboardBody> createState() => DashboardBodyState();
}

class DashboardBodyState extends State<DashboardBody> {
  List<ScanDocument> _allDocs = [];
  List<ScanDocument> _filteredDocs = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    reload();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Public so AppShell can trigger a refresh after a scan/edit session.
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await DbService.instance.getAllDocuments();
      if (!mounted) return;
      setState(() {
        _allDocs = docs;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your local vault. Please try again.';
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredDocs = query.isEmpty
          ? _allDocs
          : _allDocs.where((d) => d.title.toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        const SizedBox(height: 4),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'My Vault',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              const _GlassChip(icon: Icons.shield_outlined, label: '100% On-Device'),
              const SizedBox(width: 8),
              _GlassChip(icon: Icons.description_outlined, label: '${_allDocs.length} docs'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: ScanDisColors.glassFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ScanDisColors.glassBorder),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search your vault',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: ScanDisColors.accent),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                        onPressed: () => _searchController.clear(),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ScanDisColors.accent));
    }
    if (_error != null) {
      return _CenteredMessage(text: _error!, onRetry: reload);
    }
    if (_allDocs.isEmpty) {
      return const _CenteredMessage(
        text: 'No documents yet.\nTap the scan button below to create your first one — everything stays on this device.',
      );
    }
    if (_filteredDocs.isEmpty) {
      return const _CenteredMessage(text: 'No documents match your search.');
    }

    return RefreshIndicator(
      color: ScanDisColors.accent,
      backgroundColor: ScanDisColors.bgElevated,
      onRefresh: reload,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: _filteredDocs.length,
        itemBuilder: (context, index) {
          final doc = _filteredDocs[index];
          return GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DocumentDetailScreen(doc: doc)),
              );
              reload(); // refresh in case pdfPath/title changed
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
            boxShadow: [
              BoxShadow(
                color: ScanDisColors.accent.withOpacity(0.06),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
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
                      colors: [Colors.transparent, Colors.black.withOpacity(0.78)],
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
        mainAxisSize: MainAxisSize.min,
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
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, height: 1.5)),
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
