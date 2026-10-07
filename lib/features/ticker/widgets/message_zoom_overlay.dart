import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import '../../../core/files/file_store.dart';
import '../../../models/ticker_item.dart';
import '../../../core/vision/vision_kit.dart';

/// REQ-19 Temporary Message Zoom Lightbox (Vision OS Design System 417:1777):
/// the message rises as the centred focus card with a floating action ornament
/// beneath it, over the dimmed environment. Escapes: scrim tap, close circle.
class MessageZoomOverlay extends StatelessWidget {
  final TickerMessage message;
  final String modelName;
  final Color providerColor;
  final VoidCallback onClose;
  final VoidCallback? onBranchIsolated;

  const MessageZoomOverlay({
    super.key,
    required this.message,
    required this.modelName,
    required this.providerColor,
    required this.onClose,
    this.onBranchIsolated,
  });

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      backgroundColor: VColors.glassDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.full)),
      content: Text(text, style: VType.callout()),
    ));
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    _toast(context, 'Message text copied');
  }

  // Save: the message as a Markdown file in Files, contents kept (D32).
  Future<void> _save(BuildContext context) async {
    final t = message.timestamp;
    String two(int n) => n.toString().padLeft(2, '0');
    final who = (message.sender == 'user' ? 'Prompt' : modelName).replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '').trim();
    final name = '$who ${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}${two(t.minute)}.md';
    final note = await FileStore.instance.addBytes(name, Uint8List.fromList(utf8.encode(message.text)), 'model');
    if (!context.mounted) return;
    if (note != null) {
      await showVAlert(context, icon: Icons.error_outline_rounded, title: note, actions: const [VAlertChoice('OK')]);
    } else {
      _toast(context, 'Saved to Files');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';
    final t = message.timestamp;
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final size = MediaQuery.of(context).size;

    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: onClose),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(VSpace.md, 40, VSpace.md, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: VOverlay.menuWidth(context), maxHeight: size.height * 0.42),
                    child: VGlass(
                      material: VMaterial.modal,
                      radius: VRadius.xl,
                      padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.md, VSpace.md, VSpace.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              VAvatar(label: isUser ? 'You' : modelName, color: isUser ? VColors.overlayLight : providerColor, size: 36),
                              const SizedBox(width: VSpace.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isUser ? 'Your Prompt' : modelName, style: VType.headline()),
                                    Text(time, style: VType.caption()),
                                  ],
                                ),
                              ),
                              VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: onClose),
                            ],
                          ),
                          const SizedBox(height: VSpace.sm),
                          Flexible(
                            child: VFadeScroll(
                              padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
                              child: MdText(message.text, style: VType.body().copyWith(fontSize: VType.md, height: 1.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: VSpace.md),
                  VOrnament(
                    padding: const EdgeInsets.all(VSpace.xs - 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Action(icon: Icons.copy_rounded, label: 'Copy', onTap: () => _copy(context)),
                        if (!isUser && onBranchIsolated != null)
                          _Action(
                            icon: Icons.fork_right_rounded,
                            label: 'Branch',
                            onTap: () {
                              onBranchIsolated?.call();
                              onClose();
                            },
                          ),
                        // v8.2 round 3 (D34): Save really saves (to Files); the
                        // Share action only copied, the same as Copy, so it is gone.
                        _Action(icon: Icons.bookmark_border_rounded, label: 'Save', onTap: () => _save(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(VRadius.full)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: VColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: VType.callout(color: VColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
