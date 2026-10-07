import 'package:flutter/material.dart';
import '../../../core/vision/vision_kit.dart';

/// Pinned consensus header of the response stack: ratio capsule, chevron,
/// and the full consensus summary (wrapped, never truncated or shrunk).
class ConsensusRow extends StatelessWidget {
  final String agreementRatio;
  final String summary;
  final bool isGenerating;
  final VoidCallback? onGenerateConsensus;
  final VoidCallback? onTap;

  const ConsensusRow({
    super.key,
    required this.agreementRatio,
    required this.summary,
    this.onGenerateConsensus,
    this.onTap,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = agreementRatio.contains('Consensus') ? agreementRatio : '$agreementRatio Consensus';
    return VPress(
      onTap: onTap ?? onGenerateConsensus,
      child: Container(
        padding: const EdgeInsets.fromLTRB(VSpace.sm, 10, VSpace.xs, VSpace.sm),
        decoration: BoxDecoration(
          color: VColors.glassElevated,
          borderRadius: BorderRadius.circular(VRadius.lg - 4),
          border: Border.all(color: VColors.borderHeavy, width: 0.5),
          boxShadow: VShadow.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: VColors.fillActive, borderRadius: BorderRadius.circular(VRadius.full)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.balance_rounded, size: 14, color: VColors.textPrimary),
                      const SizedBox(width: 6),
                      Text(label, style: VType.callout(weight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(isGenerating ? Icons.sync_rounded : Icons.chevron_right_rounded, size: 20, color: VColors.textTertiary),
              ],
            ),
            if (isGenerating) ...[
              const SizedBox(height: VSpace.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(VRadius.full),
                child: const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: VColors.fillCell,
                  valueColor: AlwaysStoppedAnimation<Color>(VColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: VSpace.xs),
            AnimatedSwitcher(
              duration: VMotion.base,
              layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, if (cur != null) cur]),
              child: Text(summary, key: ValueKey(summary), style: VType.callout(weight: FontWeight.w500).copyWith(height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}
