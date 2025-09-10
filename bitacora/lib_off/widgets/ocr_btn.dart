import 'package:flutter/material.dart';

typedef OnOcrValues = void Function(double? ohm1, double? ohm3);

/// BotÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n OCR (placeholder): abre un mini formulario para ingresar 1m/3m.
/// MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s adelante podÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s cambiar la lÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³gica por OCR real.
class OcrBtn extends StatelessWidget {
  const OcrBtn({super.key, required this.onValues});
  final OnOcrValues onValues;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Leer con OCR',
      icon: const Icon(Icons.document_scanner_outlined),
      onPressed: () async {
        final r = await showDialog<({double? o1, double? o3})>(
          context: context,
          builder: (_) => const _OcrDialog(),
        );
        if (r != null) onValues(r.o1, r.o3);
      },
    );
  }
}

class _OcrDialog extends StatefulWidget {
  const _OcrDialog();

  @override
  State<_OcrDialog> createState() => _OcrDialogState();
}

class _OcrDialogState extends State<_OcrDialog> {
  final _c1 = TextEditingController();
  final _c3 = TextEditingController();

  double? _p(String t) {
    final x = t.replaceAll(',', '.').trim();
    return x.isEmpty ? null : double.tryParse(x);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('OCR (placeholder)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _c1, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '1m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)')),
          TextField(controller: _c3, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '3m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (o1: _p(_c1.text), o3: _p(_c3.text))),
          child: const Text('Usar'),
        ),
      ],
    );
  }
}
