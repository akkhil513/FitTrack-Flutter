import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hands [content] to the browser as a file download. Returns true once the download was started.
Future<bool> downloadTextFile({
  required String filename,
  required String mimeType,
  required String content,
}) async {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.append(link);
  link.click();
  link.remove();
  // Keep the blob alive long enough for the browser to start reading it.
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}
