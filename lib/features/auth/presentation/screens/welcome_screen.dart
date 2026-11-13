import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../view_models/session_controller.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBody(
      maxWidth: 520,
      children: [
        const SizedBox(height: 16),
        const Center(child: Brand()),
        const SizedBox(height: 38),
        Container(
          height: 240,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8E0FF), Color(0xFFDBE9FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(36),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -.12,
                child: Container(
                  width: 140,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Transform.rotate(
                angle: .08,
                child: Container(
                  width: 128,
                  height: 146,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6544C4),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6544C4).withValues(alpha: .2),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
              ),
              const Positioned(
                top: 24,
                right: 28,
                child: Chip(
                  avatar: Icon(Icons.auto_awesome, size: 18),
                  label: Text('Made for your potential'),
                ),
              ),
              const Positioned(
                bottom: 22,
                left: 20,
                child: Chip(
                  avatar: Icon(
                    Icons.check_circle,
                    color: Color(0xFF438568),
                    size: 18,
                  ),
                  label: Text('A little progress, every day'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'YOUR NEXT CHAPTER STARTS HERE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Learn Smarter,\nAchieve More',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        const Text(
          'Your studies, beautifully organized. Build better habits and make room for your biggest ideas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: () => openPage(context, RegisterScreen(session: session)),
          child: const Text('Get Started'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => openPage(context, LoginScreen(session: session)),
          child: const Text('I already have an account'),
        ),
        const SizedBox(height: 20),
        DemoNote(
          text: session.isDemo
              ? 'Interactive demo · No real account or AI service is connected.'
              : 'Your courses and PDFs are saved to your StudyMate account. Ask questions with local AI and check the source pages.',
        ),
        if (session.restoreError != null)
          Text(
            session.restoreError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
