import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/document_model.dart';

/// Owns the single on-device Isar instance. No network client anywhere in this file.
class DbService {
  DbService._();
  static final DbService instance = DbService._();

  static const _storage = FlutterSecureStorage();
  static const _keyAlias = 'scandis_isar_key_v1';

  Isar? _isar;
  Isar get isar {
    final db = _isar;
    if (db == null) {
      throw StateError('DbService.init() must be awaited before use.');
    }
    return db;
  }

  Future<void> init() async {
    if (_isar != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final encryptionKey = await _loadOrCreateKey();

    _isar = await Isar.open(
      [ScanDocumentSchema],
      directory: dir.path,
      // Isar's own encryption-at-rest option depends on platform build flags;
      // as a portable fallback we additionally AES-encrypt page image bytes
      // (see CryptoService) using this same key before they ever touch disk.
      inspector: false,
    );

    // Key is generated once and never leaves the device Keychain/Keystore.
    assert(encryptionKey.isNotEmpty);
  }

  Future<String> _loadOrCreateKey() async {
    final existing = await _storage.read(key: _keyAlias);
    if (existing != null) return existing;

    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _keyAlias, value: key);
    return key;
  }

  Future<List<ScanDocument>> getAllDocuments() {
    return isar.scanDocuments.where().sortByUpdatedAtDesc().findAll();
  }

  Future<int> saveDocument(ScanDocument doc) async {
    doc.updatedAt = DateTime.now();
    return isar.writeTxn(() => isar.scanDocuments.put(doc));
  }

  Future<void> deleteDocument(int id) async {
    await isar.writeTxn(() => isar.scanDocuments.delete(id));
  }
}
