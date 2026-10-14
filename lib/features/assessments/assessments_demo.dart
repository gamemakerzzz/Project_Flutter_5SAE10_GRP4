import 'package:flutter/material.dart';

import 'presentation/screens/assessments_screen.dart';
import 'presentation/widgets/assessment_widgets.dart';

/// Isolated preview entry point; does not replace the shared app's main.dart.
void main() => runApp(const AssessmentsDemoApp());

class AssessmentsDemoApp extends StatelessWidget {
  const AssessmentsDemoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Smart Learning · Quiz & Examens',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: assessmentBlue),
      scaffoldBackgroundColor: assessmentBackground,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: assessmentBlue,
          foregroundColor: Colors.white,
        ),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    ),
    home: const AssessmentsScreen(),
  );
}
