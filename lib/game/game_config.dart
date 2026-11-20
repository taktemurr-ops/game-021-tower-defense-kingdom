import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/arcade_stage.dart';
import '../app/game_api.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/arcade.dart';
import '../core/game_rules.dart';
import 'td_engine.dart';
import 'rules.dart';

void paintTd(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final s = sim as TdSim;
  // grass + path
  c.drawRect(const Rect.fromLTWH(0, kGridTop, kWorldW, kRows * kCell), Paint()..color = const Color(0xFF52796F));
  for (var r = 0; r < kRows; r++) {
    for (var col = 0; col < kCols; col++) {
      if ((r + col).isEven) {
        c.drawRect(Rect.fromLTWH(col * kCell, kGridTop + r * kCell, kCell, kCell), Paint()..color = const Color(0xFF4F7468));
      }
    }
  }
  final road = Paint()..color = const Color(0xFFDDB892);
  for (final q in s.level.path) {
    c.drawRect(Rect.fromLTWH(q.x * kCell, kGridTop + q.y * kCell, kCell, kCell), road);
  }
  // castle at the end
  final end = s.level.path.last;
  final cx = end.x * kCell + kCell / 2, cy = kGridTop + end.y * kCell + kCell / 2;
  c.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 80, height: 70), Paint()..color = const Color(0xFF6C757D));
  for (var i = 0; i < 3; i++) {
    c.drawRect(Rect.fromLTWH(cx - 40 + i * 30, cy - 50, 20, 18), Paint()..color = const Color(0xFF6C757D));
  }
  c.drawRect(Rect.fromLTWH(cx - 3, cy - 85, 6, 40), Paint()..color = Colors.white70);
  c.drawPath(Path()..moveTo(cx + 3, cy - 85)..lineTo(cx + 33, cy - 75)..lineTo(cx + 3, cy - 65)..close(), Paint()..color = const Color(0xFFE63946));
  // towers
  for (final tw in s.towers) {
    final x = tw.c * kCell + kCell / 2, y = kGridTop + tw.r * kCell + kCell / 2;
    c.drawCircle(Offset(x, y + 6), 38, Paint()..color = Colors.black26);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 70, height: 70), const Radius.circular(14)), Paint()..color = const Color(0xFF495057));
    c.drawCircle(Offset(x, y), 24, Paint()..color = Color(tw.t.color));
    for (var i = 0; i < tw.level; i++) {
      c.drawCircle(Offset(x - 21 + i * 14, y + 30), 5, Paint()..color = const Color(0xFFFFD60A));
    }
  }
  // enemies
  for (final e in s.enemies) {
    final (x, y) = s.posAt(e.dist);
    final r = switch (e.kind) { 1 => 18.0, 2 => 26.0, 3 => 40.0, _ => 22.0 };
    final col = switch (e.kind) { 1 => const Color(0xFFFFB703), 2 => const Color(0xFFADB5BD), 3 => const Color(0xFF9D0208), _ => const Color(0xFFE63946) };
    final bob = p.reducedMotion ? 0.0 : math.sin(t * 10 + e.dist * 3) * 3;
    c.drawCircle(Offset(x, y + bob), r, Paint()..color = col);
    if (e.slowTicks > 0) c.drawCircle(Offset(x, y + bob), r + 5, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = const Color(0xFF8ECAE6));
    c.drawCircle(Offset(x - r * 0.35, y + bob - r * 0.2), r * 0.18, Paint()..color = Colors.white);
    c.drawCircle(Offset(x + r * 0.35, y + bob - r * 0.2), r * 0.18, Paint()..color = Colors.white);
    final f = (e.hp / e.maxHp).clamp(0.0, 1.0);
    c.drawRect(Rect.fromLTWH(x - 25, y - r - 14, 50, 7), Paint()..color = Colors.black45);
    c.drawRect(Rect.fromLTWH(x - 25, y - r - 14, 50 * f, 7), Paint()..color = const Color(0xFF7BD389));
  }
  for (final b in s.beams) {
    c.drawLine(Offset(b.x1, b.y1), Offset(b.x2, b.y2), Paint()..color = Color(b.color).withValues(alpha: b.life / 8)..strokeWidth = 6);
  }
  // HUD
  c.drawRect(const Rect.fromLTWH(0, 0, kWorldW, kGridTop), Paint()..color = Colors.black38);
  paintText(c, '● ${s.gold}', const Offset(150, 55), 44, const Color(0xFFFFD60A));
  paintText(c, '♥ ${s.castle}', const Offset(500, 55), 44, const Color(0xFFEF476F));
  paintText(c, '⚑ ${s.goalText}', const Offset(830, 55), 44, Colors.white);
  if (!s.waveRunning && s.wave > 0 && !s.over) {
    paintText(c, '${(s.breakTicks / 60).ceil()}', const Offset(500, 760), 120, Colors.white38);
  }
  // build bar
  c.drawRect(Rect.fromLTWH(0, kBarTop - 10, kWorldW, kWorldH - kBarTop + 10), Paint()..color = const Color(0xFF212529));
  for (var i = 0; i < 4; i++) {
    final tt = towerTypes[i];
    final rect = Rect.fromLTWH(i * 200 + 10, kBarTop + 10, 180, 150);
    final sel = s.selected == i;
    c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), Paint()..color = sel ? const Color(0xFF343A40) : const Color(0xFF2B2D42));
    if (sel) c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = const Color(0xFFFFD60A));
    c.drawCircle(Offset(rect.center.dx, rect.top + 50), 28, Paint()..color = Color(tt.color));
    paintText(c, '${tt.cost}', Offset(rect.center.dx, rect.top + 115), 34, s.gold >= tt.cost ? const Color(0xFFFFD60A) : Colors.white38);
  }
  final nb = const Rect.fromLTWH(810, kBarTop + 10, 180, 150);
  c.drawRRect(RRect.fromRectAndRadius(nb, const Radius.circular(20)), Paint()..color = const Color(0xFF2A9D8F));
  paintText(c, '▶▶', Offset(nb.center.dx, nb.top + 55), 50, Colors.white);
  paintText(c, '+${10 + s.breakTicks ~/ 30}', Offset(nb.center.dx, nb.top + 115), 30, Colors.white70);
}

