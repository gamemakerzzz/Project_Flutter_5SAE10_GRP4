import '../../profile/models/student.dart';

/// Simulates latency only. No network, credentials or profile persistence.
class DemoRepository {
  Future<void> delay() =>
      Future<void>.delayed(const Duration(milliseconds: 650));
  Student sampleStudent() => Student(
    name: 'Alex Morgan',
    email: 'alex@studymate.demo',
    level: 'Bachelor 3',
    specialty: 'Computer Science',
    subjects: subjectOptions,
  );
}
