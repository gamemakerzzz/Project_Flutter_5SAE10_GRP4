import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:studymate_backend/src/config/config.dart';
import 'package:studymate_backend/src/http/application.dart';

Future<void> main() async {
  final app = Application(Config.environment());
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(
    app.handle,
    Platform.environment['HOST'] ?? '127.0.0.1',
    port,
  );
  stdout.writeln('StudyMate API listening on ${server.address.address}:$port');
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    await app.close();
    exit(0);
  });
}
