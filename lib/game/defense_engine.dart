class Enemy {
  int position;
  int hp;
  Enemy({this.position = 0, this.hp = 3});
}

class DefenseEngine {
  int gold = 100;
  int lives = 10;
  int wave = 0;
  int kills = 0;
  final Set<int> towers = {};
  final List<Enemy> enemies = [];
  bool get gameOver => lives <= 0;
  bool get canStartWave => !gameOver && enemies.isEmpty;
  bool buildTower(int cell) {
    if (gameOver || gold < 40 || cell < 0 || cell >= 12 || towers.contains(cell)) return false;
    towers.add(cell);
    gold -= 40;
    return true;
  }
  bool startWave() {
    if (!canStartWave) return false;
    wave++;
    enemies.addAll(List.generate(wave + 2, (_) => Enemy(hp: 2 + wave)));
    return true;
  }
  void tick() {
    if (gameOver) return;
    final escaped = <Enemy>[];
    final defeated = <Enemy>[];
    for (final enemy in enemies) {
      final inRange = towers.any((cell) => (cell - enemy.position).abs() <= 1);
      if (inRange) enemy.hp--;
      if (enemy.hp <= 0) {
        defeated.add(enemy);
      } else {
        enemy.position++;
        if (enemy.position >= 12) escaped.add(enemy);
      }
    }
    for (final enemy in defeated) {
      enemies.remove(enemy);
      kills++;
      gold += 15;
    }
    for (final enemy in escaped) {
      enemies.remove(enemy);
      lives--;
    }
    if (lives < 0) lives = 0;
  }
  void reset() {
    gold = 100; lives = 10; wave = 0; kills = 0;
    towers.clear(); enemies.clear();
  }
}
