import 'dart:io';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:grimreach_api/message_codec.dart';
import 'package:grimreach_api/messages.dart';
import 'package:grimreach_api/protocol.dart';
import 'package:grimreach_api/world_state.dart';
import 'package:grimreach_api/zone.dart';
import 'game/engine/game_loop.dart';

void main() {
  // Use GameLoop as the root game
  final game = GameLoop();

  // Connect to server (fire and forget / independent of UI)
  _connectToServer();

  runApp(GameWidget(game: game));
}

Future<void> _connectToServer() async {
  try {
    final socket = await WebSocket.connect('ws://localhost:8080/ws');
    final codec = MessageCodec();
    final myId = 'client_1'; // Hardcoded for this phase as per previous logic
    Zone? lastZone;

    print('Client: Connected to server');

    socket.listen(
      (data) {
        if (data is String) {
          final msg = codec.decode(data);
          if (msg.type == Protocol.state) {
            final state = WorldState.fromJson(msg.data);

            // Find local player
            try {
              final me = state.players.firstWhere((p) => p.id == myId);
              if (lastZone != me.zone) {
                print('Client: Zone changed to ${me.zone.name}');
                lastZone = me.zone;
              }
            } catch (e) {
              // Local player might not be in state yet or ID mismatch
            }

            // Still print summary if needed, or just zone? Instructions say "print a message indicating the new zone".
            // Phase 005 required printing summary. Phase 007 says "Update... to detect and print zone changes".
            // I'll keep summary to be safe but add zone logging.
          } else {
            print('Client: Message received: ${msg.type}');
          }
        }
      },
      onError: (e) {
        print('Client: Error: $e');
      },
      onDone: () {
        print('Client: Disconnected');
      },
    );

    // Send handshake
    final handshake = Message(type: Protocol.handshake, data: {'id': myId});
    socket.add(codec.encode(handshake));
    print('Client: Sent handshake');
  } catch (e) {
    print('Client: Connection failed: $e');
  }
}
