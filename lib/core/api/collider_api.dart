// Collider API client. Made by Claude.
// Talks only to the local Collider server (tools/collider_server.py), which holds the keys.
import 'dart:async';
import 'package:dio/dio.dart';
import 'proxy.dart';
import 'package:flutter/material.dart';
import '../../models/model_def.dart';

enum AskMode { chat, internet, research, deep }

extension AskModeX on AskMode {
  String get wire => switch (this) {
        AskMode.chat => 'chat',
        AskMode.internet => 'internet',
        AskMode.research => 'research',
        AskMode.deep => 'deep',
      };
}

class ModelResult {
  final String status; // pending | done | error
  final String text;
  final String essence;
  final String? error;
  const ModelResult(this.status, this.text, this.essence, this.error);
  factory ModelResult.fromJson(Map<String, dynamic> j) => ModelResult(
        j['status'] as String? ?? 'pending',
        j['text'] as String? ?? '',
        j['essence'] as String? ?? '',
        j['error'] as String?,
      );
}

class ConsensusResult {
  final String status; // pending | done | unavailable
  final String summary;
  final String score;
  final List<String> dissent;
  final String need;
  final List<List<String>> groups;
  final Map<String, int> chains;
  final String tieBasis;
  const ConsensusResult(this.status, this.summary, this.score, this.dissent, this.need,
      [this.groups = const [], this.chains = const {}, this.tieBasis = '']);
  factory ConsensusResult.fromJson(Map<String, dynamic>? j) => ConsensusResult(
        j?['status'] as String? ?? 'pending',
        j?['summary'] as String? ?? '',
        j?['score'] as String? ?? '',
        ((j?['dissent'] as List?) ?? const []).map((e) => '$e').toList(),
        j?['need'] as String? ?? '',
        [for (final g in (j?['groups'] as List?) ?? const []) [for (final m in g as List) '$m']],
        {for (final e in ((j?['chains'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt()},
        j?['tie_basis'] as String? ?? '',
      );
}

class JobState {
  final String id;
  final String prompt;
  final String mode;
  final String stage;
  final bool done;
  final Map<String, ModelResult> results;
  final ConsensusResult consensus;
  final List<Map<String, dynamic>> sources;
  final DateTime created;
  const JobState(this.id, this.prompt, this.mode, this.stage, this.done, this.results, this.consensus, this.sources, this.created);
  factory JobState.fromJson(Map<String, dynamic> j) => JobState(
        j['id'] as String,
        j['prompt'] as String? ?? '',
        j['mode'] as String? ?? 'chat',
        j['stage'] as String? ?? '',
        (j['status'] ?? 'done') == 'done',
        ((j['results'] as Map?) ?? {}).map((k, v) => MapEntry('$k', ModelResult.fromJson(Map<String, dynamic>.from(v as Map)))),
        ConsensusResult.fromJson(j['consensus'] == null ? null : Map<String, dynamic>.from(j['consensus'] as Map)),
        ((j['sources'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        DateTime.fromMillisecondsSinceEpoch((((j['created'] as num?) ?? 0) * 1000).toInt()),
      );
}

class ColliderApi {
  ColliderApi._();
  static final ColliderApi instance = ColliderApi._();
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 180)));

  // v8.4: the chat API sits behind the same proxy when COLLIDER_PROXY is set.
  String get _base => ColliderProxy.enabled ? ColliderProxy.root : Uri.base.origin;
  bool online = false;
  bool webSearch = false;
  int nvidiaKeys = 0;

  static Color _hex(String h) => Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));

  /// Loads the live roster from the server into [ModelRoster]. Returns true when connected.
  Future<bool> loadRoster() async {
    try {
      final r = await _dio.get('$_base/api/models');
      final list = (r.data['models'] as List).cast<Map>();
      webSearch = r.data['search'] == true;
      nvidiaKeys = (r.data['keys'] as num?)?.toInt() ?? 0;
      ModelRoster.setLive([
        for (final m in list)
          ModelDef(
            id: m['id'] as String,
            label: m['label'] as String,
            provider: m['provider'] as String,
            tier: ModelTier.free,
            categories: const [ModelCategory.general],
            providerColor: _hex(m['color'] as String),
          ),
      ]);
      online = true;
    } catch (_) {
      online = false;
    }
    return online;
  }

  Future<String> ask({required String prompt, required List<String> models, required AskMode mode, required bool autosave, required bool incognito}) async {
    final r = await _dio.post('$_base/api/ask', data: {
      'prompt': prompt,
      'models': models,
      'mode': mode.wire,
      'autosave': autosave,
      'incognito': incognito,
    });
    return r.data['id'] as String;
  }

  /// Polls a job until done, emitting each state.
  Stream<JobState> watch(String id) async* {
    while (true) {
      final r = await _dio.get('$_base/api/job/$id');
      final s = JobState.fromJson(Map<String, dynamic>.from(r.data as Map));
      yield s;
      if (s.done) return;
      await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  Future<({String text, String essence})> reply({required String model, required List<Map<String, String>> messages, required AskMode mode}) async {
    final r = await _dio.post('$_base/api/reply', data: {'model': model, 'messages': messages, 'mode': mode.wire});
    return (text: r.data['text'] as String, essence: r.data['essence'] as String);
  }

  Future<List<JobState>> history() async {
    try {
      final r = await _dio.get('$_base/api/history');
      return [
        for (final s in (r.data['sessions'] as List)) JobState.fromJson({...Map<String, dynamic>.from(s as Map), 'status': 'done'}),
      ];
    } catch (_) {
      return const [];
    }
  }
}
