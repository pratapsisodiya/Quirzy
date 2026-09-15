import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

/// Captures a widget (via a [RepaintBoundary] key) as a PNG and opens the
/// native share sheet — used for the My Prep shareable score card.
class ShareCardService {
  static Future<void> shareFromKey(GlobalKey key) async {
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;

    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'my_prep_progress.png')],
        text: "Here's my practice progress on Quirzy!",
      ),
    );
  }
}
