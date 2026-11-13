import 'package:pdfrx_engine/pdfrx_engine.dart';

class PdfService {
  Future<List<String>> extract(String path) async {
    await pdfrxInitialize();
    final pdf = await PdfDocument.openFile(
      path,
      passwordProvider: () async => null,
    );
    try {
      if (pdf.pages.length > 250) {
        throw const FormatException('Maximum 250 pages supported.');
      }
      final pages = <String>[];
      var total = 0;
      for (final page in pdf.pages) {
        final text = (await page.loadText())?.fullText ?? '';
        total += text.length;
        if (total > 1000000) {
          throw const FormatException(
            'Document exceeds the text indexing limit.',
          );
        }
        pages.add(text);
      }
      if (pages.every((p) => p.trim().isEmpty)) {
        throw const FormatException(
          'No extractable text. Image-only PDFs require OCR, which is not available.',
        );
      }
      return pages;
    } finally {
      await pdf.dispose();
    }
  }
}

List<({int page, int index, String text})> chunks(List<String> pages) {
  final result = <({int page, int index, String text})>[];
  for (var page = 0; page < pages.length; page++) {
    final text = pages[page].replaceAll(RegExp(r'\s+'), ' ').trim();
    var start = 0, index = 0;
    while (start < text.length) {
      var end = (start + 900).clamp(0, text.length);
      if (end < text.length) {
        final space = text.lastIndexOf(' ', end);
        if (space > start + 450) end = space;
        // A hard boundary must not split a supplementary Unicode character.
        if (text.codeUnitAt(end - 1) >= 0xD800 &&
            text.codeUnitAt(end - 1) <= 0xDBFF &&
            text.codeUnitAt(end) >= 0xDC00 &&
            text.codeUnitAt(end) <= 0xDFFF) {
          end--;
        }
      }
      result.add((
        page: page + 1,
        index: index++,
        text: text.substring(start, end),
      ));
      start = end;
      while (start < text.length && text[start] == ' ') {
        start++;
      }
    }
  }
  return result;
}
