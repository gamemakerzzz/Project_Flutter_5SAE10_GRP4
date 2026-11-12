import 'package:dart_frog/dart_frog.dart';
import 'package:studymate_backend/src/http/application.dart';

Future<Response> onRequest(RequestContext context) =>
    context.read<Application>().handle(context);
