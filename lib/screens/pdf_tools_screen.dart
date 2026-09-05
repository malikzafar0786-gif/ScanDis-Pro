import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_service.dart';
import 'dashboard_screen.dart';

class PdfToolsScreen extends StatefulWidget {
  const PdfToolsScreen({super.key});

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  final List<String> _selectedForMerge = [];
  String? _selectedForSplit;

  bool _busy = false;
  String? _error;
  List<String> _resultPaths = [];

  Future<void> _pickForMerge() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      _selectedForMerge.addAll(
        result.paths.whereType<String>().where((p) => !_selectedForMerge.contains(p)),
      );
      _error = null;
      _resultPaths = [];
    });
  }

  Future<void> _pickForSplit() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.paths.isEmpty) return;
    setState(() {
      _selectedForSplit = result.paths.first;
      _error = null;
      _resultPaths = [];
    });
  }

  Future<void> _runMerge() async {
    setState(() {
      _busy = true;
      _error = null;
      _resultPaths = [];
    });
    try {
      final path = await PdfService.instance.mergePdfs(_selectedForMerge);
      setState(() => _resultPaths = [path]);
    } on PdfServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not merge these PDFs.');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runSplit() async {
    final source = _selectedForSplit;
    if (source == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _resultPaths = [];
    });
    try {
      final paths = await PdfService.instance.splitPdf(source);
      setState(() => _resultPaths = paths);
    } on PdfServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not split this PDF.');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _shareResults() async {
    if (_resultPaths.isEmpty) return;
    await Share.shareXFiles(_resultPaths.map((p) => XFile(p)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScanDisColors.bg,
      appBar: AppBar(title: const Text('Merge & Split PDFs')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'Merge PDFs',
              subtitle: 'Combine two or more local PDFs into one',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._selectedForMerge.map(
                    (p) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_outlined, color: ScanDisColors.accent),
                      title: Text(
                        p.split(Platform.pathSeparator).last,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                        onPressed: () => setState(() => _selectedForMerge.remove(p)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickForMerge,
                        icon: const Icon(Icons.add),
                        label: const Text('Add PDFs'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _selectedForMerge.length >= 2 && !_busy ? _runMerge : null,
                        child: const Text('Merge'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Split PDF',
              subtitle: 'Break a multi-page PDF into single-page files',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedForSplit != null)
                    Text(
                      _selectedForSplit!.split(Platform.pathSeparator).last,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickForSplit,
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Choose PDF'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _selectedForSplit != null && !_busy ? _runSplit : null,
                        child: const Text('Split'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator(color: ScanDisColors.accent)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            if (_resultPaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '${_resultPaths.length} file${_resultPaths.length == 1 ? '' : 's'} created',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _shareResults,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Share result'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScanDisColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScanDisColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
