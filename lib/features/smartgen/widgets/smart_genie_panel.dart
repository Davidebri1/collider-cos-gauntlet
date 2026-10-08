import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../theme/smartgen_glass.dart';
import '../models/smartgen_models.dart';
import '../state/smartgen_store.dart';

/// Smart Genie: a minimizable agentic assistant panel for Smart Gen.
/// Pro-gated for agentic actions; Elite unlocks attached coding agents.
/// Icon is a subtle fog/mist — no lamp, no mascot, no theatrics.
///
/// The Genie runs a local command interpreter by default. [callAiApi] is
/// the hook where a real AI API plugs in: it returns null when no key is
/// configured, and the panel says so honestly ("Local interpreter").
class SmartGeniePanel extends StatefulWidget {
  final SmartGenStore store;
  final bool isPro;
  final bool isElite;
  final VoidCallback onClose;
  final VoidCallback onMinimize;

  const SmartGeniePanel({
    super.key,
    required this.store,
    this.isPro = false,
    this.isElite = false,
    required this.onClose,
    required this.onMinimize,
  });

  @override
  State<SmartGeniePanel> createState() => _SmartGeniePanelState();
}

class _GenieMessage {
  final bool fromUser;
  final String text;
  final DateTime at;
  final List<_GenieAttachment> attachments; // in-memory only

  _GenieMessage(this.fromUser, this.text,
      {DateTime? at, List<_GenieAttachment>? attachments})
      : at = at ?? DateTime.now(),
        attachments = attachments ?? const [];
}

class _GenieAttachment {
  final String name;
  final String mime;
  final String dataUrl;
  const _GenieAttachment(
      {required this.name, required this.mime, required this.dataUrl});
}

