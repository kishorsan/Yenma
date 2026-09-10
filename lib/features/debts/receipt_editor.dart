import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/receipt_source.dart';
import '../../domain/debt.dart';

class ReceiptEditor extends StatefulWidget {
  const ReceiptEditor({
    super.key,
    required this.source,
    required this.bytes,
    required this.onChanged,
    this.hasSavedReceipt = false,
    this.enabled = true,
    this.onBusyChanged,
  });
  final ReceiptSource source;
  final Uint8List? bytes;
  final bool hasSavedReceipt;
  final bool enabled;
  final ValueChanged<Uint8List?> onChanged;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<ReceiptEditor> createState() => _ReceiptEditorState();
}

class _ReceiptEditorState extends State<ReceiptEditor> {
  bool _picking = false;
  String? _error;
  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      final bytes = await widget.source.pick();
      if (bytes != null && mounted) widget.onChanged(bytes);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is DebtValidationException
              ? error.message
              : 'Image could not be selected. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receipt or UPI screenshot',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional · one image, up to 10 MB · saved on this device',
          ),
          if (widget.bytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                widget.bytes!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.contain,
                cacheWidth: 600,
                errorBuilder: (_, _, _) => const Text(
                  'Preview unavailable. Please choose another image.',
                ),
              ),
            ),
          ],
          if (widget.hasSavedReceipt && widget.bytes == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Saved screenshot attached'),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: widget.enabled && !_picking ? _pick : null,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _picking
                      ? 'Opening photos…'
                      : widget.bytes != null || widget.hasSavedReceipt
                      ? 'Replace screenshot'
                      : 'Attach screenshot',
                ),
              ),
              if (widget.bytes != null || widget.hasSavedReceipt)
                TextButton(
                  onPressed: widget.enabled && !_picking
                      ? () => widget.onChanged(null)
                      : null,
                  child: const Text('Remove screenshot'),
                ),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}
