// Files the user actually added to Collider (v8.2 fix pass, DEVIATIONS D22).
//
// Every file picked in Files (+), attached in the composer, or attached to a
// model pill is recorded here with its real name, size and time (index in
// SharedPreferences) and, on web, its contents in IndexedDB (FileBlobs,
// v8.2 round 3, D32), so it opens again after a reload. Files lists only
// these: there are no sample entries. Caps: 25 MB a file, 250 MB in total.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_blobs.dart';

class StoredFile {
  final String id;
  final String name;
  final int sizeBytes;
  final String type; // Document | Writing | Image | Video | Data
  final int addedAtMs;
  final String source; // files | composer | model

  const StoredFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.type,
    required this.addedAtMs,
    required this.source,
  });

  DateTime get addedAt => DateTime.fromMillisecondsSinceEpoch(addedAtMs);

  Map<String, Object> toJson() =>
      {'id': id, 'name': name, 'size': sizeBytes, 'type': type, 'at': addedAtMs, 'src': source};

  static StoredFile? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = j['name'];
    if (name is! String || name.isEmpty) return null;
    return StoredFile(
      id: (j['id'] as String?) ?? name,
      name: name,
      sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
      type: (j['type'] as String?) ?? FileStore.typeFor(name),
      addedAtMs: (j['at'] as num?)?.toInt() ?? 0,
      source: (j['src'] as String?) ?? 'files',
    );
  }
}

class FileStore extends ChangeNotifier {
  FileStore._();
  static final FileStore instance = FileStore._();
  static const String _prefsKey = 'collider_files_v1';
  static const int maxFileBytes = 25 * 1024 * 1024;
  /// Videos may be bigger (map row 19, D55).
  static const int maxVideoBytes = 100 * 1024 * 1024;
  static int capFor(String name) => isVideo(name) ? maxVideoBytes : maxFileBytes;
  static const int maxTotalBytes = 250 * 1024 * 1024;

  /// A quiet one-line note about the last add (e.g. a file over the cap);
  /// Files shows it under its search field.
  final ValueNotifier<String?> notice = ValueNotifier<String?>(null);

  final List<StoredFile> _files = [];
  bool _loaded = false;
  Future<void>? _loading;

  /// Newest first.
  List<StoredFile> get files => List.unmodifiable(_files);

  static String typeFor(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    if (const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'heic', 'svg', 'bmp'].contains(ext)) return 'Image';
    if (_videoExt.contains(ext)) return 'Video';
    if (const ['json', 'csv', 'tsv', 'yaml', 'yml', 'xml', 'xlsx', 'xls', 'parquet', 'sqlite'].contains(ext)) return 'Data';
    if (const ['txt', 'md', 'markdown', 'doc', 'docx', 'rtf', 'odt', 'pages'].contains(ext)) return 'Writing';
    return 'Document';
  }

  Future<void> init() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (s != null && s.isNotEmpty) {
        final list = jsonDecode(s);
        if (list is List) {
          _files
            ..clear()
            ..addAll(list.map(StoredFile.fromJson).whereType<StoredFile>());
        }
      }
      if (_files.isNotEmpty) {
        // Only files whose contents are really stored (records from the
        // metadata-only build, or cleared site data, cannot be opened).
        final keys = await FileBlobs.keys();
        final before = _files.length;
        _files.removeWhere((f) => !keys.contains(f.id));
        if (_files.length != before) await _save();
      }
    } catch (e) {
      debugPrint('FileStore: ignored unreadable store: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  bool get loaded => _loaded;

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_prefsKey, jsonEncode([for (final f in _files) f.toJson()]));
    } catch (_) {}
  }

  int get totalBytes => _files.fold(0, (a, f) => a + f.sizeBytes);

  /// Records and stores files the user just picked ([source]: files |
  /// composer | model). Returns a quiet note for anything not kept (over the
  /// cap, unreadable, or storage failed), also published on [notice].
  Future<String?> addPicked(List<PlatformFile> picked, String source) async {
    await init();
    final now = DateTime.now().millisecondsSinceEpoch;
    final skipped = <String>[];
    var tooBig = false;
    var i = 0;
    for (final f in picked) {
      if (f.name.isEmpty) continue;
      final id = '$now-${i++}-${f.name}';
      if (f.size > capFor(f.name) || totalBytes + f.size > maxTotalBytes) {
        skipped.add(f.name);
        tooBig = true;
        continue;
      }
      final Uint8List? bytes = f.bytes;
      if (bytes == null || !await FileBlobs.put(id, bytes)) {
        skipped.add(f.name);
        continue;
      }
      _files.insert(
        0,
        StoredFile(id: id, name: f.name, sizeBytes: f.size, type: typeFor(f.name), addedAtMs: now, source: source),
      );
    }
    notifyListeners();
    await _save();
    String? note;
    if (skipped.isNotEmpty) {
      final what = skipped.length == 1 ? skipped.first : '${skipped.length} files';
      note = tooBig ? '$what not kept: too big' : '$what could not be kept';
    }
    notice.value = note;
    return note;
  }

  /// Saves app-made content (e.g. a model answer) as a file the user owns.
  Future<String?> addBytes(String name, Uint8List bytes, String source) =>
      addPicked([PlatformFile(name: name, size: bytes.length, bytes: bytes)], source);

  /// The stored contents, or null (not found).
  Future<Uint8List?> bytesOf(String id) => FileBlobs.get(id);

  Future<void> remove(String id) async {
    _files.removeWhere((f) => f.id == id);
    notifyListeners();
    await _save();
    await FileBlobs.delete(id);
  }

  static String mimeFor(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return const {
          'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'webp': 'image/webp', 'gif': 'image/gif',
          'bmp': 'image/bmp', 'svg': 'image/svg+xml', 'pdf': 'application/pdf', 'txt': 'text/plain', 'md': 'text/markdown',
          'csv': 'text/csv', 'json': 'application/json', 'xml': 'application/xml', 'html': 'text/html',
          'mp4': 'video/mp4', 'm4v': 'video/mp4', 'mov': 'video/quicktime', 'webm': 'video/webm', 'ogv': 'video/ogg',
        }[ext] ??
        'application/octet-stream';
  }

  /// Opens in-app as text (plain-text formats).
  static bool isText(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return const ['txt', 'md', 'markdown', 'csv', 'tsv', 'json', 'yaml', 'yml', 'xml', 'log', 'dart', 'py', 'js', 'ts', 'html', 'css']
        .contains(ext);
  }

  static const _videoExt = ['mp4', 'm4v', 'mov', 'webm', 'ogv'];

  /// Plays in the in-app video player (map row 19).
  static bool isVideo(String name) {
    final dot = name.lastIndexOf('.');
    return dot >= 0 && _videoExt.contains(name.substring(dot + 1).toLowerCase());
  }

  /// Opens in-app as an image (formats Flutter decodes).
  static bool isImage(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'].contains(ext);
  }

  static String sizeLabel(int b) {
    if (b <= 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${d.inDays}d ago';
  }
}
