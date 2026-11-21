import 'dart:math' as math;

import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// Tower defense on a 10 x 13 grid. Enemies walk a generated path from the
/// top to the castle at the bottom; the player builds and upgrades towers.

const int kCols = 10;
const int kRows = 13;
const double kCell = 100;
const double kGridTop = 110;
const double kBarTop = kGridTop + kRows * kCell + 10; // 1420

class TowerType {
  final String tr, en;
  final int cost;
  final double range; // cells
  final double damage;
  final int cooldown; // ticks
  final double splash; // cells, 0 = single target
  final double slow; // 0..1
  final int color;
  const TowerType(this.tr, this.en, this.cost, this.range, this.damage, this.cooldown,
      {this.splash = 0, this.slow = 0, required this.color});
}

const towerTypes = [
  TowerType('Okçu', 'Archer', 50, 2.3, 9, 30, color: 0xFF7BD389),
  TowerType('Top', 'Cannon', 90, 2.0, 22, 80, splash: 0.9, color: 0xFFF4A261),
  TowerType('Buz', 'Frost', 70, 1.9, 3, 45, slow: 0.5, color: 0xFF8ECAE6),
  TowerType('Şimşek', 'Tesla', 150, 2.7, 46, 100, color: 0xFFB5179E),
];

class TdLevel {
  final ArcadeMeta meta;
  final List<math.Point<int>> path;
  final int waves; // 0 = endless
  final double hpMul;
  final bool armored, fast, swarm, boss, regen;
  final int startGold;
  const TdLevel({
    required this.meta,
    required this.path,
    required this.waves,
    required this.hpMul,
    required this.armored,
    required this.fast,
    required this.swarm,
    required this.boss,
    required this.regen,
    required this.startGold,
  });
}

List<math.Point<int>> generatePath(SeededRandom rng) {
  final pts = <math.Point<int>>[];
  var c = 1 + rng.nextInt(kCols - 2);
  var r = 0;
  pts.add(math.Point(c, r));
  while (r < kRows - 1) {
    // go down 1-2 rows
    final down = r >= kRows - 3 ? kRows - 1 - r : 1 + rng.nextInt(2);
    for (var i = 0; i < down && r < kRows - 1; i++) {
      r++;
      pts.add(math.Point(c, r));
    }
    if (r >= kRows - 1) break;
    // horizontal run to a new column
    var target = rng.nextInt(kCols);
    if ((target - c).abs() < 2) target = c < kCols / 2 ? math.min(kCols - 1, c + 3) : math.max(0, c - 3);
    while (c != target) {
      c += target > c ? 1 : -1;
      pts.add(math.Point(c, r));
    }
  }
  return pts;
}

TdLevel generateTdLevel(LevelSpec s) {
  final m = ArcadeMeta.of(s);
  final rng = SeededRandom(mixSeed([s.seed, 21]));
  final d = s.difficulty;
  return TdLevel(
    meta: m,
    path: generatePath(rng),
    waves: m.goal ? 8 + (d * 0.8).round() : 0,
    hpMul: 1 + (d - 1) * 0.06,
    armored: s.has('armored'),
    fast: s.has('fast'),
    swarm: s.has('swarm'),
    boss: s.has('boss') || d >= 7,
    regen: s.has('regen'),
    startGold: 170,
  );
}

class Enemy {
  final int kind; // 0 grunt, 1 runner, 2 knight, 3 boss
  double hp;
  final double maxHp;
  final double speed; // cells per second
  final double armor;
  double dist = 0; // along path, cells
  int slowTicks = 0;
  final int reward;
  Enemy(this.kind, this.hp, this.speed, this.armor, this.reward) : maxHp = hp;
}

class Tower {
  final int type;
  final int c, r;
  int level = 1;
  int cool = 0;
  int spent;
  Tower(this.type, this.c, this.r, this.spent);
  TowerType get t => towerTypes[type];
  double get range => t.range + (level - 1) * 0.25;
  double get damage => t.damage * math.pow(1.6, level - 1);
  int get upgradeCost => (t.cost * 0.8 * level).round();
}

