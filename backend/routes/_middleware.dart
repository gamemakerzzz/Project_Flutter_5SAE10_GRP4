import 'package:dart_frog/dart_frog.dart';
import 'package:studymate_backend/src/config/config.dart';
import 'package:studymate_backend/src/http/application.dart';

final application = Application(Config.environment());
Handler middleware(Handler handler) =>
    handler.use(provider<Application>((_) => application));