Sfx? tdSound(ArcadeSim sim) => switch ((sim as TdSim).lastEvent) {
      1 => Sfx.place,
      2 => Sfx.coin,
      3 => Sfx.error,
      4 => Sfx.unlock,
      5 => Sfx.combo,
      6 => Sfx.error,
      _ => null,
    };

final gameConfig = GameConfig(
  gameId: 'game-021-tower-defense-kingdom',
  title: const ['Kule Savunma Krallığı', 'Tower Defense Kingdom', 'Turmverteidigung', 'Defensa de Torres', 'Défense de Tours'],
  tagline: const ['Kuleleri kur, hattı tut, krallığı kurtar!', 'Build towers, hold the line, save the kingdom!', 'Baue Türme, halte die Linie!', '¡Construye torres y defiende el reino!', 'Construisez des tours, défendez le royaume !'],
  seedColor: const Color(0xFFF4A261),
  icon: Icons.castle,
  rules: TdRules(),
  buildPlay: (ctx) => ArcadeStage(
    ctx: ctx,
    create: () => TdSim((ctx.generated as GeneratedLevel<TdLevel>).puzzle),
    paint: paintTd,
    sound: tdSound,
    boosterIcon: Icons.local_fire_department,
    boosterLabel: (l) => l == 'tr' ? 'Meteor' : 'Meteor strike',
    howTo: const [
      'Alttan kule seç, yolun yanındaki boş kareye dokun. Kuleye tekrar dokun: yükselt.',
      'Pick a tower below, tap an empty tile next to the road. Tap a tower to upgrade.',
      'Turm wählen, freies Feld antippen; Turm antippen = verbessern.',
      'Elige torre, toca una casilla libre; toca la torre para mejorar.',
      'Choisissez une tour, touchez une case libre ; touchez une tour pour l\'améliorer.',
    ],
  ),
  tutorial: const [
    TutorialStep(Icons.castle, [
      'Okçu hızlı, top alan hasarı, buz yavaşlatır, şimşek ağır vurur.',
      'Archer is fast, cannon splashes, frost slows, tesla hits hard.',
      'Bogen schnell, Kanone Fläche, Frost bremst, Tesla stark.',
      'Arquero rápido, cañón en área, hielo ralentiza, tesla fuerte.',
      'Archer rapide, canon de zone, gel ralentit, tesla puissant.',
    ]),
    TutorialStep(Icons.fast_forward, [
      '▶▶ ile sonraki dalgayı erken çağır, bonus altın kazan.',
      'Call the next wave early with ▶▶ for bonus gold.',
      'Mit ▶▶ die nächste Welle früher rufen.',
      'Llama la siguiente oleada antes con ▶▶.',
      'Appelez la vague suivante avec ▶▶.',
    ]),
  ],
);