class Beam {
  final double x1, y1, x2, y2;
  final int color;
  int life;
  Beam(this.x1, this.y1, this.x2, this.y2, this.color, this.life);
}

class TdSim extends ArcadeSim {
  final TdLevel level;
  late final Set<int> pathCells;
  final List<Enemy> enemies = [];
  final List<Tower> towers = [];
  final List<Beam> beams = [];
  int gold;
  int castle = 20;
  int wave = 0; // waves started
  int spawnLeft = 0;
  int spawnCool = 0;
  int breakTicks = 60 * 6;
  int selected = 0;
  int kills = 0, leaks = 0, built = 0, upgrades = 0, bossKills = 0;
  int lastEvent = 0; // 1 build, 2 kill, 3 leak, 4 wave, 5 upgrade, 6 denied

  TdSim(this.level)
      : gold = level.startGold,
        super(level.meta, lives: 1) {
    pathCells = {for (final p in level.path) p.y * kCols + p.x};
  }

  double get pathLen => (level.path.length - 1).toDouble();

  /// World position at [d] cells along the path.
  (double, double) posAt(double d) {
    final i = d.floor().clamp(0, level.path.length - 2);
    final f = (d - i).clamp(0.0, 1.0);
    final a = level.path[i], b = level.path[i + 1];
    final x = (a.x + (b.x - a.x) * f) * kCell + kCell / 2;
    final y = kGridTop + (a.y + (b.y - a.y) * f) * kCell + kCell / 2;
    return (x, y);
  }

  bool get waveRunning => spawnLeft > 0 || enemies.isNotEmpty;

  Tower? towerAt(int c, int r) {
    for (final t in towers) {
      if (t.c == c && t.r == r) return t;
    }
    return null;
  }

  bool canBuild(int c, int r) =>
      c >= 0 && c < kCols && r >= 0 && r < kRows && !pathCells.contains(r * kCols + c) && towerAt(c, r) == null;

  bool build(int type, int c, int r) {
    if (!canBuild(c, r) || gold < towerTypes[type].cost) {
      lastEvent = 6;
      return false;
    }
    gold -= towerTypes[type].cost;
    towers.add(Tower(type, c, r, towerTypes[type].cost));
    built++;
    score += 5;
    lastEvent = 1;
    return true;
  }

  bool upgrade(Tower t) {
    if (t.level >= 4 || gold < t.upgradeCost) {
      lastEvent = 6;
      return false;
    }
    gold -= t.upgradeCost;
    t.spent += t.upgradeCost;
    t.level++;
    upgrades++;
    score += 5;
    lastEvent = 5;
    return true;
  }

  void _startWave() {
    wave++;
    final n = 6 + wave * 2 + (level.swarm ? wave ~/ 2 + 1 : 0);
    spawnLeft = n;
    spawnCool = 0;
    lastEvent = 4;
  }

  /// Calls the next wave early for bonus gold.
  void callWave() {
    if (spawnLeft > 0 || (level.waves > 0 && wave >= level.waves)) return;
    gold += 10 + breakTicks ~/ 30;
    breakTicks = 0;
  }

