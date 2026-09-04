import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

/// Bottom-sheet style signature capture. Returns the saved PNG path (with
/// white background stripped to transparency) via [onSaved], or null on cancel.
class SignaturePad extends StatefulWidget {
  final ValueChanged<String?> onSaved;
  const SignaturePad({super.key, required this.onSaved});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14202E),
      builder: (ctx) => SignaturePad(
        onSaved: (path) => Navigator.of(ctx).pop(path),
      ),
    );
  }

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  late final SignatureController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.white,
      exportBackgroundColor: Colors.white, // solid fill we then key out below
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndStamp() async {
    if (_controller.isEmpty) {
      setState(() => _error = 'Draw a signature first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final pngBytes = await _controller.toPngBytes();
      if (pngBytes == null) throw Exception('Could not export the signature image.');

      final transparentBytes = _removeWhiteBackground(pngBytes);

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/signature_${const Uuid().v4()}.png';
      await File(path).writeAsBytes(transparentBytes);

      widget.onSaved(path);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save the signature locally. Please try again.';
      });
    }
  }

  /// Naive chroma-key: any near-white pixel becomes fully transparent so the
  /// stamp overlays cleanly onto a scanned page.
  Uint8List _removeWhiteBackground(Uint8List pngBytes) {
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) return pngBytes;

    final out = img.Image(width: decoded.width, height: decoded.height, numChannels: 4);
    const threshold = 245;

    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final p = decoded.getPixel(x, y);
        final isNearWhite = p.r >= threshold && p.g >= threshold && p.b >= threshold;
        out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), isNearWhite ? 0 : 255);
      }
    }
    return Uint8List.fromList(img.encodePng(out));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sign here', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Signature(controller: _controller, backgroundColor: Colors.transparent),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _controller.clear(),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveAndStamp,
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Stamp Document'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
