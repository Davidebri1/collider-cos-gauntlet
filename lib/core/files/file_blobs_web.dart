// Web: the bytes of every file the user adds, in IndexedDB
// (database `collider_files`, store `blobs`, key = StoredFile.id), so a file
// opens again after a reload (DEVIATIONS D32).
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class FileBlobs {
  FileBlobs._();
  static const String _db = 'collider_files';
  static const String _store = 'blobs';
  static Future<web.IDBDatabase>? _open;

  static Future<web.IDBDatabase> _database() => _open ??= () {
        final c = Completer<web.IDBDatabase>();
        final req = web.window.indexedDB.open(_db, 1);
        req.onupgradeneeded = ((web.Event _) {
          final db = req.result as web.IDBDatabase;
          if (!db.objectStoreNames.contains(_store)) db.createObjectStore(_store);
        }).toJS;
        req.onsuccess = ((web.Event _) => c.complete(req.result as web.IDBDatabase)).toJS;
        req.onerror = ((web.Event _) {
          _open = null;
          c.completeError(StateError('IndexedDB open failed'));
        }).toJS;
        return c.future;
      }();

  static Future<JSAny?> _run(String mode, web.IDBRequest Function(web.IDBObjectStore s) op) async {
    final db = await _database();
    final tx = db.transaction(_store.toJS, mode);
    final req = op(tx.objectStore(_store));
    final c = Completer<JSAny?>();
    req.onsuccess = ((web.Event _) => c.complete(req.result)).toJS;
    req.onerror = ((web.Event _) => c.completeError(StateError('IndexedDB request failed'))).toJS;
    return c.future;
  }

  static Future<bool> put(String id, Uint8List bytes) async {
    try {
      await _run('readwrite', (s) => s.put(bytes.toJS, id.toJS));
      return true;
    } catch (_) {
      return false; // e.g. quota exceeded or private mode
    }
  }

  static Future<Uint8List?> get(String id) async {
    try {
      final r = await _run('readonly', (s) => s.get(id.toJS));
      if (r == null || r.isUndefinedOrNull) return null;
      return (r as JSUint8Array).toDart;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String id) async {
    try {
      await _run('readwrite', (s) => s.delete(id.toJS));
    } catch (_) {}
  }

  static Future<Set<String>> keys() async {
    try {
      final r = await _run('readonly', (s) => s.getAllKeys());
      if (r == null) return <String>{};
      final out = <String>{};
      for (final k in (r as JSArray<JSAny?>).toDart) {
        final d = k?.dartify();
        if (d is String) out.add(d);
      }
      return out;
    } catch (_) {
      return <String>{};
    }
  }

  /// Hands the file to the browser: a new tab ([newTab], e.g. PDF) or a
  /// download under its own name.
  static Future<bool> openExternal(String name, Uint8List bytes, String mime, {bool newTab = false}) async {
    try {
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
      final url = web.URL.createObjectURL(blob);
      if (newTab) {
        web.window.open(url, '_blank');
      } else {
        final a = web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = name;
        web.document.body?.append(a);
        a.click();
        a.remove();
      }
      // Give the tab / download time to read it, then free it.
      Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
      return true;
    } catch (_) {
      return false;
    }
  }
}
