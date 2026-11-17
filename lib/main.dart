import 'package:flutter/material.dart';
import 'game/defense_engine.dart';

void main() => runApp(const MaterialApp(home: DefenseScreen(), debugShowCheckedModeBanner: false));

class DefenseScreen extends StatefulWidget {
  const DefenseScreen({super.key});
  @override
  State<DefenseScreen> createState() => _DefenseScreenState();
}

class _DefenseScreenState extends State<DefenseScreen> {
  final engine = DefenseEngine();
  void update(void Function() action) => setState(action);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tower Defense Kingdom'), actions: [
      IconButton(onPressed: () => update(engine.reset), icon: const Icon(Icons.refresh), tooltip: 'Restart'),
    ]),
    body: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Wave ${engine.wave} • Gold ${engine.gold} • Lives ${engine.lives} • Kills ${engine.kills}'),
      const SizedBox(height: 18),
      const Text('Tap a tile to build a tower (40 gold)'),
      Padding(padding: const EdgeInsets.all(16), child: GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 12,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6),
        itemBuilder: (context, index) {
          final count = engine.enemies.where((enemy) => enemy.position == index).length;
          return InkWell(onTap: () => update(() { engine.buildTower(index); }),
            child: Container(margin: const EdgeInsets.all(3),
              color: engine.towers.contains(index) ? Colors.blueGrey : Colors.green.shade100,
              child: Center(child: Text(engine.towers.contains(index) ? '🏰' : count > 0 ? '👾$count' : '$index'))));
        })),
      ElevatedButton(onPressed: engine.canStartWave ? () => update(engine.startWave) : null,
        child: const Text('Start wave')),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: engine.enemies.isNotEmpty && !engine.gameOver
        ? () => update(engine.tick) : null, child: const Text('Advance one turn')),
      if (engine.gameOver) const Text('Game over — restart to play again'),
      const Padding(padding: EdgeInsets.all(12), child: Text('No ads or purchases required to play.')),
    ])),
  );
}
