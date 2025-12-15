# grimreach_client

The deterministic visualization and interaction frontend for Grimreach.

See also: [Grimreach Design & Architecture](../grimreach_docs/README.md)

## Core Responsibilities
- Connects to server and receives WorldState messages
- Prints systemic transitions and summaries
- Demonstrates minimal deterministic client behavior
- Contains no simulation logic or authority

## Architectural Role
Acts as a dumb terminal that renders the authoritative state provided by the server. It handles local user input and visualizes the world but makes no decisions about world state. It is built on Flutter and Flame.

## Deterministic Contract Surface
- Input: `User Actions` (Keyboard/Mouse)
- Input: `WorldState` (via WebSocket)
- Output: `Protocol.handshake`
- Output: `Protocol.move` (and other commands)

## Explicit Non-Responsibilities
- No simulation authority
- No cheat validation (handled by server)
- No direct database access

## Folder/Layout Summary
- `lib/`: Flutter/Dart source code.
  - `main.dart`: Entry point.
  - `game/`: Flame game engine integration.
- `web/`, `linux/`, `macos/`, `windows/`: Platform runners.

## Development Notes
Run with `flutter run`. Requires `grimreach_api` and a running `grimreach_server`.
