import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:iouring_transport/iouring_transport.dart';

Future<void> main(List<String> args) async {
  final transport = Transport();
  final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
  await worker.initialize();
  worker.servers.tcp(InternetAddress.anyIPv4, 1234, (connection) {
    connection.stream().listen((event) {
      connection.writeSingle(Uint8List.fromList((String.fromCharCodes(event.takeBytes()) + "world!").codeUnits));
    });
  });
  final completer = Completer();
  final clients = await worker.clients.tcp(InternetAddress.loopbackIPv4, 1234);
  clients.select().stream().listen((event) {
    print(String.fromCharCodes(event.takeBytes()));
    completer.complete();
  });
  clients.select().writeSingle(Uint8List.fromList("Hello, ".codeUnits));
  await completer.future;
  await transport.shutdown();
  exit(0);
}
