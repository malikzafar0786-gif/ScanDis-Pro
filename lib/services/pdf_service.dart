import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';

class PdfServiceException implements Exception {
  final String message;
  PdfServiceException(this.message);
  @override
  String toString() => message;
}

class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  /// Compiles [doc]'s pages (already in final drag-and-drop order) into a
  /// single PDF, optionally watermarking and/or password-protecting it.
  /// Returns the local file path of the generated PDF.
  Future<String> compileDocument(
    ScanDocument doc, {
    String? userPassword,
    String? ownerPassword,
    String? watermarkText,
    String? signatureImagePath,
    bool signatureOnLastPageOnly = true,
  }) async {
    if (doc.pages.isEmpty) {
      throw PdfServiceException('This document has no pages to export.');
    }

    final sortedPages = [...doc.pages]..sort((a, b) => a.order.compareTo(b.order));
    final document = PdfDocument();

    PdfBitmap? signatureBitmap;
    if (signatureImagePath != null) {
      final sigFile = File(signatureImagePath);
      if (await sigFile.exists()) {
        signatureBitmap = PdfBitmap(await sigFile.readAsBytes());
      }
    }

    try {
      for (var i = 0; i < sortedPages.length; i++) {
        final scanPage = sortedPages[i];
        final file = File(scanPage.localImagePath);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        final image = PdfBitmap(bytes);

        final page = document.pages.add();
        final pageSize = page.getClientSize();

        // Fit the scanned image to the page while preserving aspect ratio.
        final scale = (pageSize.width / image.width)
            .clamp(0, pageSize.height / image.height)
            .toDouble();
        final drawWidth = image.width * scale;
        final drawHeight = image.height * scale;
        final offsetX = (pageSize.width - drawWidth) / 2;
        final offsetY = (pageSize.height - drawHeight) / 2;

        page.graphics.drawImage(
          image,
          Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight),
        );

        if (watermarkText != null && watermarkText.trim().isNotEmpty) {
          _drawWatermark(page.graphics, pageSize, watermarkText);
        }

        final isLastPage = i == sortedPages.length - 1;
        if (signatureBitmap != null && (!signatureOnLastPageOnly || isLastPage)) {
          _drawSignature(page.graphics, pageSize, signatureBitmap);
        }
      }

      if (document.pages.count == 0) {
        throw PdfServiceException('None of this document\'s pages could be read from disk.');
      }

      if (userPassword != null || ownerPassword != null) {
        final security = document.security;
        security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
        if (userPassword != null && userPassword.isNotEmpty) {
          security.userPassword = userPassword;
        }
        if (ownerPassword != null && ownerPassword.isNotEmpty) {
          security.ownerPassword = ownerPassword;
        }
      }

      final bytes = await document.save();
      return _writeToDisk(Uint8List.fromList(bytes), suffix: 'compiled');
    } finally {
      document.dispose();
    }
  }

  void _drawWatermark(PdfGraphics graphics, Size pageSize, String text) {
    graphics.save();
    try {
      final font = PdfStandardFont(PdfFontFamily.helvetica, 42, style: PdfFontStyle.bold);
      final brush = PdfSolidBrush(PdfColor(150, 150, 150, 90)); // semi-transparent grey

      graphics.translateTransform(pageSize.width / 2, pageSize.height / 2);
      graphics.rotateTransform(-35);
      final textSize = font.measureString(text);
      graphics.drawString(
        text,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height),
      );
    } finally {
      graphics.restore();
    }
  }

  void _drawSignature(PdfGraphics graphics, Size pageSize, PdfBitmap signature) {
    // Bottom-right stamp, sized to ~28% of page width, aspect-ratio preserved.
    const marginRight = 36.0;
    const marginBottom = 36.0;
    final targetWidth = pageSize.width * 0.28;
    final aspect = signature.height / signature.width;
    final targetHeight = targetWidth * aspect;

    final x = pageSize.width - marginRight - targetWidth;
    final y = pageSize.height - marginBottom - targetHeight;

    graphics.drawImage(signature, Rect.fromLTWH(x, y, targetWidth, targetHeight));
  }

  /// Applies or updates a password on an existing PDF without re-rasterizing
  /// pages — used when securing a document after it's already been exported.
  Future<String> applySecurity(
    String pdfPath, {
    String? userPassword,
    String? ownerPassword,
  }) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw PdfServiceException('The source PDF could not be found.');
    }
    final document = PdfDocument(inputBytes: await file.readAsBytes());
    try {
      final security = document.security;
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
      security.userPassword = userPassword ?? '';
      security.ownerPassword = ownerPassword ?? '';
      final bytes = await document.save();
      return _writeToDisk(Uint8List.fromList(bytes), suffix: 'secured');
    } finally {
      document.dispose();
    }
  }

  /// Merges multiple existing local PDF files into one new local PDF.
  /// Pages are copied via template (annotations/form fields are flattened
  /// in the process — this is a known tradeoff of on-device, offline merge).
  Future<String> mergePdfs(List<String> pdfPaths) async {
    if (pdfPaths.length < 2) {
      throw PdfServiceException('Select at least two PDFs to merge.');
    }

    final merged = PdfDocument();
    final loaded = <PdfDocument>[];
    try {
      for (final path in pdfPaths) {
        final file = File(path);
        if (!await file.exists()) {
          throw PdfServiceException('Missing file: $path');
        }
        final source = PdfDocument(inputBytes: await file.readAsBytes());
        loaded.add(source);
        for (var i = 0; i < source.pages.count; i++) {
          final template = source.pages[i].createTemplate();
          final page = merged.pages.add();
          page.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
      }
      final bytes = await merged.save();
      return _writeToDisk(Uint8List.fromList(bytes), suffix: 'merged');
    } finally {
      for (final d in loaded) {
        d.dispose();
      }
      merged.dispose();
    }
  }

  /// Splits [pdfPath] into individual single-page PDFs saved locally.
  /// Returns the list of new file paths, in original page order.
  Future<List<String>> splitPdf(String pdfPath) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw PdfServiceException('The source PDF could not be found.');
    }

    final source = PdfDocument(inputBytes: await file.readAsBytes());
    final outputPaths = <String>[];
    try {
      if (source.pages.count <= 1) {
        throw PdfServiceException('This PDF only has one page — nothing to split.');
      }
      for (var i = 0; i < source.pages.count; i++) {
        final single = PdfDocument();
        try {
          final template = source.pages[i].createTemplate();
          final page = single.pages.add();
          page.graphics.drawPdfTemplate(template, const Offset(0, 0));
          final bytes = await single.save();
          final path = await _writeToDisk(Uint8List.fromList(bytes), suffix: 'page_${i + 1}');
          outputPaths.add(path);
        } finally {
          single.dispose();
        }
      }
      return outputPaths;
    } finally {
      source.dispose();
    }
  }

  Future<String> _writeToDisk(Uint8List bytes, {required String suffix}) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${suffix}_${const Uuid().v4()}.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }
}
