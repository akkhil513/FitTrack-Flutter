import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _maxEdge = 1600;
const _maxBytes = 1900000; // server limit is 2,000,000
const _qualities = [0.85, 0.72, 0.6, 0.45];

/// Lets the user choose a photo and returns it as a downsized JPEG.
///
/// Drawing the image onto a canvas and re-encoding it drops all metadata (EXIF, including GPS
/// location) and applies the camera's rotation. Returns null when the user cancels.
Future<Uint8List?> pickJpegPhoto() async {
  final chosen = Completer<web.File?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = 'image/*';
  input.addEventListener(
    'change',
    ((web.Event _) {
      if (chosen.isCompleted) return;
      final files = input.files;
      chosen.complete(files != null && files.length > 0 ? files.item(0) : null);
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!chosen.isCompleted) chosen.complete(null);
    }).toJS,
  );
  input.click();

  final file = await chosen.future;
  if (file == null) return null;
  return _toJpeg(file);
}

Future<Uint8List> _toJpeg(web.File file) async {
  final url = web.URL.createObjectURL(file);
  try {
    final img = web.HTMLImageElement()..src = url;
    await img.decode().toDart;

    var w = img.naturalWidth;
    var h = img.naturalHeight;
    if (w <= 0 || h <= 0) throw StateError('Unreadable image');
    final longest = w > h ? w : h;
    if (longest > _maxEdge) {
      final scale = _maxEdge / longest;
      w = (w * scale).round();
      h = (h * scale).round();
    }

    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(img, 0, 0, w, h);

    Uint8List? best;
    for (final quality in _qualities) {
      final done = Completer<web.Blob?>();
      canvas.toBlob(
        ((web.Blob? b) => done.complete(b)).toJS,
        'image/jpeg',
        quality.toJS,
      );
      final blob = await done.future;
      if (blob == null) throw StateError('Could not encode the image');
      final buffer = await blob.arrayBuffer().toDart;
      best = buffer.toDart.asUint8List();
      if (best.length <= _maxBytes) return best;
    }
    throw StateError('Photo is too large');
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
