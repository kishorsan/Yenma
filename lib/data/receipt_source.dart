import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/debt.dart';

/// Supplies validated receipt-image bytes to transaction and debt forms.
abstract interface class ReceiptSource {
  /// Lets the user select one receipt image, or returns `null` if cancelled.
  Future<Uint8List?> pick();

  /// Recovers an interrupted Android image-picker request when available.
  Future<Uint8List?> recover();
}

/// Receipt source backed by `image_picker` with size and decode validation.
class ImageReceiptSource implements ReceiptSource {
  final _picker = ImagePicker();
  @override
  Future<Uint8List?> pick() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    return image == null ? null : _read(image);
  }

  @override
  Future<Uint8List?> recover() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final response = await _picker.retrieveLostData();
      if (response.exception != null) throw response.exception!;
      final image = response.files?.firstOrNull;
      return image == null ? null : await _read(image);
    } on MissingPluginException {
      return null;
    }
  }

  /// Reads [image] only after enforcing the receipt limit and decoding it.
  Future<Uint8List> _read(XFile image) async {
    if (await image.length() > maxReceiptBytes) {
      throw const DebtValidationException(
        'Choose an image smaller than 10 MB.',
      );
    }
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxReceiptBytes) {
      throw const DebtValidationException(
        'Choose an image smaller than 10 MB.',
      );
    }
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1600,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      throw const DebtValidationException(
        'This image could not be opened. Try a JPG, PNG or WebP screenshot.',
      );
    }
    return bytes;
  }
}
