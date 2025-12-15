import 'dart:io';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:grimreach_api/message_codec.dart';
import 'package:grimreach_api/messages.dart';
import 'package:grimreach_api/protocol.dart';
import 'package:grimreach_api/world_state.dart';
import 'package:grimreach_api/zone.dart';
import 'package:grimreach_api/entity_type.dart';
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
    final myId = 'player_1'; // Matched to server logic for Phase 014
    Zone? lastZone;
    Set<String> previousEntityIds = {}; // State for tracking despawns

    print('Client: Connected to server');

    socket.listen(
      (data) {
        if (data is String) {
          final msg = codec.decode(data);
          if (msg.type == Protocol.state) {
            final state = WorldState.fromJson(msg.data);

            int eSafe = 0;
            int eWild = 0;
            int npc = 0;
            int res = 0;
            int str = 0;

            final currentIds = <String>{};

            for (final e in state.entities) {
              currentIds.add(e.id);
              if (e.zone == Zone.safe) eSafe++;
              if (e.zone == Zone.wilderness) eWild++;

              if (e.type == EntityType.npc) npc++;
              if (e.type == EntityType.resource) res++;
              if (e.type == EntityType.structure) str++;
            }

            final despawnedCount = previousEntityIds
                .difference(currentIds)
                .length;
            final respawnedCount = currentIds
                .difference(previousEntityIds)
                .length;
            previousEntityIds = currentIds;

            print(
              'Client: World update - P: ${state.players.length}, E: ${state.entities.length} (Safe: $eSafe, Wild: $eWild), Types (N: $npc, R: $res, S: $str), Despawned: $despawnedCount, Respawned: $respawnedCount',
            );

            // Client State
            try {
              final me = state.players.firstWhere((p) => p.id == myId);

              // Detect Zone Change
              if (lastZone != me.zone) {
                print('Client: Zone changed to ${me.zone.name}');
                lastZone = me.zone;
              }

              // Log movement
              print('Client: Player moved to x=${me.x.toStringAsFixed(1)}');
            } catch (e) {
              print('Client: Error tracking player: $e');
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
