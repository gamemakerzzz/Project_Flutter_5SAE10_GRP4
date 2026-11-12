import 'package:flutter/material.dart';

void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
void openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 23),
      ),
      const SizedBox(width: 10),
      const Flexible(
        child: Text(
          'StudyMate AI',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 21,
            letterSpacing: -.5,
          ),
        ),
      ),
    ],
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 840});
  final List<Widget> children;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
}

class DemoNote extends StatelessWidget {
  const DemoNote({
    super.key,
    this.text = 'Demo workspace · Changes stay in this session.',
  });
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer
          .withValues(alpha: .55),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 19),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder(this.title, {super.key, this.standalone = true});
  final String title;
  final bool standalone;
  @override
  Widget build(BuildContext context) {
    final body = PageBody(
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.construction_rounded,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          '$title is on its way',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const Text(
          'This destination is a placeholder for the team’s upcoming module. Explore your dashboard and profile while we build the next chapter.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const DemoNote(
          text: 'Integration preview · No module functionality is connected.',
        ),
      ],
    );
    return standalone
        ? Scaffold(
            appBar: AppBar(title: Text(title)),
            body: body,
          )
        : body;
  }
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;
String? emailValidator(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Enter a valid email address.';
String? passwordValidator(String? value) =>
    (value?.length ?? 0) >= 8 ? null : 'Use at least 8 characters.';
