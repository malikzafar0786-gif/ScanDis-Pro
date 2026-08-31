import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/document_model.dart';
import '../services/db_service.dart';
import 'dashboard_screen.dart';

/// Batch-scan session: launches the on-device ML Kit scanner UI, then lets
/// the user long-press and drag pages into the correct order before saving.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<ScanPage> _pages = [];
  bool _scanning = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Kick off the native scanner sheet as soon as this screen mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchScanner());
  }

  Future<void> _launchScanner() async {
    setState(() {
      _scanning = true;
      _error = null;
    });

    final options = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.full, // on-device edge detection + cleanup filter
      pageLimit: 20,
      isGalleryImport: true,
    );
    final scanner = DocumentScanner(options: options);

    try {
      final result = await scanner.scanDocument();
      final paths = result.images; // List<String> of local file paths, nothing uploaded
      if (paths.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      setState(() {
        for (var i = 0; i < paths.length; i++) {
          _pages.add(ScanPage()
            ..localImagePath = paths[i]
            ..order = _pages.length + i);
        }
      });
    } on PlatformException catch (e) {
      setState(() => _error = 'Scanner error: ${e.message ?? 'unknown failure'}');
    } catch (e) {
      setState(() => _error = 'Could not open the camera scanner.');
    } finally {
      await scanner.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
      for (var i = 0; i < _pages.length; i++) {
        _pages[i].order = i;
      }
    });
  }

  void _removePage(int index) {
    setState(() => _pages.removeAt(index));
  }

  Future<void> _saveDocument() async {
    if (_pages.isEmpty) return;
    setState(() => _saving = true);
    try {
      final doc = ScanDocument()
        ..title = 'Scan ${DateTime.now().toLocal().toString().split('.').first}'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..pages = _pages;
      await DbService.instance.saveDocument(doc);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save this document locally. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScanDisColors.bg,
      appBar: AppBar(
        backgroundColor: ScanDisColors.bg,
        title: const Text('Arrange Pages'),
        actions: [
          IconButton(
            tooltip: 'Add more pages',
            onPressed: _scanning ? null : _launchScanner,
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
      body: _scanning
          ? const Center(child: CircularProgressIndicator(color: ScanDisColors.accent))
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                Expanded(
                  child: _pages.isEmpty
                      ? const Center(
                          child: Text('No pages captured yet.',
                              style: TextStyle(color: Colors.white54)),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(12),
                          child: ReorderableGridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.7,
                            ),
                            itemCount: _pages.length,
                            onReorder: _onReorder,
                            dragStartDelay: const Duration(milliseconds: 250), // long-press feel
                            itemBuilder: (context, index) {
                              final page = _pages[index];
                              return _PageThumb(
                                key: ValueKey(page.localImagePath),
                                page: page,
                                pageNumber: index + 1,
                                onDelete: () => _removePage(index),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_pages.isEmpty || _saving) ? null : _saveDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: ScanDisColors.accent,
                foregroundColor: ScanDisColors.bg,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ScanDisColors.bg),
                    )
                  : Text('Save ${_pages.length} page${_pages.length == 1 ? '' : 's'}'),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageThumb extends StatelessWidget {
  final ScanPage page;
  final int pageNumber;
  final VoidCallback onDelete;

  const _PageThumb({
    super.key,
    required this.page,
    required this.pageNumber,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.white10),
          if (File(page.localImagePath).existsSync())
            Image.file(File(page.localImagePath), fit: BoxFit.cover)
          else
            const Icon(Icons.broken_image_outlined, color: Colors.white24),
          Positioned(
            top: 4,
            left: 4,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Colors.black87,
              child: Text('$pageNumber',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.white),
              onPressed: onDelete,
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
