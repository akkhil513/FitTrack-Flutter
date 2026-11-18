/// Saves [content] as a file. Only the web build can do this; elsewhere it reports false.
Future<bool> downloadTextFile({
  required String filename,
  required String mimeType,
  required String content,
}) async =>
    false;