  void _spawn() {
    final w = wave;
    final base = 26 * math.pow(1.21, w - 1) * level.hpMul;
    final idx = spawnLeft;
    int kind = 0;
    if (level.boss && w % 5 == 0 && idx == 1) {
      kind = 3;
    } else if ((level.fast || w >= 4) && idx % 4 == 0) {
      kind = 1;
    } else if ((level.armored || w >= 6) && idx % 5 == 2) {
      kind = 2;
    }
    final e = switch (kind) {
      1 => Enemy(1, base * 0.6, 2.8, 0, 6),
      2 => Enemy(2, base * 1.6, 1.3, 3 + w * 0.35, 10),
      3 => Enemy(3, base * 9, 1.0, 3, 60),
      _ => Enemy(0, base, 1.8, 0, 5),
    };
    enemies.add(e);
    spawnLeft--;
    spawnCool = level.swarm ? 20 : 30;
  }

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (input.tap && input.hasPointer) _tap(input.x, input.y);
    // waves
    if (spawnLeft == 0 && enemies.isEmpty) {
      if (level.waves > 0 && wave >= level.waves) {
        win();
        return;
      }
      if (breakTicks > 0) {
        breakTicks--;
      } else {
        if (wave > 0) gold += 20 + wave * 3;
        _startWave();
        breakTicks = 60 * 4;
      }
    }
    if (spawnLeft > 0) {
      if (spawnCool > 0) {
        spawnCool--;
      } else {
        _spawn();
      }
    }
    // move
    for (final e in [...enemies]) {
      final sp = e.speed * (e.slowTicks > 0 ? 0.5 : 1);
      if (e.slowTicks > 0) e.slowTicks--;
      e.dist += sp * kDt;
      if (level.regen && e.hp < e.maxHp) e.hp = math.min(e.maxHp, e.hp + e.maxHp * 0.006 * kDt);
      if (e.dist >= pathLen) {
        enemies.remove(e);
        leaks++;
        castle -= e.kind == 3 ? 5 : 1;
        lastEvent = 3;
        if (castle <= 0) {
          castle = 0;
          hit();
          if (over) return;
        }
      }
    }
    // shoot
    for (final t in towers) {
      if (t.cool > 0) {
        t.cool--;
        continue;
      }
      final tx = t.c * kCell + kCell / 2, ty = kGridTop + t.r * kCell + kCell / 2;
      final rr = t.range * kCell;
      Enemy? target;
      for (final e in enemies) {
        final (x, y) = posAt(e.dist);
        if ((x - tx) * (x - tx) + (y - ty) * (y - ty) <= rr * rr) {
          if (target == null || e.dist > target.dist) target = e;
        }
      }
      if (target == null) continue;
      t.cool = t.t.cooldown;
      final (ex, ey) = posAt(target.dist);
      beams.add(Beam(tx, ty, ex, ey, t.t.color, 8));
      if (t.t.splash > 0) {
        final sr = t.t.splash * kCell;
        for (final e in [...enemies]) {
          final (x, y) = posAt(e.dist);
          if ((x - ex) * (x - ex) + (y - ey) * (y - ey) <= sr * sr) _damage(e, t.damage);
        }
      } else {
        _damage(target, t.damage);
        if (t.t.slow > 0) target.slowTicks = 90 + t.level * 20;
      }
    }
    for (final b in [...beams]) {
      if (--b.life <= 0) beams.remove(b);
    }
  }

  void _damage(Enemy e, double dmg) {
    if (!enemies.contains(e)) return;
    e.hp -= math.max(dmg * 0.25, dmg - e.armor);
    if (e.hp <= 0) {
      enemies.remove(e);
      kills++;
      if (e.kind == 3) bossKills++;
      gold += e.reward;
      score += e.reward;
      lastEvent = 2;
    }
  }

  void _tap(double x, double y) {
    if (y >= kBarTop) {
      final i = (x / 200).floor();
      if (i >= 0 && i < 4) {
        selected = i;
      } else if (i == 4) {
        callWave();
      }
      return;
    }
    if (y < kGridTop) return;
    final c = (x / kCell).floor(), r = ((y - kGridTop) / kCell).floor();
    final t = towerAt(c, r);
    if (t != null) {
      upgrade(t);
    } else {
      build(selected, c, r);
    }
  }

  @override
  void onLifeLost() {}

  @override
  void revive() {
    super.revive();
    castle = 10;
    enemies.clear();
    spawnLeft = 0;
  }

  /// Booster: meteor strike damages every enemy on the field.
  @override
  bool useBooster() {
    if (over) return false;
    for (final e in [...enemies]) {
      _damage(e, e.maxHp * 0.6 + 40);
    }
    lastEvent = 2;
    return true;
  }

  @override
  double get progress => level.waves == 0 ? 0 : (wave - (waveRunning ? 1 : 0)) / level.waves;

  @override
  String get goalText => level.waves == 0 ? '$wave' : '$wave/${level.waves}';

  @override
  Map<String, int> get stats => {
        'enemies_defeated': kills,
        'towers_built': built,
        'waves_survived': math.max(0, wave - (waveRunning ? 1 : 0)),
        'bosses_defeated': bossKills,
      };

  @override
  int get stars {
    if (!won) return 0;
    final s = castle >= 18 ? 3 : (castle >= 10 ? 2 : 1);
    return (s - revives).clamp(1, 3);
  }
}

