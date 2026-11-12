const academicLevels = [
  'Bachelor 1',
  'Bachelor 2',
  'Bachelor 3',
  'Master 1',
  'Master 2',
];
const specialties = [
  'Computer Science',
  'Software Engineering',
  'Data Science',
  'Business Informatics',
];
const subjectOptions = [
  'Artificial Intelligence',
  'Mobile Development',
  'Cloud Computing',
  'Software Engineering',
];

class Student {
  factory Student.fromJson(Map<String, dynamic> json) => Student(
    name: json['fullName'] as String,
    email: json['email'] as String,
    level: json['academicLevel'] as String,
    specialty: json['specialty'] as String,
    subjects: List<String>.from(json['subjects'] as List),
  );
  Map<String, dynamic> toJson() => {
    'fullName': name,
    'email': email,
    'academicLevel': level,
    'specialty': specialty,
    'subjects': subjects,
  };
  Student({
    required this.name,
    required this.email,
    required this.level,
    required this.specialty,
    required List<String> subjects,
  }) : subjects = List.unmodifiable(subjects);
  final String name, email, level, specialty;
  final List<String> subjects;
  String get firstName => name.trim().split(RegExp(r'\s+')).first;
  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((s) => s[0].toUpperCase())
      .join();
}
