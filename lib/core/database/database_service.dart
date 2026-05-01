import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  // ─── LRU cache ────────────────────────────────────────────────────────────
  static const int _cacheSize = 20;
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final List<String> _cacheKeys = [];

  bool get isReady => _db != null;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> initDatabase() async {
    if (kIsWeb) return;
    if (_db != null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'app_v7.db');

    if (!await databaseFactory.databaseExists(path)) {
      debugPrint('[DB] Initializing database from assets...');
      await Directory(dirname(path)).create(recursive: true);
      ByteData data = await rootBundle.load('assets/search_data.db');
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(path).writeAsBytes(bytes, flush: true);
    }

    _db = await databaseFactory.openDatabase(path);

    if (!await _checkIntegrity()) {
      // Check for FTS5 vs FTS4 compatibility
      bool hasFts5 = false;
      bool hasFts4 = false;
      
      try {
        final modules = await _db!.rawQuery(
          "SELECT name FROM pragma_module_list()",
        );
        final allModules = modules.map((m) => m['name'].toString()).toList();
        hasFts5 = allModules.contains('fts5');
        hasFts4 = allModules.contains('fts4');
      } catch (e) {
        // pragma_module_list might fail if FTS5 is not available
        debugPrint('[DB] Module list check failed: $e - attempting FTS4 fallback');
        hasFts4 = true; // Assume FTS4 is available
      }

      if ((hasFts4 || !hasFts5) && !hasFts5) {
        debugPrint('[DB] FTS5 missing. Auto-repairing using FTS4 fallback...');
        await _ensureFts4Table();
        if (await _checkIntegrity()) {
          debugPrint('[DB] Ready (FTS4).');
          return;
        }
      }
      
      // If still not ready, throw error
      if (!await _checkIntegrity()) {
        throw Exception(
          'Database integrity check failed. The data might be corrupted or incompatible with this device.',
        );
      }
    }

    debugPrint('[DB] Ready.');
  }

  Future<bool> _checkIntegrity() async {
    try {
      if (_db == null) return false;
      // Check for pages_v4 first, then fallback to original pages
      final checkV4 = await _db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE name='pages_v4'",
      );
      if (checkV4.isNotEmpty) {
        await _db!.rawQuery('SELECT 1 FROM pages_v4 LIMIT 1');
        return true;
      }
      final checkOrig = await _db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE name='pages'",
      );
      if (checkOrig.isNotEmpty) {
        await _db!.rawQuery('SELECT 1 FROM pages LIMIT 1');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureFts4Table() async {
    final check = await _db!.rawQuery(
      "SELECT name FROM sqlite_master WHERE name='pages_v4'",
    );
    if (check.isNotEmpty) return;

    await _db!.execute(
      'CREATE VIRTUAL TABLE pages_v4 USING fts4(url, title, content)',
    );
    try {
      await _db!.execute(
        'INSERT INTO pages_v4(url, title, content) SELECT c0, c1, c2 FROM pages_content',
      );
    } catch (_) {
      await _db!.execute(
        'INSERT INTO pages_v4(url, title, content) SELECT c0url, c1title, c2content FROM pages_content',
      );
    }
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> performSearch(String searchTerm) async {
    if (_db == null || searchTerm.trim().isEmpty) return [];

    final normalized = searchTerm.trim().toLowerCase();
    if (_cache.containsKey(normalized)) return _cache[normalized]!;

    List<Map<String, dynamic>> results = [];

    // FTS path.
    try {
      final cleanTerm = normalized.replaceAll('"', '');
      if (cleanTerm.isNotEmpty) {
        final ftsQuery = '"$cleanTerm"*';

        // Use pages_v4 if it exists, otherwise use pages
        final useV4 = (await _db!.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='pages_v4'",
        )).isNotEmpty;
        final tableName = useV4 ? 'pages_v4' : 'pages';

        try {
          final rows = await _db!.rawQuery(
            "SELECT url, title, content "
            "FROM $tableName "
            "WHERE $tableName MATCH ? LIMIT 30",
            [ftsQuery],
          );

          if (rows.isNotEmpty) {
            results = rows.map((row) {
              final String rawTitle = row['title']?.toString() ?? '';
              final String rawContent = row['content']?.toString() ?? '';
              
              // ─── Calculate Keyword Occurrences ───
              int count = 0;
              if (normalized.isNotEmpty) {
                // Use regex to count how many times the term appears in raw title/content
                final regex = RegExp(RegExp.escape(normalized), caseSensitive: false);
                count += regex.allMatches(rawTitle).length;
                count += regex.allMatches(rawContent).length;
              }

              // ─── Apply Visual Highlighting ───
              String title = rawTitle;
              String content = rawContent;
              if (normalized.isNotEmpty) {
                // Inject <b> tags for UI highlighting
                title = _manualHighlight(title, normalized, fullText: true);
                content = _manualHighlight(content, normalized, fullText: true);
              }

              return {
                'url': row['url']?.toString() ?? '',
                'title': title,
                'content': content,
                'occurrenceCount': count,
              };
            }).toList();
          }
        } catch (ftsError) {
          // FTS might not be available, will use LIKE fallback
          debugPrint('[DB] FTS error: $ftsError');
        }
      }
    } catch (e) {
      debugPrint('[DB] FTS error: $e');
    }

    // LIKE fallback.
    if (results.isEmpty) {
      try {
        final useV4 = (await _db!.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='pages_v4'",
        )).isNotEmpty;
        final tableName = useV4 ? 'pages_v4' : 'pages';

        final rows = await _db!.rawQuery(
          'SELECT url, title, content FROM $tableName '
          'WHERE title LIKE ? OR content LIKE ? LIMIT 30',
          ['%$normalized%', '%$normalized%'],
        );

        // Manual highlighting for LIKE results
        results = rows.map((row) {
          final String rawTitle = row['title']?.toString() ?? '';
          final String rawContent = row['content']?.toString() ?? '';

          // ─── Calculate Keyword Occurrences ───
          int count = 0;
          if (normalized.isNotEmpty) {
            // Count occurrences in raw text for the LIKE fallback path
            final regex = RegExp(RegExp.escape(normalized), caseSensitive: false);
            count += regex.allMatches(rawTitle).length;
            count += regex.allMatches(rawContent).length;
          }

          // ─── Apply Visual Highlighting ───
          String title = rawTitle;
          String content = rawContent;
          if (normalized.isNotEmpty) {
            // Inject <b> tags for UI highlighting
            title = _manualHighlight(title, normalized, fullText: true);
            content = _manualHighlight(content, normalized, fullText: true);
          }

          return {
            'url': row['url']?.toString() ?? '',
            'title': title,
            'content': content,
            'occurrenceCount': count,
          };
        }).toList();
      } catch (e) {
        debugPrint('[DB] Fallback search error: $e');
      }
    }

    _putCache(normalized, results);
    return results;
  }

  void _putCache(String key, List<Map<String, dynamic>> value) {
    if (_cacheKeys.length >= _cacheSize) {
      _cache.remove(_cacheKeys.removeAt(0));
    }
    _cache[key] = value;
    _cacheKeys.add(key);
  }

  String _manualHighlight(String text, String term, {bool fullText = false}) {
    if (term.isEmpty || text.isEmpty) return text;
    final lowercaseText = text.toLowerCase();
    final index = lowercaseText.indexOf(term);
    if (index == -1) return text;

    String resultText;
    if (fullText) {
      resultText = text;
    } else {
      // Create a simple snippet around the match
      int start = (index - 40).clamp(0, text.length);
      int end = (index + term.length + 40).clamp(0, text.length);
      resultText = text.substring(start, end);
      if (start > 0) resultText = '...$resultText';
      if (end < text.length) resultText = '$resultText...';
    }

    // Inject tags
    final regex = RegExp(RegExp.escape(term), caseSensitive: false);
    return resultText.replaceAllMapped(
      regex,
      (match) => '<b>${match.group(0)}</b>',
    );
  }

}
