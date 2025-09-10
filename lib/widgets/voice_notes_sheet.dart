import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dictation_service.dart';

Future<void> showVoiceNotesBottomSheet(
    BuildContext context, {
      required String sheetId,
      Color? accent,
      String localeId = 'es_AR',
    }) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _VoiceNotesSheet(
        sheetId: sheetId,
        accent: accent,
        localeId: localeId,
      );
    },
  );
}

class _VoiceNotesSheet extends StatefulWidget {
  const _VoiceNotesSheet({
    required this.sheetId,
    this.accent,
    required this.localeId,
  });

  final String sheetId;
  final Color? accent;
  final String localeId;

  @override
  State<_VoiceNotesSheet> createState() => _VoiceNotesSheetState();
}

class _VoiceNotesSheetState extends State<_VoiceNotesSheet> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _listening = false;
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _load();
    DictationService.instance.states.listen((s) {
      if (!mounted) return;
      setState(() {
        _listening = s.listening;
        _level = s.level;
      });
    });
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    _ctrl.text = sp.getString('note_${widget.sheetId}') ?? '';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('note_${widget.sheetId}', _ctrl.text);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await DictationService.instance.stop();
      return;
    }
    await DictationService.instance.start(
      localeId: widget.localeId,
      onFinalText: (chunk) {
        // Agrega el texto final con un espacio.
        final sep = _ctrl.text.isEmpty ? '' : (_ctrl.text.endsWith(' ') ? '' : ' ');
        _ctrl.text = '${_ctrl.text}$sep$chunk';
        _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final primary = widget.accent ?? Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: _loading
            ? const SizedBox(height: 280, child: Center(child: CircularProgressIndicator()))
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra superior
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  const Text('Parte diario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  FilledButton(
                    style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(primary)),
                    onPressed: _save,
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),

            // Editor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Dictá o escribí tu parte diario…',
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Controles de dictado
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleListen,
                    icon: Icon(_listening ? Icons.stop : Icons.mic),
                    label: Text(_listening ? 'Detener' : 'Dictar'),
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(_listening ? Colors.red : primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Indicador simple de nivel de voz
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: LinearProgressIndicator(
                          value: _listening ? (0.15 + 0.85 * _level) : 0,
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
