import 'dart:convert';
import 'dart:typed_data';

/// Minimal two-page PDF fixture, with real xref offsets and page contents.
Uint8List coursePdfFixture({
  List<String> texts = const [
    'Supervised learning uses labelled examples.',
    'Unsupervised learning discovers patterns without labels.',
  ],
}) {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [${List.generate(texts.length, (i) => '${3 + i * 2} 0 R').join(' ')}] /Count ${texts.length} >>',
  ];
  for (var i = 0; i < texts.length; i++) {
    final contentId = 4 + i * 2;
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 ${3 + texts.length * 2} 0 R >> >> /Contents $contentId 0 R >>',
    );
    final escaped = texts[i]
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
    final stream = 'BT /F1 16 Tf 50 700 Td ($escaped) Tj ET';
    objects.add(
      '<< /Length ${latin1.encode(stream).length} >>\nstream\n$stream\nendstream',
    );
  }
  objects.add(
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
  );
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(latin1.encode(out.toString()).length);
    out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = latin1.encode(out.toString()).length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    out.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(latin1.encode(out.toString()));
}
