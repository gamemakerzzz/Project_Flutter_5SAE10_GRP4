import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/flashcard_repository.dart';
import 'flashcards_screen.dart';

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key, required this.repo});
  final FlashcardRepository repo;
  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final title = TextEditingController();
  PlatformFile? file;
  int count = 10;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final chosen = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (chosen == null || !mounted) return;
      final size = await chosen.length();
      if (!mounted) return;
      if (size == null || size > 10 * 1024 * 1024) {
        setState(() => error = 'Le PDF doit faire moins de 10 Mo.');
        return;
      }
      setState(() {
        file = chosen;
        title.text = chosen.name.replaceFirst(
          RegExp(r'\.pdf$', caseSensitive: false),
          '',
        );
        error = null;
      });
      await generate();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Impossible d’ouvrir ce fichier. Réessayez.');
      }
    }
  }

  Future<void> generate() async {
    if (file == null || title.text.trim().isEmpty) {
      setState(() => error = 'Choisissez un PDF et donnez un titre au paquet.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final deck = await widget.repo.generate(
        bytes: await file!.readAsBytes(),
        filename: file!.name,
        title: title.text.trim(),
        count: count,
      );
      if (mounted) Navigator.pop(context, deck);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is FormatException ? e.message : e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Créer avec Claude Sonnet 5.5'),
      content: SizedBox(
        width: 490,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisissez votre PDF : Claude Sonnet 5.5 génère automatiquement vos questions et réponses. Le texte du cours est envoyé à Anthropic.',
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 22),
              InkWell(
                onTap: busy ? null : pick,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F1FD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD8D0F5)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.upload_file, color: purple, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        file?.name ?? 'Importer un PDF et générer',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'PDF • 10 Mo maximum • 100 pages maximum',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: title,
                enabled: !busy,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Nom du paquet'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: count,
                decoration: const InputDecoration(
                  labelText: 'Nombre de cartes souhaité',
                ),
                items: [5, 10, 15, 20]
                    .map(
                      (n) =>
                          DropdownMenuItem(value: n, child: Text('$n cartes')),
                    )
                    .toList(),
                onChanged: busy ? null : (n) => setState(() => count = n!),
              ),
              const SizedBox(height: 12),
              const Text(
                'Génération IA avec Claude • Cartes et progression enregistrées sur cet appareil.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: LinearProgressIndicator(),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: busy
              ? null
              : file == null
              ? pick
              : generate,
          icon: const Icon(Icons.auto_awesome, size: 17),
          label: Text(
            busy
                ? 'Claude analyse le PDF…'
                : file == null
                ? 'Choisir mon PDF'
                : 'Réessayer la génération',
          ),
        ),
      ],
    ),
  );
}
