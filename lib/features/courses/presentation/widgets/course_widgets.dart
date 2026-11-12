import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../models/course_models.dart';

class CourseModeBanner extends StatelessWidget {
  const CourseModeBanner({super.key, required this.local});
  final bool local;
  @override
  Widget build(BuildContext context) => DemoNote(
    text: local
        ? 'Local workspace · PDFs stay in memory until logout or app restart. Text search is real; semantic search and AI generation need the backend.'
        : 'Connected workspace · Results come from your course server.',
  );
}

class CourseError extends StatelessWidget {
  const CourseError(this.message, {super.key, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (retry != null)
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
      ],
    ),
  );
}

String dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String sizeLabel(int size) => size < 1024 * 1024
    ? '${(size / 1024).toStringAsFixed(1)} KB'
    : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
Future<bool> confirmRemoval(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

class DocumentTile extends StatelessWidget {
  const DocumentTile({
    super.key,
    required this.document,
    required this.onOpen,
    this.onRetry,
    this.onDelete,
  });
  final CourseDocument document;
  final VoidCallback onOpen;
  final VoidCallback? onRetry, onDelete;
  @override
  Widget build(BuildContext context) {
    final status = document.status;
    final color = status == ProcessingStatus.failed
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, color: color, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  document.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${sizeLabel(document.size)} · ${dateLabel(document.uploadedAt)}${document.pages == null ? '' : ' · ${document.pages} pages'}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(
                  status.name[0].toUpperCase() + status.name.substring(1),
                ),
              ),
              if (status == ProcessingStatus.processing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open PDF'),
              ),
              if (status == ProcessingStatus.failed ||
                  status == ProcessingStatus.uploaded)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry processing'),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete document',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          if (document.error != null)
            Text(document.error!, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
