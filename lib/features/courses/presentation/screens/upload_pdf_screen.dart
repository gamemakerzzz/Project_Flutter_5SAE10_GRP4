import 'package:flutter/material.dart';

import '../../../../shared/widgets/ui.dart';
import '../../data/pdf_import_service.dart';
import '../../models/course_models.dart';
import '../view_models/courses_view_model.dart';
import '../widgets/course_widgets.dart';

class UploadPdfScreen extends StatefulWidget {
  const UploadPdfScreen({
    super.key,
    required this.model,
    required this.courseId,
    this.importer,
  });
  final CoursesViewModel model;
  final String courseId;
  final PdfImportService? importer;
  @override
  State<UploadPdfScreen> createState() => _UploadPdfScreenState();
}

class _UploadPdfScreenState extends State<UploadPdfScreen> {
  SelectedPdf? pdf;
  String? error;
  bool busy = false;
  late String destination;
  @override
  void initState() {
    super.initState();
    destination = widget.courseId;
  }

  Future<void> pick() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await (widget.importer ?? PdfImportService()).pick();
      if (mounted && result != null) setState(() => pdf = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is CoursesException
              ? e.message
              : 'Cannot read this file. Choose an accessible PDF and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> upload() async {
    if (pdf == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await widget.model.importPdf(destination, pdf!);
    if (!mounted) return;
    setState(() => busy = false);
    if (result == null) {
      setState(
        () => error = widget.model.error ?? 'Import failed. Please retry.',
      );
      return;
    }
    Navigator.pop(context);
    notice(
      context,
      result.status == ProcessingStatus.failed
          ? 'PDF imported, but indexing failed. Open the course to see the error and retry.'
          : widget.model.isLocal
          ? 'PDF imported and indexed locally. Nothing was uploaded to a server.'
          : 'Server accepted the PDF. Processing status appears in the course.',
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Upload PDF')),
      body: PageBody(
        maxWidth: 600,
        children: [
          Text(
            'Make room for new knowledge.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          CourseModeBanner(local: widget.model.isLocal),
          const SizedBox(height: 24),
          Panel(
            child: Column(
              children: [
                Icon(
                  Icons.upload_file_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  pdf?.name ?? 'Bring your course material',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  pdf == null
                      ? 'PDF only · Up to 20 MB\nText PDFs work best. Scans need OCR, which is not enabled.'
                      : sizeLabel(pdf!.bytes.length),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: busy ? null : pick,
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    pdf == null ? 'Select PDF' : 'Choose another PDF',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: destination,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Destination course / subject',
            ),
            items: widget.model.courses
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.title} · ${c.subject}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: busy ? null : (v) => setState(() => destination = v!),
          ),
          const SizedBox(height: 20),
          if (error != null) CourseError(error!),
          if (busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Reading or processing your PDF… Please keep this screen open. No estimated percentage is shown.',
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: pdf == null || busy || widget.model.working
                ? null
                : upload,
            icon: const Icon(Icons.check),
            label: Text(
              widget.model.isLocal
                  ? 'Import into local workspace'
                  : 'Upload to course',
            ),
          ),
        ],
      ),
    ),
  );
}
