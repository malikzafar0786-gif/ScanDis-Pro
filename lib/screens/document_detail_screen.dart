import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/document_model.dart';
import '../services/db_service.dart';
import '../services/ocr_tts_service.dart';
import '../services/pdf_service.dart';
import '../widgets/signature_pad.dart';
import 'dashboard_screen.dart';
import 'pdf_tools_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final ScanDocument doc;
  const DocumentDetailScreen({super.key, required this.doc});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _busy = false;
  String? _busyLabel;
  String? _signaturePath;

  Future<void> _run(String label, Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is Exception ? e.toString() : 'Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _playPodcast() async {
    await _run('Extracting text on-device…', () async {
      final text = await OcrTtsService.instance.extractDocumentText(widget.doc);
      if (text.isEmpty) {
        throw Exception('No readable text was found on these pages.');
      }
      await OcrTtsService.instance.playAsPodcast(text);
    });
  }

  Future<void> _addSignature() async {
    final path = await SignaturePad.show(context);
    if (path != null) {
      setState(() => _signaturePath = path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signature captured. It will be applied on export.')),
        );
      }
    }
  }

  Future<void> _exportPdf({bool withPassword = false, bool withWatermark = false}) async {
    await _run('Compiling PDF locally…', () async {
      String? password;
      if (withPassword) {
        password = await _promptForPassword();
        if (password == null || password.isEmpty) return; // cancelled
      }

      final path = await PdfService.instance.compileDocument(
        widget.doc,
        userPassword: password,
        watermarkText: withWatermark ? 'ScanDis — Verified Copy' : null,
        signatureImagePath: _signaturePath,
      );

      widget.doc.pdfPath = path;
      widget.doc.isPasswordProtected = password != null;
      await DbService.instance.saveDocument(widget.doc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved to your local vault.')),
        );
      }
    });
  }

  Future<String?> _promptForPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14202E),
        title: const Text('Set a PDF password', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Enter password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePdf() async {
    final path = widget.doc.pdfPath;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export the PDF first.')),
      );
      return;
    }
    // share_plus hands off to the OS share sheet — still no server round-trip.
    await Share.shareXFiles([XFile(path)], text: widget.doc.title);
  }

  @override
  void dispose() {
    OcrTtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScanDisColors.bg,
      appBar: AppBar(title: Text(widget.doc.title)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Opacity(
          opacity: _busy ? 0.5 : 1,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${widget.doc.pageCount} pages', style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 20),
              _ActionTile(
                icon: Icons.headphones_outlined,
                title: 'Listen as podcast',
                subtitle: 'On-device OCR + text-to-speech',
                onTap: _playPodcast,
              ),
              _ActionTile(
                icon: Icons.draw_outlined,
                title: _signaturePath == null ? 'Add signature / stamp' : 'Signature captured ✓',
                subtitle: 'Canvas signature, applied on export',
                onTap: _addSignature,
              ),
              _ActionTile(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Export as PDF',
                subtitle: 'Compile pages in current order',
                onTap: () => _exportPdf(),
              ),
              _ActionTile(
                icon: Icons.lock_outline,
                title: 'Export password-protected PDF',
                subtitle: 'AES-256 encryption, on-device',
                onTap: () => _exportPdf(withPassword: true),
              ),
              _ActionTile(
                icon: Icons.branding_watermark_outlined,
                title: 'Export with watermark',
                subtitle: '"Verified Copy" diagonal stamp',
                onTap: () => _exportPdf(withWatermark: true),
              ),
              _ActionTile(
                icon: Icons.ios_share_outlined,
                title: 'Share exported PDF',
                subtitle: widget.doc.pdfPath == null ? 'No PDF exported yet' : 'Opens the system share sheet',
                onTap: _sharePdf,
              ),
              _ActionTile(
                icon: Icons.call_merge_outlined,
                title: 'Merge or split PDFs',
                subtitle: 'Combine multiple PDFs or split this one apart',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PdfToolsScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: _busy
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: const Color(0xFF14202E),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ScanDisColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Text(_busyLabel ?? 'Working…', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : null,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
