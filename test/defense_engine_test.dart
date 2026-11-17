import 'package:flutter_test/flutter_test.dart';
import 'package:game_021_tower_defense_kingdom/game/defense_engine.dart';

void main() {
  test('tower cost and duplicate prevention', () {
    final g = DefenseEngine();
    expect(g.buildTower(0), true);
    expect(g.gold, 60);
    expect(g.buildTower(0), false);
    expect(g.buildTower(1), true);
    expect(g.buildTower(2), false);
  });
  test('wave cannot overlap', () {
    final g = DefenseEngine();
    expect(g.startWave(), true);
    expect(g.startWave(), false);
    expect(g.wave, 1);
  });
  test('unopposed enemies escape and reduce lives', () {
    final g = DefenseEngine();
    g.startWave();
    for (var i = 0; i < 12; i++) { g.tick(); }
    expect(g.lives, 7);
    expect(g.enemies, isEmpty);
  });
  test('tower can defeat enemies and earn gold', () {
    final g = DefenseEngine();
    g.buildTower(1);
    g.startWave();
    for (var i = 0; i < 12; i++) { g.tick(); }
    expect(g.kills, greaterThan(0));
    expect(g.gold, greaterThan(60));
  });
  test('reset clears progression', () {
    final g = DefenseEngine();
    g.buildTower(1); g.startWave(); g.tick(); g.reset();
    expect(g.gold, 100); expect(g.wave, 0); expect(g.enemies, isEmpty);
  });
}