/// Coverage of path cells for a tower placed at (c, r) with range [range].
int coverage(TdSim s, int c, int r, double range) {
  var n = 0;
  final rr = range * range;
  for (final p in s.level.path) {
    final dx = (p.x - c).toDouble(), dy = (p.y - r).toDouble();
    if (dx * dx + dy * dy <= rr) n++;
  }
  return n;
}

ArcadeInput tdBot(ArcadeSim sim) {
  final s = sim as TdSim;
  if (s.ticks % 6 != 0) return ArcadeInput.idle;
  // What to build next.
  final counts = List.filled(4, 0);
  for (final t in s.towers) {
    counts[t.type]++;
  }
  int want;
  if (s.towers.length < 3) {
    want = 0;
  } else if (counts[2] * 5 < s.towers.length) {
    want = 2;
  } else if (counts[1] * 3 < s.towers.length) {
    want = 1;
  } else if (s.wave >= 6 && counts[3] * 4 < s.towers.length) {
    want = 3;
  } else {
    want = 0;
  }
  // Enough towers for this wave => upgrade the weakest one.
  if (s.towers.length >= 5 + s.wave) {
    Tower? best;
    for (final t in s.towers) {
      if (t.level < 4 && (best == null || t.level < best.level || (t.level == best.level && coverage(s, t.c, t.r, t.range) > coverage(s, best.c, best.r, best.range)))) {
        best = t;
      }
    }
    if (best != null) {
      if (s.gold >= best.upgradeCost) return _tapCell(best.c, best.r);
      if (!s.waveRunning && s.wave > 0 && s.breakTicks > 60) {
        return const ArcadeInput(tap: true, down: true, x: 900, y: kBarTop + 80);
      }
      return ArcadeInput.idle;
    }
  }
  if (s.gold < towerTypes[want].cost) {
    // Nothing to buy: call the next wave early for bonus gold.
    if (!s.waveRunning && s.wave > 0 && s.breakTicks > 60) {
      return const ArcadeInput(tap: true, down: true, x: 900, y: kBarTop + 80);
    }
    return ArcadeInput.idle;
  }
  if (s.selected != want) {
    return ArcadeInput(tap: true, down: true, x: want * 200 + 100, y: kBarTop + 80);
  }
  var bc = -1, br = -1, bv = 0;
  for (var r = 0; r < kRows; r++) {
    for (var c = 0; c < kCols; c++) {
      if (!s.canBuild(c, r)) continue;
      // Prefer spots near the castle end for slow / splash.
      final v = coverage(s, c, r, towerTypes[want].range) * 10 + r;
      if (v > bv) {
        bv = v;
        bc = c;
        br = r;
      }
    }
  }
  if (bc < 0) return ArcadeInput.idle;
  return _tapCell(bc, br);
}

ArcadeInput _tapCell(int c, int r) =>
    ArcadeInput(tap: true, down: true, x: c * kCell + kCell / 2, y: kGridTop + r * kCell + kCell / 2);
