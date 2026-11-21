import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'td_engine.dart';

class TdRules extends ArcadeRules<TdLevel> {
  @override
  String get gameId => 'game-021-tower-defense-kingdom';

  @override
  List<String> get optionalMechanics => const ['armored', 'fast', 'swarm', 'boss', 'regen'];

  @override
  List<GameStat> get gameStats => const [
        GameStat('enemies_defeated', 'Yenilen düşman', 'Enemies defeated', scale: 300),
        GameStat('towers_built', 'Kurulan kule', 'Towers built', scale: 50),
        GameStat('waves_survived', 'Atlatılan dalga', 'Waves survived', scale: 40),
        GameStat('bosses_defeated', 'Yenilen boss', 'Bosses defeated', scale: 5),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('enemies_defeated', 'enemies_defeated', [100, 200, 300]),
        MissionTemplate('towers_built', 'towers_built', [16, 33, 50]),
      ];

  @override
  TdLevel generate(LevelSpec spec) => generateTdLevel(spec);

  @override
  ArcadeMeta metaOf(TdLevel l) => l.meta;

  @override
  ArcadeSim createSim(TdLevel l) => TdSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => tdBot(sim);

  @override
  int maxTicks(TdLevel l) => 60 * 60 * 10;
}

ArcadeRules createRules() => TdRules();
