// lib/widgets/quick_share_button.dart
import 'package:flutter/material.dart';
import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../theme/gridnote_theme.dart';
import '../services/quick_mail_service.dart';
import '../services/frequent_email_store.dart';
import 'excel_badge_icon.dart';

typedef LoadRows = Future<List<Measurement>> Function();

class QuickShareButton extends StatefulWidget {
  const QuickShareButton({
    super.key,
    required this.meta,
    required this.theme,
    required this.loadRows,
    this.compact = false, // compacto para lista
  });

  final SheetMeta meta;
  final GridnoteTheme theme;
  final LoadRows loadRows;
  final bool compact;

  @override
  State<QuickShareButton> createState() => _QuickShareButtonState();
}

class _QuickShareButtonState extends State<QuickShareButton> {
  final _emailCtrl = TextEditingController();
  final _store = FrequentEmailStore();
  final QuickMailService _mail = const QuickMailService(); // ✅ fijo el error
  bool _sending = false;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _suggestions = await _store.getAll();
    if (_suggestions.isNotEmpty) _emailCtrl.text = _suggestions.first;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _valid(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);

  Future<void> _openDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enviar planilla por correo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo frecuente',
                  hintText: 'nombre@empresa.com',
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _suggestions
                      .map(
                        (e) => ActionChip(
                      label: Text(e),
                      onPressed: () => _emailCtrl.text = e,
                      backgroundColor: cs.surfaceContainerHighest,
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _sending
                        ? null
                        : () async {
                      final email = _emailCtrl.text.trim();
                      if (!_valid(email)) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ingresá un correo válido'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop();
                      setState(() => _sending = true);
                      try {
                        final rows = await widget.loadRows();
                        await _mail.sendSheet(
                          meta: widget.meta,
                          rows: rows,
                          toEmail: email,
                        );
                        await _store.add(email);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Abriendo app de correo para ${widget.meta.name}…',
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _sending = false);
                      }
                    },
                    icon: const ExcelBadgeIcon(size: 18),
                    label: const Text('Enviar Excel'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ExcelBadgeIcon(size: 18),
        if (!widget.compact) const SizedBox(width: 8),
        if (!widget.compact) const Text('Compartir'),
      ],
    );

    return widget.compact
        ? IconButton(
      tooltip: 'Compartir por correo',
      onPressed: _sending ? null : _openDialog,
      icon: const ExcelBadgeIcon(size: 20),
    )
        : TextButton(
      onPressed: _sending ? null : _openDialog,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: const StadiumBorder(),
        backgroundColor: cs.surfaceContainerHighest,
        foregroundColor: cs.onSurfaceVariant,
      ),
      child: child,
    );
  }
}
