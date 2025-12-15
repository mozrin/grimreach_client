import 'package:flutter/material.dart';
import 'package:grimreach_api/player.dart';

void main() {
  final player = Player(id: "test", x: 0, y: 0);
  print('Client: API linked. Player created: ${player.id}');
  runApp(const Placeholder());
}
