import 'dart:html' as html;
import 'dart:typed_data';

/// Trigger a browser download of an .xlsx blob fetched from the backend.
void triggerXlsxDownload({
  required Uint8List bytes,
  String? filename,
  String fallbackName = 'export.xlsx',
}) {
  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename ?? fallbackName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