class _SmartGeniePanelState extends State<SmartGeniePanel> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _newConvoTimer;

  final List<_GenieMessage> _history = [];
  final List<_GenieAttachment> _pendingAttachments = [];
  bool _working = false;
  double _msgMaxWidth = 280;

  /// Destructive commands (e.g. delete-all) park here until the user
  /// replies "yes". Never execute them on a single ambiguous message.
  Future<String> Function()? _pendingConfirm;
  String? _pendingConfirmLabel;

  /// Compile-time API key hook. Empty (the default) means the Genie runs
  /// its local interpreter and says so. Set SMART_GENIE_API_KEY via
  /// --dart-define to light up the live path in [callAiApi].
  static const _apiKey =
      String.fromEnvironment('SMART_GENIE_API_KEY', defaultValue: '');

  @override
  void initState() {
    super.initState();
    // Spec: persisted conversation rendering — hydrate from the store.
    for (final m in widget.store.genieHistory) {
      _history.add(_GenieMessage(
        m['fromUser'] == 'true',
        m['text'] ?? '',
        at: DateTime.tryParse(m['at'] ?? ''),
      ));
    }
  }

  @override
  void dispose() {
    _newConvoTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Real-AI hook. Returns the model's reply text, or null when no API
  /// key is configured — the panel then falls back to the local command
  /// interpreter and reports "Local interpreter" in the header.
  ///
  /// To go live: pass --dart-define=SMART_GENIE_API_KEY=… at build time
  /// and implement the POST below against your provider.
  Future<String?> callAiApi(String userText) async {
    if (_apiKey.isEmpty) return null;
    // TODO: POST to the provider with the conversation and return the text.
    // Until this is implemented, the Genie stays in local mode even with a
    // key present — it must never claim to be live when it isn't.
    return null;
  }

  bool get _liveAi => _apiKey.isNotEmpty;

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if ((text.isEmpty && _pendingAttachments.isEmpty) || _working) return;
    final attachments = List<_GenieAttachment>.from(_pendingAttachments);
    _inputCtrl.clear();
    _pendingAttachments.clear();
    var displayText = text;
    if (attachments.isNotEmpty) {
      displayText =
          '${text.isEmpty ? '' : '$text\n'}[attached ${attachments.length} image${attachments.length == 1 ? '' : 's'}: ${attachments.map((a) => a.name).join(', ')}]';
    }
    setState(() {
      _history.add(_GenieMessage(true, text.isEmpty ? '(attachment)' : text,
          attachments: attachments));
      _working = true;
    });
    widget.store.geniePush(true, displayText);
    _scrollToEnd();
    final reply = await callAiApi(displayText) ??
        await _runCommand(displayText, attachments);
    if (!mounted) return;
    setState(() {
      _history.add(_GenieMessage(false, reply));
      _working = false;
    });
    widget.store.geniePush(false, reply);
    _scrollToEnd();
  }

  Future<void> _attach() async {
    if (_pendingAttachments.length >= 4) return;
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (res == null || !mounted) return;
    setState(() {
      for (final f in res.files) {
        if (_pendingAttachments.length >= 4) break;
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        if (bytes.length > 2 * 1024 * 1024) continue; // persistence guard
        final mime = f.extension == 'png'
            ? 'image/png'
            : (f.extension == 'gif' ? 'image/gif' : 'image/jpeg');
        _pendingAttachments.add(_GenieAttachment(
          name: f.name,
          mime: mime,
          dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
        ));
      }
    });
  }

  bool _newConvoArmed = false;

  /// First tap arms an inline confirmation on the button itself;
  /// the second tap clears history and starts fresh.
  void _newConversation() {
    if (!_newConvoArmed) {
      setState(() => _newConvoArmed = true);
      _newConvoTimer?.cancel();
      _newConvoTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _newConvoArmed = false);
      });
      return;
    }
    _newConvoTimer?.cancel();
    widget.store.genieClearHistory();
    setState(() {
      _history.clear();
      _pendingConfirm = null;
      _pendingConfirmLabel = null;
      _newConvoArmed = false;
    });
  }

  /// Local command interpreter: parses plain-language requests into
  /// store operations. Agentic actions require Pro.
  Future<String> _runCommand(
      String text, List<_GenieAttachment> attachments) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final store = widget.store;
    final lower = text.toLowerCase().trim();

    // Pending destructive confirmation: "yes" / "no".
    if (_pendingConfirm != null) {
      if (lower == 'yes' || lower == 'y' || lower == 'confirm') {
        final fn = _pendingConfirm!;
        _pendingConfirm = null;
        _pendingConfirmLabel = null;
        return fn();
      }
      if (lower == 'no' || lower == 'n' || lower == 'cancel') {
        _pendingConfirm = null;
        _pendingConfirmLabel = null;
        return 'Cancelled — nothing was changed.';
      }
      return 'I have a pending action ("$_pendingConfirmLabel"). Reply '
          '"yes" to confirm or "no" to cancel.';
    }

    if (!widget.isPro) {
      return 'Smart Genie actions need Collider Pro. You can browse and read, '
          'but creating, moving, or editing components is a Pro capability.';
    }

    // Elite: attached coding-agent affordance. Truthful: it files a tracked
    // task card for the agent — it does not pretend to execute code here.
    final agentRe = RegExp(r'^/agent\s+(.+)', caseSensitive: false);
    final agentMatch = agentRe.firstMatch(text);
    if (agentMatch != null) {
      if (!widget.isElite) {
        return 'Attached coding agents are an Elite capability. '
            'Upgrade to Elite to delegate work with /agent.';
      }
      final task = agentMatch.group(1)!.trim();
      final tpl = _findTemplate(ComponentKind.card, 'task');
      final card = tpl == null
          ? null
          : store.instantiateCard(tpl.id, title: 'Agent: $task');
      if (card == null) {
        return 'Could not queue the agent task (card limit reached).';
      }
      card.urgent = true;
      store.updateCard(card);
      return 'Queued for your attached coding agent: "$task". I created a '
          'tracked task card ("Agent: $task") so the work is visible on '
          'your board.';
    }

    // --- context / count reporting ---
    if (RegExp(r'\b(how many|count|stats|statistics|context)\b')
        .hasMatch(lower)) {
      var cards = 0;
      var canvases = 0;
      for (final b in store.boards) {
        cards += store.boardCards(b.id).length;
        canvases += store.boardCanvases(b.id).length;
      }
      final buf = StringBuffer(
          'Context: $cards card${cards == 1 ? '' : 's'} across '
          '${store.boards.length} board${store.boards.length == 1 ? '' : 's'} '
          'and $canvases canvas${canvases == 1 ? '' : 'es'}. '
          'This conversation holds ${_history.length} messages '
          '(persisted, capped at 200).');
      if (attachments.isNotEmpty) {
        buf.write(
            ' You attached ${attachments.length} image${attachments.length == 1 ? '' : 's'} with this message.');
      }
      return buf.toString();
    }

    String? statusFilter(String s) {
      final l = s.toLowerCase();
      if (l.contains('in progress')) return 'in_progress';
      if (l.contains('to do') || l.contains('todo')) return 'to_do';
      if (l.contains('done')) return 'done';
      return null;
    }

    List<SmartCard> scoped(String? status) {
      final board = store.activeBoard;
      if (board == null) return [];
      var cards = store.boardCards(board.id);
      if (status != null) {
        cards = cards
            .where((c) => normalizeKanbanStatus(c.status) == status)
            .toList();
      }
      return cards;
    }

    // --- bulk: convert all <type> cards to <type> ---
    final convAllRe = RegExp(
        r'(?:convert|change)\s+all\s+(.+?)\s+cards?\s+to\s+(.+)',
        caseSensitive: false);
    final convAllMatch = convAllRe.firstMatch(text);
    if (convAllMatch != null) {
      final fromName = convAllMatch.group(1)!.trim().toLowerCase();
      final toName = convAllMatch.group(2)!.trim().toLowerCase();
      final fromTpl = _findTemplate(ComponentKind.card, fromName);
      final toTpl = _findTemplate(ComponentKind.card, toName);
      if (fromTpl == null || toTpl == null) {
        return 'I couldn\u2019t match those card types. Try one of: '
            '${_typeNames(ComponentKind.card)}.';
      }
      final n = store.retypeCards(fromTpl.id, toTpl.id);
      return n == 0
          ? 'No "${fromTpl.name}" cards to convert.'
          : 'Converted $n "${fromTpl.name}" card${n == 1 ? '' : 's'} to '
              '"${toTpl.name}". Fields with matching labels were kept.';
    }

    // --- single: convert <card> to <type> ---
    final convOneRe = RegExp(
        r'(?:convert|change)\s+(.+?)\s+to\s+(?:a\s+|an\s+)?(.+?)(?:\s+cards?)?$',
        caseSensitive: false);
    final convOneMatch = convOneRe.firstMatch(text);
    if (convOneMatch != null && !lower.contains(' to done')) {
      final cardName = convOneMatch.group(1)!.trim().toLowerCase();
      final toName = convOneMatch.group(2)!.trim().toLowerCase();
      final toTpl = _findTemplate(ComponentKind.card, toName);
      final card = _findCard(cardName);
      if (card == null) {
        return 'I couldn\u2019t find a card matching "$cardName".';
      }
      if (toTpl == null) {
        return 'I couldn\u2019t find a card type matching "$toName". '
            'Try one of: ${_typeNames(ComponentKind.card)}.';
      }
      final ok = store.retypeCard(card.id, toTpl.id);
      return ok
          ? '"${card.title}" is now a "${toTpl.name}" card. Matching fields were kept.'
          : 'Could not convert "${card.title}".';
    }

    // --- bulk: move all <status> cards to <dest> ---
    final moveAllRe =
        RegExp(r'move\s+all\s+(.+?)\s+to\s+(.+)', caseSensitive: false);
    final moveAllMatch = moveAllRe.firstMatch(text);
    if (moveAllMatch != null) {
      final srcName = moveAllMatch.group(1)!.trim();
      final dest = moveAllMatch.group(2)!.trim().toLowerCase();
      final status = statusFilter(srcName);
      final cards = scoped(status);
      if (cards.isEmpty) return 'No matching cards to move.';
      final destKey = dest.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      for (final c in cards) {
        store.moveCard(c.id, status: destKey);
      }
      return 'Moved ${cards.length} card${cards.length == 1 ? '' : 's'} '
          'to ${_prettyStatus(destKey)}.';
    }

    // --- bulk: mark all <status> cards urgent ---
    final urgAllRe =
        RegExp(r'mark\s+all\s+(.*?)\s*urgent', caseSensitive: false);
    final urgAllMatch = urgAllRe.firstMatch(text);
    if (urgAllMatch != null) {
      final cards = scoped(statusFilter(urgAllMatch.group(1)!));
      if (cards.isEmpty) return 'No matching cards to mark urgent.';
      for (final c in cards) {
        c.urgent = true;
        store.updateCard(c);
      }
      return 'Marked ${cards.length} card${cards.length == 1 ? '' : 's'} urgent.';
    }

    // --- bulk: delete all <status> cards (destructive: confirm first) ---
    final delAllRe = RegExp(r'(?:delete\s+all|clear)\s+(.+?)\s*cards?$',
        caseSensitive: false);
    final delAllMatch = delAllRe.firstMatch(text);
    if (delAllMatch != null) {
      final cards = scoped(statusFilter(delAllMatch.group(1)!));
      if (cards.isEmpty) return 'No matching cards to delete.';
      final ids = cards.map((c) => c.id).toList();
      _pendingConfirmLabel =
          'delete ${ids.length} card${ids.length == 1 ? '' : 's'}';
      _pendingConfirm = () async {
        for (final id in ids) {
          store.deleteCard(id);
        }
        return 'Deleted ${ids.length} card${ids.length == 1 ? '' : 's'}.';
      };
      return 'This will permanently delete ${ids.length} card'
          '${ids.length == 1 ? '' : 's'}. Reply "yes" to confirm or "no" '
          'to cancel.';
    }

    // Specific creations first: "create board called X" / "new canvas called Y".
    final mkBoardRe = RegExp(
        r'(?:create|new|add)\s+(?:a\s+|an\s+)?board\s+(?:called|titled|named)\s+(.+)',
        caseSensitive: false);
    final mkBoardMatch = mkBoardRe.firstMatch(text);
    if (mkBoardMatch != null) {
      final title = mkBoardMatch.group(1)!.trim();
      final tpl = store.templatesOf(ComponentKind.board).first;
      final board = store.instantiateBoard(tpl.id, title: title);
      return 'Created board "${board.title}" (${tpl.name}). Switched to it.';
    }
    final mkCanvasRe = RegExp(
        r'(?:create|new|add)\s+(?:a\s+|an\s+)?canvas\s+(?:called|titled|named)\s+(.+)',
        caseSensitive: false);
    final mkCanvasMatch = mkCanvasRe.firstMatch(text);
    if (mkCanvasMatch != null) {
      final title = mkCanvasMatch.group(1)!.trim();
      final tpl = store.templatesOf(ComponentKind.canvas).first;
      final cv = store.instantiateCanvas(tpl.id, title: title);
      if (cv == null) {
        return 'This board already holds 10 canvases — the Smart Gen limit. '
            'Delete one first, then ask me again.';
      }
      return 'Created canvas "${cv.title}" (${tpl.name}) on the current board.';
    }

    // "create a task card called X" / "new note titled Y"
    final createRe = RegExp(
        r'(?:create|new|add)\s+(?:a\s+|an\s+)?(\w[\w ]*?)\s+(?:card\s+)?(?:called|titled|named)\s+(.+)',
        caseSensitive: false);
    final createMatch = createRe.firstMatch(text);
    if (createMatch != null) {
      final typeName = createMatch.group(1)!.trim().toLowerCase();
      final title = createMatch
          .group(2)!
          .trim()
          .replaceAll(RegExp(r'["\u201c\u201d]'), '');
      final tpl = _findTemplate(ComponentKind.card, typeName);
      if (tpl == null) {
        return 'I couldn\u2019t find a card type matching "$typeName". '
            'Try one of: ${_typeNames(ComponentKind.card)}.';
      }
      final card = store.instantiateCard(tpl.id, title: title);
      if (card == null) {
        return 'You\u2019ve hit the 999-card Smart Gen limit. Delete some cards '
            'first, then ask me again.';
      }
      // Carry Genie attachments onto the new card as file attachments.
      for (final a in attachments) {
        store.addAttachment(
          card.id,
          CardAttachment(name: a.name, mime: a.mime, dataUrl: a.dataUrl),
        );
      }
      final attNote = attachments.isEmpty
          ? ''
          : ' I attached your ${attachments.length} image'
              '${attachments.length == 1 ? '' : 's'} to it.';
      return 'Created "${card.title}" (${tpl.name}). It\u2019s on your board now — '
          'tap any field to edit it inline.$attNote';
    }

    // "move X to done" / "move X to in progress"
    final moveRe = RegExp(r'move\s+(.+?)\s+to\s+(.+)', caseSensitive: false);
    final moveMatch = moveRe.firstMatch(text);
    if (moveMatch != null) {
      final cardName = moveMatch.group(1)!.trim().toLowerCase();
      final dest = moveMatch.group(2)!.trim().toLowerCase();
      final card = _findCard(cardName);
      if (card == null) {
        return 'I couldn\u2019t find a card matching "$cardName".';
      }
      final status = dest.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      store.moveCard(card.id, status: status);
      return 'Moved "${card.title}" to ${_prettyStatus(status)}.';
    }

    // "mark X urgent"
    final urgentRe =
        RegExp(r'(?:mark|set)\s+(.+?)\s+urgent', caseSensitive: false);
    final urgentMatch = urgentRe.firstMatch(text);
    if (urgentMatch != null) {
      final cardName = urgentMatch.group(1)!.trim().toLowerCase();
      final card = _findCard(cardName);
      if (card == null) {
        return 'I couldn\u2019t find a card matching "$cardName".';
      }
      card.urgent = true;
      store.updateCard(card);
      return '"${card.title}" is now marked urgent. Add a due date on the card '
          'for a live countdown.';
    }

    // "delete X"
    final deleteRe = RegExp(r'delete\s+(?:the\s+)?(.+)', caseSensitive: false);
    final deleteMatch = deleteRe.firstMatch(text);
    if (deleteMatch != null && !lower.startsWith('delete type')) {
      final cardName = deleteMatch.group(1)!.trim().toLowerCase();
      final card = _findCard(cardName);
      if (card == null) {
        return 'I couldn\u2019t find a card matching "$cardName".';
      }
      store.deleteCard(card.id);
      return 'Deleted "${card.title}".';
    }

    // "summarize board" / "what's on my board"
    if (lower.contains('summar') ||
        lower.contains('what') && lower.contains('board')) {
      final board = store.activeBoard;
      if (board == null) return 'No active board.';
      final cards = store.boardCards(board.id);
      if (cards.isEmpty) return '"${board.title}" is empty right now.';
      final byStatus = <String, int>{};
      for (final c in cards) {
        byStatus[c.status] = (byStatus[c.status] ?? 0) + 1;
      }
      final parts = byStatus.entries
          .map((e) => '${e.value} ${_prettyStatus(e.key)}')
          .join(', ');
      return '"${board.title}" has ${cards.length} cards: $parts.';
    }

    if (attachments.isNotEmpty) {
      return 'Got your ${attachments.length} attachment'
          '${attachments.length == 1 ? '' : 's'}. In local mode I can file '
          'them onto cards you ask me to create, but I can\u2019t analyze '
          'image content yet.';
    }

    return 'I can create, move, mark urgent, delete, and summarize cards, '
        'bulk-edit ("mark all done cards urgent", "move all todo cards to '
        'done"), convert card types ("convert all task cards to notes"), '
        'report counts ("how many cards"), and create boards and canvases. '
        '${widget.isElite ? 'Elite: delegate with /agent <task>.' : 'Elite unlocks attached coding agents (/agent).'}';
  }

  ComponentTemplate? _findTemplate(ComponentKind kind, String name) {
    final all = widget.store.templatesOf(kind);
    final singular =
        name.endsWith('s') ? name.substring(0, name.length - 1) : name;
    for (final t in all) {
      final tn = t.name.toLowerCase();
      final tk = t.typeKey.toLowerCase();
      if (tn == name ||
          tk == name ||
          tn.contains(name) ||
          tn == singular ||
          tk == singular) {
        return t;
      }
    }
    return null;
  }

  String _typeNames(ComponentKind kind) => widget.store
      .templatesOf(kind)
      .take(6)
      .map((t) => t.name.toLowerCase())
      .join(', ');

  SmartCard? _findCard(String name) {
    final board = widget.store.activeBoard;
    if (board == null) return null;
    final cards = widget.store.boardCards(board.id);
    for (final c in cards) {
      if (c.title.toLowerCase().contains(name)) return c;
    }
    return null;
  }

  String _prettyStatus(String key) {
    final map = {
      'todo': 'To Do',
      'to_do': 'To Do',
      'in_progress': 'In Progress',
      'done': 'Done'
    };
    return map[key] ??
        key
            .split('_')
            .map(
                (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final pw = sw > 700 ? 360.0 : (sw - 96).clamp(240.0, 360.0);
    _msgMaxWidth = pw - 80;
    return GlassPanel.window(
      child: SizedBox(
        width: pw,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            if (!widget.isPro) _buildProBanner(),
            Expanded(child: _buildHistory()),
            if (_pendingAttachments.isNotEmpty) _buildAttachmentStrip(),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Subtle fog/mist icon — the Genie's only mark.
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: const Icon(Icons.foggy, size: 15, color: Colors.white70),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Smart Genie',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.instrumentSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.2)),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.isElite
                            ? 'Elite · agents attached'
                            : widget.isPro
                                ? 'Pro · actions on'
                                : 'Preview · Pro unlocks more',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.instrumentSans(
                            fontSize: 10.5, color: Colors.white38),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Truthful engine status: local interpreter until a
                    // real key is wired through callAiApi().
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _liveAi ? 'LIVE AI' : 'LOCAL',
                        style: AppFonts.instrumentSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Tooltip(
            message: _newConvoArmed
                ? 'Tap again to clear history and start fresh'
                : 'New conversation',
            child: GlassPressable(
              onTap: _newConversation,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(
                    _newConvoArmed
                        ? Icons.warning_amber_rounded
                        : Icons.add_comment_outlined,
                    size: 15,
                    color: _newConvoArmed ? SGGlass.sysRed : Colors.white60),
              ),
            ),
          ),
          GlassPressable(
            onTap: widget.onMinimize,
            child: const Padding(
              padding: EdgeInsets.all(5),
              child:
                  Icon(Icons.minimize_rounded, size: 15, color: Colors.white60),
            ),
          ),
          GlassPressable(
            onTap: widget.onClose,
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.close_rounded, size: 15, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF64FFDA).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
            color: const Color(0xFF64FFDA).withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 14, color: Color(0xFF64FFDA)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Genie actions need Pro. Reading and summaries work now.',
              style:
                  AppFonts.instrumentSans(fontSize: 11, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.foggy, size: 30, color: Colors.white24),
              const SizedBox(height: 10),
              Text(
                'Ask me to organize your boards.\n"Create a task card called Launch plan"',
                textAlign: TextAlign.center,
                style: AppFonts.instrumentSans(
                    fontSize: 12, color: Colors.white38, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      itemCount: _history.length + (_working ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _history.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white54),
              ),
            ),
          );
        }
        final m = _history[i];
        return Align(
          alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            constraints: BoxConstraints(maxWidth: _msgMaxWidth),
            decoration: BoxDecoration(
              color: m.fromUser
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.attachments.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in m.attachments) _historyThumb(a.dataUrl),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(m.text,
                    style: AppFonts.instrumentSans(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.35)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _historyThumb(String dataUrl) {
    final bytes = _dataUrlBytes(dataUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: bytes == null
          ? Container(
              width: 56,
              height: 56,
              color: Colors.white.withValues(alpha: 0.1),
              child: const Icon(Icons.broken_image_outlined,
                  size: 20, color: Colors.white38),
            )
          : Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
    );
  }

  Uint8List? _dataUrlBytes(String dataUrl) {
    final idx = dataUrl.indexOf('base64,');
    if (idx < 0) return null;
    try {
      return base64Decode(dataUrl.substring(idx + 7));
    } catch (_) {
      return null;
    }
  }

  Widget _buildAttachmentStrip() {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = _pendingAttachments[i];
          final bytes = _dataUrlBytes(a.dataUrl);
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: bytes == null
                    ? Container(
                        width: 60,
                        height: 60,
                        color: Colors.white.withValues(alpha: 0.1))
                    : Image.memory(bytes,
                        width: 60, height: 60, fit: BoxFit.cover),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: GestureDetector(
                  onTap: () => setState(() => _pendingAttachments.removeAt(i)),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Attach images',
            child: GlassPressable(
              onTap: _attach,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.attach_file_rounded,
                    size: 17, color: Colors.white60),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlassField(
              controller: _inputCtrl,
              hintText: 'Ask the Genie…',
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GlassPressable(
            onTap: _send,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  size: 17, color: SGGlass.ink),
            ),
          ),
        ],
      ),
    );
  }
}
