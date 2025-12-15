import 'dart:io';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:grimreach_api/message_codec.dart';
import 'package:grimreach_api/messages.dart';
import 'package:grimreach_api/protocol.dart';
import 'package:grimreach_api/world_state.dart';
import 'package:grimreach_api/zone.dart';
import 'package:grimreach_api/entity_type.dart';
import 'package:grimreach_api/faction.dart';
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
    Map<String, Zone> previousEntityZones = {}; // ID -> Zone
    Map<String, Faction> previousZoneControl = {}; // Phase 020
    Map<String, Map<Faction, double>> previousZoneInfluence = {}; // Phase 021
    Map<Faction, double> previousFactionMorale = {};

    debugPrint('Client: Connected to server');

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

            final factionCounts = <Faction, int>{};

            final currentIds = <String>{};
            int movedToWild = 0;
            int movedToSafe = 0;

            for (final e in state.entities) {
              currentIds.add(e.id);
              if (e.zone == Zone.safe) eSafe++;
              if (e.zone == Zone.wilderness) eWild++;

              if (e.type == EntityType.npc) npc++;
              if (e.type == EntityType.resource) res++;
              if (e.type == EntityType.structure) str++;

              factionCounts[e.faction] = (factionCounts[e.faction] ?? 0) + 1;

              if (previousEntityZones.containsKey(e.id)) {
                final oldZone = previousEntityZones[e.id];
                if (oldZone == Zone.safe && e.zone == Zone.wilderness) {
                  movedToWild++;
                }
                if (oldZone == Zone.wilderness && e.zone == Zone.safe) {
                  movedToSafe++;
                }
              }
              previousEntityZones[e.id] = e.zone;
            }
            // Count player factions too?
            for (final p in state.players) {
              factionCounts[p.faction] = (factionCounts[p.faction] ?? 0) + 1;
            }

            previousEntityZones.removeWhere((k, v) => !currentIds.contains(k));

            if (movedToWild > 0) {
              debugPrint('Client: $movedToWild entities moved into wilderness');
            }
            if (movedToSafe > 0) {
              debugPrint('Client: $movedToSafe entities moved into safe zone');
            }

            final despawnedCount = previousEntityIds
                .difference(currentIds)
                .length;
            final respawnedCount = currentIds
                .difference(previousEntityIds)
                .length;
            previousEntityIds = currentIds;

            // NOTE: This logic requires persistence between frames.
            // I'll skip implementing full per-entity zone tracking inside this block if I can't preserve state easily without fields.
            // Wait, I can use a top-level or outer variable. `previousEntityIds` is there.
            // I need `previousEntityZones`.
            // But I cannot easily add top-level vars in this `replace_file_content` without changing `main`.
            // Current `main` has `Set<String> previousEntityIds = {};` in `_connectToServer`. I can add `previousEntityZones` there.

            debugPrint(
              'Client: World update - P: ${state.players.length}, E: ${state.entities.length} (Safe: $eSafe, Wild: $eWild), Types (N: $npc, R: $res, S: $str), Despawned: $despawnedCount, Respawned: $respawnedCount',
            );

            // Client State
            try {
              final me = state.players.firstWhere((p) => p.id == myId);

              // Detect Zone Change
              if (lastZone != me.zone) {
                debugPrint('Client: Zone changed to ${me.zone.name}');
                lastZone = me.zone;
              }

              // Log movement
              debugPrint(
                'Client: Player moved to x=${me.x.toStringAsFixed(1)}',
              );

              if (state.playerProximityCounts.containsKey(myId)) {
                final count = state.playerProximityCounts[myId];
                if (count != null && count > 0) {
                  debugPrint('Client: Player near $count entities');
                }
              } else {
                debugPrint(
                  'Client: No proximity data for $myId. Keys: ${state.playerProximityCounts.keys.toList()}',
                );
              }

              // Log Clusters
              if (state.largestClusterSize > 0) {
                debugPrint(
                  'Client: Clusters detected. Largest: ${state.largestClusterSize}',
                );
                state.zoneClusterCounts.forEach((zone, count) {
                  debugPrint('Client: $count clusters in $zone');
                });
              }

              // Log Groups (Phase 018)
              if (state.groupCount > 0) {
                debugPrint(
                  'Client: Groups detected. Count: ${state.groupCount}, Avg Size: ${state.averageGroupSize.toStringAsFixed(1)}',
                );
              }

              // Zone Control Changes (Phase 022)
              // Use explicit recentShifts list from server
              for (final zone in state.recentShifts) {
                final newOwner = state.zoneControl[zone]!;
                debugPrint('Client: WARNING: $newOwner has TAKEN the $zone!');
              }

              // Update previous control state just in case we need it later, or remove if unused.
              // Requirement says "detect changes... print...". `recentShifts` handles detection.
              previousZoneControl = state.zoneControl;

              // Zone Influence (Phase 021)
              // Print summary for Safe Zone (example as per req)
              // "Order influence in safe zone: 72"
              // Detect increases/decreases?
              // "Order influence in Safe: 72.0 (+1.0)"

              state.zoneInfluence.forEach((zone, scores) {
                final previousScores = previousZoneInfluence[zone] ?? {};

                scores.forEach((faction, score) {
                  final prev = previousScores[faction] ?? 0.0;
                  if ((score - prev).abs() > 0.5) {
                    debugPrint(
                      'Client: Influence Update: $zone - ${faction.name} ($score)',
                    );
                  }
                });
              });
              previousZoneInfluence = state.zoneInfluence;

              // Faction Morale (Phase 023)
              state.factionMorale.forEach((faction, score) {
                final prev = previousFactionMorale[faction] ?? 50.0;
                if ((score - prev).abs() > 0.5) {
                  String trend = score > prev ? 'Rising' : 'Falling';
                  debugPrint(
                    'Client: Morale ${faction.name} $trend: ${prev.toStringAsFixed(1)} -> ${score.toStringAsFixed(1)}',
                  );
                }
              });
              previousFactionMorale = state.factionMorale;
            } catch (e) {
              debugPrint('Client: Error tracking player: $e');
            }

            // Still print summary if needed, or just zone? Instructions say "print a message indicating the new zone".
            // Phase 005 required printing summary. Phase 007 says "Update... to detect and print zone changes".
            // I'll keep summary to be safe but add zone logging.
          } else {
            debugPrint('Client: Message received: ${msg.type}');
          }
        }
      },
      onError: (e) {
        debugPrint('Client: Error: $e');
      },
      onDone: () {
        debugPrint('Client: Disconnected');
      },
    );

    // Send handshake
    final handshake = Message(type: Protocol.handshake, data: {'id': myId});
    socket.add(codec.encode(handshake));
    debugPrint('Client: Sent handshake');
  } catch (e) {
    debugPrint('Client: Connection failed: $e');
  }
}
