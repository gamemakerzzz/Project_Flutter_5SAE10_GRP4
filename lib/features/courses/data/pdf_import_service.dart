import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/course_models.dart';

abstract final class PdfValidation {
  static const maxBytes = 20 * 1024 * 1024;
  static void metadata(String name, int size) {
    if (!name.toLowerCase().endsWith('.pdf')) {
      throw const CoursesException('Choose a PDF file (.pdf).');
    }
    if (size <= 0) throw const CoursesException('This file is empty.');
    if (size > maxBytes) {
      throw const CoursesException('The maximum PDF size is 20 MB.');
    }
  }

  static void validate(SelectedPdf pdf) {
    metadata(pdf.name, pdf.bytes.length);
    if (pdf.bytes.length < 5 ||
        String.fromCharCodes(pdf.bytes.take(5)) != '%PDF-') {
      throw const CoursesException(
        'This file does not contain a valid PDF header.',
      );
    }
  }
}

class PdfImportService {
  Future<SelectedPdf?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Choose a course PDF',
    );
    if (file == null) return null;
    final knownSize = file.lengthSync();
    if (knownSize != null) {
      PdfValidation.metadata(file.name, knownSize);
    }
    final builder = BytesBuilder(copy: false);
    await for (final bytes in file.readAsByteStream()) {
      if (builder.length + bytes.length > PdfValidation.maxBytes) {
        throw const CoursesException('The maximum PDF size is 20 MB.');
      }
      builder.add(bytes);
    }
    final pdf = SelectedPdf(file.name, builder.takeBytes());
    PdfValidation.validate(pdf);
    return pdf;
  }
}

abstract class PdfTextExtractor {
  Future<List<String>> pages(Uint8List bytes);
}

class PdfrxTextExtractor implements PdfTextExtractor {
  @override
  Future<List<String>> pages(Uint8List bytes) async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(
      bytes,
      passwordProvider: () async => null,
    );
    try {
      if (document.pages.length > 250) {
        throw const CoursesException(
          'Local indexing supports up to 250 pages per PDF.',
        );
      }
      final result = <String>[];
      var characters = 0;
      for (final page in document.pages) {
        final text = (await page.loadText())?.fullText ?? '';
        characters += text.length;
        if (characters > 1000000) {
          throw const CoursesException(
            'This PDF exceeds the local text indexing limit.',
          );
        }
        result.add(text);
      }
      return result;
    } finally {
      await document.dispose();
    }
  }
}

List<SourcePassage> chunkPages(CourseDocument doc, List<String> pages) {
  final chunks = <SourcePassage>[];
  for (var page = 0; page < pages.length; page++) {
    final text = pages[page].replaceAll(RegExp(r'\s+'), ' ').trim();
    var start = 0;
    var index = 0;
    while (start < text.length) {
      var end = (start + 900).clamp(0, text.length);
      if (end < text.length) {
        final boundary = text.lastIndexOf(' ', end);
        if (boundary > start + 450) end = boundary;
        // Preserve supplementary Unicode characters at hard boundaries.
        if (text.codeUnitAt(end - 1) >= 0xD800 &&
            text.codeUnitAt(end - 1) <= 0xDBFF &&
            text.codeUnitAt(end) >= 0xDC00 &&
            text.codeUnitAt(end) <= 0xDFFF) {
          end--;
        }
      }
      chunks.add(
        SourcePassage(
          chunkId: '${doc.id}:p${page + 1}:c${index++}',
          documentId: doc.id,
          courseId: doc.courseId,
          documentName: doc.name,
          page: page + 1,
          excerpt: text.substring(start, end),
        ),
      );
      if (end == text.length) break;
      start = end;
      while (start < text.length && text[start] == ' ') {
        start++;
      }
    }
  }
  return chunks;
}
