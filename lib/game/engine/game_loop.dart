import 'dart:async';
import 'package:flame/game.dart';
import 'world_scene.dart';

class GameLoop extends FlameGame {
  final WorldScene worldScene = WorldScene();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(worldScene);
  }
}
