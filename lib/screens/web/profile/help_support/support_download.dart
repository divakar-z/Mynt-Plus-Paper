import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

/// Hands already-fetched bytes to the browser as a download.
///
/// The client API exposes no download URL — deliberately, since one would
/// carry its own auth knowing nothing about ticket ownership — so the bytes
/// come through the authenticated route and are turned into a download here
/// rather than linked to.
void saveSupportAttachment(List<int> bytes, String filename) {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  // Revoked immediately: the click has already handed the blob to the browser,
  // and holding the URL open leaks the bytes for the life of the tab.
  html.Url.revokeObjectUrl(url);
}

/// Publishes bytes as a blob URL the browser can render in an `<iframe>`.
///
/// Used for PDFs: Chrome, Edge, Firefox and Safari all ship a PDF viewer with
/// paging, zoom and print already in it, so embedding one beats adding a
/// rendering package and reimplementing all of that.
///
/// Registers a view factory under [viewType]. The caller is responsible for
/// calling [releaseSupportBlob] when the view goes away — a blob URL holds its
/// bytes in memory for the life of the tab otherwise.
String publishSupportBlob(
  List<int> bytes, {
  required String viewType,
  required String mimeType,
}) {
  final url = html.Url.createObjectUrlFromBlob(
    html.Blob([bytes], mimeType),
  );
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int _) => html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%',
  );
  return url;
}

void releaseSupportBlob(String url) => html.Url.revokeObjectUrl(url);

/// One file taken off a browser drag-and-drop.
typedef DroppedFile = ({String name, int size, Uint8List bytes});

/// Listens for files dropped anywhere in the window.
///
/// Window-wide rather than scoped to the drop zone's rectangle: the zone only
/// listens while it is on screen, and it is only ever on screen inside a modal
/// dialog — so "anywhere in the window" and "on the dialog" are the same place.
/// Hit-testing a Flutter widget from a DOM event would mean mapping coordinates
/// across the two, for no gain here.
///
/// `dragover` must be cancelled or the browser navigates to the file instead of
/// handing it over — the default action for a drop is "open this".
///
/// Returns a disposer. Call it when the zone goes away, or the listeners
/// outlive the dialog and keep firing into a dead callback.
void Function() listenForFileDrops(
  void Function(List<DroppedFile> files) onFiles, {
  void Function(bool active)? onHoverChanged,
}) {
  var depth = 0;

  void over(html.Event e) => e.preventDefault();

  void enter(html.Event e) {
    e.preventDefault();
    // Entering a child element fires `dragleave` on the parent, so a plain
    // boolean flickers off as the pointer crosses anything inside. Counting
    // enters against leaves is what keeps the highlight steady.
    depth++;
    if (depth == 1) onHoverChanged?.call(true);
  }

  void leave(html.Event e) {
    e.preventDefault();
    depth = (depth - 1).clamp(0, 1 << 30);
    if (depth == 0) onHoverChanged?.call(false);
  }

  Future<void> drop(html.Event e) async {
    e.preventDefault();
    depth = 0;
    onHoverChanged?.call(false);
    final transfer = (e as html.MouseEvent).dataTransfer;
    final picked = transfer.files;
    if (picked == null || picked.isEmpty) return;

    final out = <DroppedFile>[];
    for (final file in picked) {
      final reader = html.FileReader()..readAsArrayBuffer(file);
      await reader.onLoadEnd.first;
      final result = reader.result;
      if (result is! Uint8List) continue;
      out.add((name: file.name, size: file.size, bytes: result));
    }
    if (out.isNotEmpty) onFiles(out);
  }

  html.document.addEventListener('dragover', over);
  html.document.addEventListener('dragenter', enter);
  html.document.addEventListener('dragleave', leave);
  html.document.addEventListener('drop', drop);

  return () {
    html.document.removeEventListener('dragover', over);
    html.document.removeEventListener('dragenter', enter);
    html.document.removeEventListener('dragleave', leave);
    html.document.removeEventListener('drop', drop);
  };
}
