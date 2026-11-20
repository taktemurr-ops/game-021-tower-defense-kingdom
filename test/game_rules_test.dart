import 'package:flutter_test/flutter_test.dart';
import 'package:game_021_tower_defense_kingdom/core/arcade.dart';
import 'package:game_021_tower_defense_kingdom/core/level_plan.dart';
import 'package:game_021_tower_defense_kingdom/game/rules.dart';
import 'package:game_021_tower_defense_kingdom/game/td_engine.dart';

void main() {
  final rules = TdRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('path runs from the top row to the bottom row in 4-connected steps', () {
    for (var n = 1; n < 60; n += 7) {
      final p = rules.build(planner.spec(n)).puzzle.path;
      expect(p.first.y, 0);
      expect(p.last.y, kRows - 1);
      for (var i = 1; i < p.length; i++) {
        expect((p[i].x - p[i - 1].x).abs() + (p[i].y - p[i - 1].y).abs(), 1);
      }
      expect(p.toSet().length, p.length, reason: 'no self crossing');
    }
  });

  test('towers cannot be built on the road and cost gold', () {
    final s = TdSim(rules.build(planner.spec(1)).puzzle);
    final road = s.level.path[3];
    expect(s.build(0, road.x, road.y), isFalse);
    final g = s.gold;
    var placed = false;
    for (var c = 0; c < kCols && !placed; c++) {
      if (s.canBuild(c, 5)) placed = s.build(0, c, 5);
    }
    expect(placed, isTrue);
    expect(s.gold, g - towerTypes[0].cost);
  });

  test('tapping a tower upgrades it and increases its damage', () {
    final s = TdSim(rules.build(planner.spec(1)).puzzle);
    s.gold = 10000;
    var c = 0;
    while (!s.canBuild(c, 6)) {
      c++;
    }
    s.build(0, c, 6);
    final d1 = s.towers.first.damage;
    s.tick(ArcadeInput(tap: true, down: true, x: c * kCell + 50, y: kGridTop + 6 * kCell + 50));
    expect(s.towers.first.level, 2);
    expect(s.towers.first.damage, greaterThan(d1));
  });

  test('leaking enemies damage the castle; at zero the round is lost', () {
    final s = TdSim(rules.build(planner.spec(1)).puzzle);
    for (var t = 0; t < 60 * 120 && !s.over; t++) {
      s.tick(ArcadeInput.idle);
    }
    expect(s.leaks, greaterThan(0));
    expect(s.dead, isTrue);
    s.revive();
    expect(s.castle, 10);
    expect(s.over, isFalse);
  });

  test('meteor booster damages all enemies', () {
    final s = TdSim(rules.build(planner.spec(1)).puzzle);
    for (var t = 0; t < 60 * 9; t++) {
      s.tick(ArcadeInput.idle);
    }
    expect(s.enemies, isNotEmpty);
    final hp = s.enemies.map((e) => e.hp).toList();
    s.useBooster();
    for (var i = 0; i < s.enemies.length && i < hp.length; i++) {
      expect(s.enemies[i].hp, lessThan(hp[i]));
    }
  });
}
