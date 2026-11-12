import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:smart_learning/features/courses/data/pdf_import_service.dart';

import 'pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDFium extracts the real two-page PDF and renders a page', () async {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
    final bytes = coursePdfFixture();
    final pages = await PdfrxTextExtractor().pages(bytes);
    expect(pages.length, 2);
    expect(pages[0], contains('Supervised learning uses labelled examples.'));
    expect(
      pages[1],
      contains('Unsupervised learning discovers patterns without labels.'),
    );
    final doc = await PdfDocument.openData(bytes);
    try {
      final rendered = await doc.pages[1].render(width: 306, height: 396);
      expect(rendered, isNotNull);
      expect(rendered!.width, 306);
      rendered.dispose();
    } finally {
      await doc.dispose();
    }
  });
}
