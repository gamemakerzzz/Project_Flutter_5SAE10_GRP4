import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../view_models/session_controller.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool hidden = true, remember = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    email.text = widget.session.rememberedEmail ?? '';
    remember = email.text.isNotEmpty;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.signIn(email.text, password.text, remember);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      notice(
        context,
        widget.session.isDemo
            ? 'Demo session started. Welcome to StudyMate AI!'
            : 'Welcome to StudyMate AI!',
      );
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save your session securely. Please retry.',
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
        const SizedBox(height: 32),
        Text('Welcome Back!', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        const Text('A fresh start for your next great idea.'),
        const SizedBox(height: 24),
        if (widget.session.isDemo)
          const DemoNote(
            text: 'Demo account\nalex@studymate.demo\nPassword: StudyMate123!\nNo real authentication takes place.',
          ),
        if (widget.session.isDemo)
          TextButton.icon(
            onPressed: busy
                ? null
                : () {
                    email.text = 'alex@studymate.demo';
                    password.text = 'StudyMate123!';
                  },
            icon: const Icon(Icons.edit_note),
            label: const Text('Fill demo credentials'),
          ),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
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
                onFieldSubmitted: (_) {
                  if (!busy) submit();
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
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
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: remember,
                        onChanged: busy
                            ? null
                            : (value) => setState(() => remember = value!),
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => widget.session.isDemo
                              ? openPage(context, const ForgotPasswordScreen())
                              : notice(
                                  context,
                                  'Password recovery is not available yet. No email has been sent.',
                                ),
                    child: const Text('Forgot Password?'),
                  ),
                ],
              ),
              const Text(
                'Remembers your email for this app session only.',
                style: TextStyle(fontSize: 12),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              BusyButton(label: 'Sign In', busy: busy, onPressed: submit),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: busy
              ? null
              : () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => RegisterScreen(session: widget.session),
                  ),
                ),
          child: const Text("Don't have an account? Sign Up"),
        ),
      ],
    ),
  );
}
