import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:iouring_transport/iouring_transport.dart';

Future<void> main(List<String> args) async {
  await tcp();
  await udp();
  await unixStream();
  await unixDatagram();
  await file();
}

Future<void> tcp() async {
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
}

Future<void> unixStream() async {
  final transport = Transport();
  final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
  await worker.initialize();

  worker.servers.unixStream('/tmp/my_socket', (connection) {
    connection.stream().listen((event) {
      connection.writeSingle(Uint8List.fromList((String.fromCharCodes(event.takeBytes()) + "world!").codeUnits));
    });
  });

  final completer = Completer();
  final clients = await worker.clients.unixStream('/tmp/my_socket');

  clients.select().stream().listen((event) {
    print(String.fromCharCodes(event.takeBytes()));
    completer.complete();
  });

  clients.select().writeSingle(Uint8List.fromList("Hello, ".codeUnits));
  await completer.future;
  await transport.shutdown();
}

Future<void> unixDatagram() async {
  final transport = Transport();
  final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
  await worker.initialize();

  worker.servers.unixDatagram('/tmp/server').receive().listen((responder) {
    responder.respond(Uint8List.fromList((String.fromCharCodes(responder.receivedBytes) + "world!").codeUnits));
  });

  final completer = Completer();
  final client = await worker.clients.unixDatagram('/tmp/client', '/tmp/server');

  client.stream().listen((event) {
    print(String.fromCharCodes(event.takeBytes()));
    completer.complete();
  });

  client.send(Uint8List.fromList("Hello, ".codeUnits));
  await completer.future;
  await transport.shutdown();
}

Future<void> udp() async {
  final transport = Transport();
  final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
  await worker.initialize();

  worker.servers.udp(InternetAddress.anyIPv4, 1234).receive().listen((responder) {
    responder.respond(Uint8List.fromList((String.fromCharCodes(responder.receivedBytes) + "world!").codeUnits));
  });

  final completer = Completer();
  final client = await worker.clients.udp(InternetAddress.loopbackIPv4, 5678, InternetAddress.loopbackIPv4, 1234);

  client.stream().listen((event) {
    print(String.fromCharCodes(event.takeBytes()));
    completer.complete();
  });

  client.send(Uint8List.fromList("Hello, ".codeUnits));
  await completer.future;
  await transport.shutdown();
}

Future<void> file() async {
  final transport = Transport();
  final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
  await worker.initialize();

  final file = worker.files.open('/tmp/my_file', create: true, truncate: true);

  file.writeSingle(Uint8List.fromList("Hello".codeUnits), onDone: () {
    print("Data written to file.");
  });

  final data = await file.load();
  print("Data read from file: " + String.fromCharCodes(data));

  await transport.shutdown();
}
