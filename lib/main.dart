import 'package:flutter/material.dart';

import 'app/study_mate_app.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.demo});
  final bool? demo;
  @override
  Widget build(BuildContext context) => StudyMateApp(demo: demo);
}
