import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../../profile/models/student.dart';
import '../view_models/session_controller.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  String level = academicLevels[2], specialty = specialties.first;
  bool hidden = true, accepted = false, busy = false, showTermsError = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  int get strength => [
    password.text.length >= 8,
    RegExp(r'[A-Z]').hasMatch(password.text),
    RegExp(r'[0-9]').hasMatch(password.text),
    RegExp(r'[^a-zA-Z0-9]').hasMatch(password.text),
  ].where((x) => x).length;
  Future<void> submit() async {
    final valid = form.currentState!.validate();
    setState(() => showTermsError = !accepted);
    if (!valid || !accepted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.register(
        Student(
          name: name.text.trim(),
          email: email.text.trim(),
          level: level,
          specialty: specialty,
          subjects: subjectOptions,
        ),
        password: password.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      notice(
        context,
        widget.session.isDemo
            ? 'Demo profile created. No real account was registered.'
            : 'Account created. Welcome to StudyMate!',
      );
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not save your session securely. Please try signing in.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: PageBody(
      maxWidth: 480,
      children: [
        const Brand(),
        const SizedBox(height: 28),
        Text(
          'Your future starts here.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 10),
        const Text('Create your learning space in a few simple steps.'),
        const SizedBox(height: 20),
        DemoNote(
          text: widget.session.isDemo
              ? 'Demo registration · Use fictional details and a sample password. Nothing is stored permanently.'
              : 'Create your student account. Your profile and uploaded PDFs will be stored on the StudyMate server.',
        ),
        const SizedBox(height: 20),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: name,
                enabled: !busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: requiredText,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: emailValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                enabled: !busy,
                obscureText: hidden,
                enableSuggestions: false,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Show passwords' : 'Hide passwords',
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: passwordValidator,
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: strength / 4,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 6),
              Text(
                'Password strength: ${['Not entered', 'Weak', 'Fair', 'Good', 'Strong'][strength]}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirm,
                enabled: !busy,
                obscureText: hidden,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                validator: (v) => v == password.text && (v?.isNotEmpty ?? false)
                    ? null
                    : 'Passwords must match.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: level,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Academic Level'),
                items: academicLevels
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => level = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: specialty,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Field of Study / Specialty',
                ),
                items: specialties
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => specialty = v!),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Accept Terms & Conditions'),
                value: accepted,
                onChanged: busy ? null : (v) => setState(() => accepted = v!),
              ),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      widget.session.isDemo
                          ? 'Demo Terms & Conditions'
                          : 'Development service information',
                    ),
                    content: Text(
                      widget.session.isDemo
                          ? 'This prototype uses fictional learning data. Profiles exist only in memory until logout or restart. No email is sent and no learning or authentication service is connected.'
                          : 'This development service stores your profile and PDFs on the configured server. Upload only materials you may use. AI generation, email verification and password recovery are not available. Signing out removes the token from this device; server data remains.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
                child: Text(
                  widget.session.isDemo
                      ? 'Read demo terms'
                      : 'Read service information',
                ),
              ),
              if (showTermsError && !accepted)
                Text(
                  'Please accept the terms to continue.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              BusyButton(
                label: 'Create Account',
                busy: busy,
                onPressed: submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy
              ? null
              : () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => LoginScreen(session: widget.session),
                  ),
                ),
          child: const Text('Already have an account? Sign In'),
        ),
      ],
    ),
  );
}
