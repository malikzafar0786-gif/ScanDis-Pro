import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/document_model.dart';
import 'db_service.dart';

enum PodcastState { idle, playing, paused, stopped }

/// Runs ML Kit text recognition fully on-device, then feeds the extracted
/// text to the platform TTS engine — no text or audio ever leaves the phone.
class OcrTtsService {
  OcrTtsService._();
  static final OcrTtsService instance = OcrTtsService._();

  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final FlutterTts _tts = FlutterTts();

  PodcastState state = PodcastState.idle;

  Future<void> dispose() async {
    await _recognizer.close();
    await _tts.stop();
  }

  /// Runs OCR over every page that doesn't already have cached text,
  /// persists the result, and returns the combined document text.
  Future<String> extractDocumentText(ScanDocument doc) async {
    final buffer = StringBuffer();
    var changed = false;

    for (final page in doc.pages) {
      if (page.ocrText == null || page.ocrText!.trim().isEmpty) {
        try {
          final file = File(page.localImagePath);
          if (!await file.exists()) continue;
          final input = InputImage.fromFile(file);
          final result = await _recognizer.processImage(input);
          page.ocrText = result.text;
          changed = true;
        } catch (e) {
          // Skip a page that fails OCR rather than aborting the whole document.
          page.ocrText ??= '';
        }
      }
      if (page.ocrText != null && page.ocrText!.isNotEmpty) {
        buffer.writeln(page.ocrText);
        buffer.writeln();
      }
    }

    if (changed) {
      await DbService.instance.saveDocument(doc);
    }
    return buffer.toString().trim();
  }

  /// Configures and starts reading [text] aloud as an offline "podcast".
  Future<void> playAsPodcast(
    String text, {
    double rate = 0.45,
    double pitch = 1.0,
    String languageCode = 'en-US',
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError('No extracted text to read aloud.');
    }

    await _tts.setLanguage(languageCode);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);

    _tts.setCompletionHandler(() => state = PodcastState.stopped);
    _tts.setCancelHandler(() => state = PodcastState.stopped);
    _tts.setPauseHandler(() => state = PodcastState.paused);
    _tts.setContinueHandler(() => state = PodcastState.playing);
    _tts.setErrorHandler((msg) => state = PodcastState.stopped);

    state = PodcastState.playing;
    await _tts.speak(text);
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  Future<void> stop() async {
    await _tts.stop();
    state = PodcastState.stopped;
  }
}
