import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../shared/widgets/ui.dart';
import '../../data/courses_repository.dart';
import '../../models/course_models.dart';
import '../widgets/course_widgets.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.repository,
    required this.document,
    this.initialPage = 1,
    this.excerpt,
  });
  final CoursesRepository repository;
  final CourseDocument document;
  final int initialPage;
  final String? excerpt;
  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final controller = PdfViewerController();
  late Future<Uint8List> data;
  int page = 1, total = 0;
  @override
  void initState() {
    super.initState();
    page = widget.initialPage;
    data = widget.repository.content(widget.document.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.document.name, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Document metadata',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Document details'),
              content: Text(
                '${widget.document.name}\n${sizeLabel(widget.document.size)}\nImported ${dateLabel(widget.document.uploadedAt)}\n${total == 0 ? 'Loading pages' : '$total pages'}\n${widget.repository.isLocal ? 'Local session storage' : 'Course server'}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.info_outline),
        ),
      ],
    ),
    body: Column(
      children: [
        if (widget.excerpt != null)
          ExpansionTile(
            title: Text('Source passage · Page ${widget.initialPage}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(widget.excerpt!),
              ),
            ],
          ),
        Expanded(
          child: FutureBuilder<Uint8List>(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return PageBody(
                  children: [
                    CourseError(
                      'Cannot open this PDF. It may have been removed or the server is unavailable.',
                      retry: () => setState(
                        () => data = widget.repository.content(
                          widget.document.id,
                        ),
                      ),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return PdfViewer.data(
                snapshot.data!,
                sourceName: widget.document.id,
                controller: controller,
                initialPageNumber: widget.initialPage,
                passwordProvider: () async => null,
                params: PdfViewerParams(
                  onViewerReady: (doc, _) {
                    if (mounted) {
                      setState(() {
                        total = doc.pages.length;
                        page = widget.initialPage.clamp(1, total);
                      });
                    }
                  },
                  onPageChanged: (p) {
                    if (mounted && p != null) setState(() => page = p);
                  },
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: total > 0 && page > 1
                    ? () => controller.goToPage(pageNumber: page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Page $page / ${total == 0 ? '…' : total}'),
              IconButton(
                tooltip: 'Next page',
                onPressed: total > 0 && page < total
                    ? () => controller.goToPage(pageNumber: page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: 'Zoom out',
                onPressed: total > 0 ? () => controller.zoomDown() : null,
                icon: const Icon(Icons.zoom_out),
              ),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: total > 0 ? () => controller.zoomUp() : null,
                icon: const Icon(Icons.zoom_in),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
