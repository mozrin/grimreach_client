import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grimreach_api/protocol.dart';
import 'package:grimreach_api/messages.dart';
import 'package:grimreach_api/message_codec.dart';

void main() async {
  runApp(const Placeholder());

  try {
    final socket = await WebSocket.connect('ws://localhost:8080/ws');
    final codec = MessageCodec();

    print('Client: Connected to server');

    socket.listen(
      (data) {
        if (data is String) {
          final msg = codec.decode(data);
          print('Client: Echo received: ${msg.type}');
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
    final handshake = Message(
      type: Protocol.handshake,
      data: {'id': 'client_1'},
    );
    socket.add(codec.encode(handshake));
    print('Client: Sent handshake');
  } catch (e) {
    print('Client: Connection failed: $e');
  }
}
