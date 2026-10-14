import 'package:flutter/material.dart';

// Palette inspired by template_reference/lib/theme/config.dart.
const assessmentBlue = Color(0xFF0396FF);
const assessmentBackground = Color(0xFFF5F6FC);

String clockLabel(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 999999);
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class AssessmentPanel extends StatelessWidget {
  const AssessmentPanel({super.key, required this.child, this.padding = 20});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE5EAF2)),
    ),
    child: child,
  );
}

class AssessmentBanner extends StatelessWidget {
  const AssessmentBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.auto_awesome_outlined,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [Color(0xFF0396FF), Color(0xFF68BFFF)],
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 36),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class OpenAnswerField extends StatefulWidget {
  const OpenAnswerField({
    super.key,
    required this.answer,
    required this.onChanged,
    required this.enabled,
  });
  final String answer;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  State<OpenAnswerField> createState() => _OpenAnswerFieldState();
}

class _OpenAnswerFieldState extends State<OpenAnswerField> {
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.answer);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: widget.enabled,
    minLines: 4,
    maxLines: 8,
    onChanged: widget.onChanged,
    decoration: const InputDecoration(
      labelText: 'Votre réponse',
      hintText: 'Expliquez votre raisonnement…',
      border: OutlineInputBorder(),
    ),
  );
}
