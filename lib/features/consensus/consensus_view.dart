// Dart port of collidermergedx3-glm src/services/consensusView.ts
// (Consensus Framework v3). Arithmetic only, kept line-for-line with the
// source so the scene receives the same payload the source app sends.
import 'dart:math' as math;

String matchKey(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

/// §3: structural mass, earned by reasoning. 30 + chains x 10 (revised 2026-08-08).
int sphereSize(int chains) => (30 + math.max(0, chains) * 10).round();

class ConsensusClaim {
  final String modelId;
  final String essence;
  final int chains;
  const ConsensusClaim({required this.modelId, required this.essence, required this.chains});
}

class ConsensusResult {
  final List<ConsensusClaim> claims;
  final List<List<String>> groups;
  final Map<String, int> matches;
  final List<String>? tieBreakGroup;
  final String? tieBreakBecause;
  final String need;
  final bool degraded;
  const ConsensusResult({
    required this.claims,
    this.groups = const [],
    this.matches = const {},
    this.tieBreakGroup,
    this.tieBreakBecause,
    this.need = '',
    this.degraded = false,
  });
}

class DerivedClaim {
  final ConsensusClaim claim;
  final bool inConsensus;
  final int size;
  const DerivedClaim(this.claim, this.inConsensus, this.size);
  String get modelId => claim.modelId;
  int get chains => claim.chains;
  String get essence => claim.essence;
}

class Derived {
  final List<DerivedClaim> claims;
  final List<String> consensus;
  final String summary;
  final String need;
  final List<DerivedClaim> dissent;
  final int ratioN;
  final int ratioM;
  final double ratio;
  final int nucleusChains;
  final int nucleusSize;
  final double glowOpacity;
  final int glowRadius;
  final String? tieBecause;
  final bool degraded;
  const Derived({
    required this.claims,
    required this.consensus,
    required this.summary,
    required this.need,
    required this.dissent,
    required this.ratioN,
    required this.ratioM,
    required this.ratio,
    required this.nucleusChains,
    required this.nucleusSize,
    required this.glowOpacity,
    required this.glowRadius,
    required this.tieBecause,
    required this.degraded,
  });
}

bool _sameSet(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final sa = [...a]..sort();
  final sb = [...b]..sort();
  return sa.join('|') == sb.join('|');
}

/// Consensus = the largest group. Summary = the winning essence, verbatim.
Derived? deriveConsensus(ConsensusResult? result) {
  if (result == null || result.claims.isEmpty) return null;
  final byId = {for (final c in result.claims) c.modelId: c};
  final groups = result.groups
      .map((g) => g.where(byId.containsKey).toList())
      .where((g) => g.isNotEmpty)
      .toList();
  final placed = groups.expand((g) => g).toSet();
  for (final c in result.claims) {
    if (!placed.contains(c.modelId)) groups.add([c.modelId]);
  }

  final maxLen = groups.fold<int>(0, (m, g) => math.max(m, g.length));
  final tied = groups.where((g) => g.length == maxLen).toList();
  var winner = tied.first;
  String? tieBecause;
  if (tied.length > 1 && result.tieBreakGroup != null) {
    for (final g in tied) {
      if (_sameSet(g, result.tieBreakGroup!)) {
        winner = g;
        tieBecause = result.tieBreakBecause;
        break;
      }
    }
  }

  final inWinner = winner.toSet();
  final claims = result.claims
      .map((c) => DerivedClaim(c, inWinner.contains(c.modelId), sphereSize(c.chains)))
      .toList();
  final members = claims.where((c) => c.inConsensus).toList();
  final nucleusChains = members.fold<int>(0, (m, c) => math.max(m, c.chains));
  final deepest = members.isEmpty
      ? null
      : members.reduce((best, c) => c.chains > best.chains ? c : best);

  final ratioN = winner.length;
  final ratioM = result.claims.length;
  final ratio = ratioM > 0 ? ratioN / ratioM : 0.0;

  return Derived(
    claims: claims,
    consensus: winner,
    summary: deepest?.essence ?? '',
    need: result.need,
    dissent: claims.where((c) => !c.inConsensus).toList(),
    ratioN: ratioN,
    ratioM: ratioM,
    ratio: ratio,
    nucleusChains: nucleusChains,
    nucleusSize: sphereSize(nucleusChains),
    glowOpacity: 0.15 + ratio * 0.55,
    glowRadius: (14 + ratio * 36).round(),
    tieBecause: tieBecause,
    degraded: result.degraded,
  );
}

class Placed {
  final String modelId;
  final double x;
  final double y;
  final bool unanchored;
  final int linksToConsensus;
  final bool inConsensus;
  const Placed({
    required this.modelId,
    required this.x,
    required this.y,
    required this.unanchored,
    required this.linksToConsensus,
    required this.inConsensus,
  });
}

class Field {
  final double width, height, centerX, centerY, innerR, outerR;
  const Field({
    required this.width,
    required this.height,
    required this.centerX,
    required this.centerY,
    required this.innerR,
    required this.outerR,
  });
}

/// §6: position follows from link counts. Angle = cluster, radius = links shared.
List<Placed> layoutByMatches(Derived d, ConsensusResult result, Field field) {
  int pull(String a, String b) => result.matches[matchKey(a, b)] ?? 0;
  final centerX = field.centerX, centerY = field.centerY;
  final innerR = field.innerR, outerR = field.outerR;

  final groupOf = <String, int>{};
  for (var i = 0; i < result.groups.length; i++) {
    for (final id in result.groups[i]) {
      groupOf[id] = i;
    }
  }
  final outsiders = d.claims.where((c) => !c.inConsensus).toList();

  final clusters = <List<String>>[];
  final clusterIndex = <String, int>{};
  for (final c in outsiders) {
    final key = groupOf.containsKey(c.modelId) ? 'g${groupOf[c.modelId]}' : 's${c.modelId}';
    var idx = clusterIndex[key];
    if (idx == null) {
      idx = clusters.length;
      clusterIndex[key] = idx;
      clusters.add([]);
    }
    clusters[idx].add(c.modelId);
  }

  int linksBetween(List<String> a, List<String> b) =>
      a.fold(0, (sum, x) => sum + b.fold(0, (s, y) => s + pull(x, y)));
  final order = <int>[];
  final remaining = List<int>.generate(clusters.length, (i) => i);
  while (remaining.isNotEmpty) {
    if (order.isEmpty) {
      order.add(remaining.removeAt(0));
      continue;
    }
    final last = clusters[order.last];
    var bestAt = 0;
    var bestLinks = -1;
    for (var at = 0; at < remaining.length; at++) {
      final l = linksBetween(last, clusters[remaining[at]]);
      if (l > bestLinks) {
        bestLinks = l;
        bestAt = at;
      }
    }
    order.add(remaining.removeAt(bestAt));
  }

  int linksToConsensus(String id) =>
      d.consensus.fold(0, (sum, cid) => cid == id ? sum : sum + pull(id, cid));

  final maxLinks = outsiders
      .where((c) => c.chains > 0)
      .map((c) => linksToConsensus(c.modelId))
      .fold<int>(0, math.max);

  int? chainsOf(String id) {
    for (final c in d.claims) {
      if (c.modelId == id) return c.chains;
    }
    return null;
  }

  final placed = <Placed>[];
  for (var i = 0; i < d.consensus.length; i++) {
    final id = d.consensus[i];
    final a = (-math.pi / 2) + (i * 2 * math.pi) / math.max(d.consensus.length, 1);
    placed.add(Placed(
      modelId: id,
      x: centerX + math.cos(a) * innerR,
      y: centerY + math.sin(a) * innerR * 0.72,
      unanchored: (chainsOf(id) ?? 0) == 0,
      linksToConsensus: 0,
      inConsensus: true,
    ));
  }

  final sectors = math.max(order.length, 1);
  for (var slot = 0; slot < order.length; slot++) {
    final ci = order[slot];
    final base = math.pi / 2 + (slot * 2 * math.pi) / sectors;
    final cluster = clusters[ci];
    for (var k = 0; k < cluster.length; k++) {
      final id = cluster[k];
      final claim = d.claims.firstWhere((c) => c.modelId == id);
      final links = linksToConsensus(id);
      final spread = cluster.length > 1 ? ((k - (cluster.length - 1) / 2) * 0.38) / sectors : 0.0;
      final a = base + spread * math.pi;
      final r = claim.chains == 0 || maxLinks == 0
          ? outerR
          : outerR - (links / maxLinks) * (outerR - innerR * 1.6);
      placed.add(Placed(
        modelId: id,
        x: centerX + math.cos(a) * r,
        y: centerY + math.sin(a) * r * 0.72,
        unanchored: claim.chains == 0,
        linksToConsensus: links,
        inConsensus: false,
      ));
    }
  }
  return placed;
}
