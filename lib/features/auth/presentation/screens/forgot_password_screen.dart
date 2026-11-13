import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../data/demo_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  bool busy = false, sent = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    await DemoRepository().delay();
    if (!mounted) return;
    setState(() {
      busy = false;
      sent = true;
    });
    notice(context, 'Demonstration complete. No email was sent.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: PageBody(
      maxWidth: 480,
      children: [
        const Brand(),
        const SizedBox(height: 40),
        Icon(
          sent ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          sent ? 'You’re all set — in demo!' : 'Reset Your Password',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Text(
          sent
              ? 'The reset flow was simulated for ${email.text.trim()}. No link was generated and no email was sent.'
              : 'Enter your email to preview the password recovery experience. This demonstration sends no real email.',
        ),
        const SizedBox(height: 24),
        if (!sent)
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  validator: emailValidator,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 20),
                BusyButton(
                  label: 'Send Reset Link',
                  busy: busy,
                  onPressed: submit,
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Login'),
        ),
      ],
    ),
  );
}
