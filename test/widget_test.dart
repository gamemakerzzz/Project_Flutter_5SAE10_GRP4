import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_learning/main.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> login(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp(demo: true));
  await tapText(tester, 'I already have an account');
  await tapText(tester, 'Fill demo credentials');
  await tapText(tester, 'Sign In');
}

void main() {
  testWidgets('Login validates input and rejects credentials outside demo', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(demo: true));
    await tapText(tester, 'I already have an account');
    await tapText(tester, 'Sign In');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'someone@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'WrongPassword!');
    await tapText(tester, 'Sign In');
    expect(
      find.text('Use the demo credentials shown above to explore.'),
      findsOneWidget,
    );
  });

  testWidgets('Login, edit profile, empty subjects, dashboard and logout', (
    tester,
  ) async {
    await login(tester);
    expect(find.text('Alex'), findsOneWidget);
    await tapText(tester, 'Profile');
    await tapText(tester, 'Edit Profile');
    await tester.enterText(find.byType(TextFormField).first, 'Sam Taylor');
    for (final name in [
      'Artificial Intelligence',
      'Mobile Development',
      'Cloud Computing',
      'Software Engineering',
    ]) {
      await tapText(tester, name);
    }
    await tapText(tester, 'Save Changes');
    expect(find.text('Sam Taylor'), findsOneWidget);
    await tapText(tester, 'Home');
    expect(find.text('Sam'), findsOneWidget);
    await tester.ensureVisible(
      find.text(
        'Your learning journey is a blank canvas. Add subjects in Edit Profile to get started.',
      ),
    );
    expect(
      find.text('No upcoming demo exams for your selected subjects.'),
      findsOneWidget,
    );
    await tapText(tester, 'Profile');
    await tapText(tester, 'Logout');
    await tapText(tester, 'Logout');
    expect(find.text('Learn Smarter,\nAchieve More'), findsOneWidget);
  });

  testWidgets('Password reset explicitly confirms no email is sent', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(demo: true));
    await tapText(tester, 'I already have an account');
    await tapText(tester, 'Forgot Password?');
    await tester.enterText(find.byType(TextFormField).last, 'alex@example.com');
    await tapText(tester, 'Send Reset Link');
    expect(
      find.textContaining('No link was generated and no email was sent.'),
      findsOneWidget,
    );
    await tapText(tester, 'Back to Login');
    expect(find.text('Welcome Back!'), findsOneWidget);
  });

  testWidgets('Registration validates confirmation and creates a session', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(demo: true));
    await tapText(tester, 'Get Started');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Jamie Lee');
    await tester.enterText(fields.at(1), 'jamie@example.com');
    await tester.enterText(fields.at(2), 'Sample123!');
    await tester.enterText(fields.at(3), 'Different123!');
    await tapText(tester, 'Create Account');
    expect(find.text('Passwords must match.'), findsOneWidget);
    expect(find.text('Please accept the terms to continue.'), findsOneWidget);
    await tester.ensureVisible(fields.at(3));
    await tester.enterText(fields.at(3), 'Sample123!');
    await tapText(tester, 'Accept Terms & Conditions');
    await tapText(tester, 'Create Account');
    expect(find.text('Jamie'), findsOneWidget);
  });

  testWidgets('Small phone and dark theme remain navigable', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await login(tester);
    expect(tester.takeException(), isNull);
    await tapText(tester, 'Courses');
    expect(find.text('My Courses'), findsOneWidget);
    await tapText(tester, 'Profile');
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(Switch));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
