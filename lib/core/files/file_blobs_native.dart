// iOS / Android: the bytes of every file the user adds, as files on disk in
// the app's support directory (collider_files/<id>), so a file opens again
// after a restart. Same caps as web (FileStore: 25 MB a file, 250 MB total).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class FileBlobs {
  FileBlobs._();
  static Future<Directory>? _dir;

  static Future<Directory> _root() => _dir ??= () async {
        final base = await getApplicationSupportDirectory();
        final d = Directory('${base.path}${Platform.pathSeparator}collider_files');
        if (!await d.exists()) await d.create(recursive: true);
        return d;
      }();

  // Ids carry the original file name; the on-disk name is a safe encoding.
  static String _enc(String id) => base64Url.encode(utf8.encode(id)).replaceAll('=', '');
  static String _dec(String n) => utf8.decode(base64Url.decode(base64Url.normalize(n)));

  static Future<File> _file(String id) async => File('${(await _root()).path}${Platform.pathSeparator}${_enc(id)}');

  static Future<bool> put(String id, Uint8List bytes) async {
    try {
      await (await _file(id)).writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {
      return false; // e.g. disk full
    }
  }

  static Future<Uint8List?> get(String id) async {
    try {
      final f = await _file(id);
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String id) async {
    try {
      final f = await _file(id);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static Future<Set<String>> keys() async {
    try {
      final out = <String>{};
      await for (final e in (await _root()).list()) {
        if (e is! File) continue;
        try {
          out.add(_dec(e.uri.pathSegments.last));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return <String>{};
    }
  }

  /// Hands the file to the system: written under its own name to the cache
  /// directory and opened with the app the user has for that type.
  static Future<bool> openExternal(String name, Uint8List bytes, String mime, {bool newTab = false}) async {
    try {
      final tmp = await getTemporaryDirectory();
      final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final f = File('${tmp.path}${Platform.pathSeparator}$safe');
      await f.writeAsBytes(bytes, flush: true);
      final r = await OpenFilex.open(f.path, type: mime);
      return r.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }
}
