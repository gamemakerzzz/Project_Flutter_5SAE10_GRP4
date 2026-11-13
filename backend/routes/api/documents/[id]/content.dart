import 'package:dart_frog/dart_frog.dart';
import 'package:studymate_backend/src/http/application.dart';

Future<Response> onRequest(RequestContext context, String id) =>
    context.read<Application>().handle(context);
