import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _endpointCtl = TextEditingController();
  final _emailCtl = TextEditingController();

  bool _loading = true;
  late final SettingsService _settings;
  ChangeNotifier? _maybeNotifier;

  @override
  void initState() {
    super.initState();
    _settings = SettingsService.instance;
    _maybeNotifier = _settings as ChangeNotifier;
    _maybeNotifier!.addListener(_onServiceChanged);
      _load();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    await _settings.init();
    final snap = await _settings.snapshot();
    if (!mounted) return;
    setState(() {
      _endpointCtl.text = snap.endpoint ?? '';
      _emailCtl.text = snap.defaultEmail ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _maybeNotifier?.removeListener(_onServiceChanged);
    _endpointCtl.dispose();
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final endpoint = _endpointCtl.text.trim();
    final email = _emailCtl.text.trim();

    setState(() => _loading = true);
    await _settings.setFrom(
      endpoint: endpoint.isEmpty ? null : endpoint,
      defaultEmail: email.isEmpty ? null : email,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferencias guardadas')),
    );
    Navigator.pop(context);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar borrado'),
        content: const Text(
          '¿Borrar todas las configuraciones? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    await _settings.clear();
    if (!mounted) return;
    _endpointCtl.clear();
    _emailCtl.clear();
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuraciones borradas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ajustes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Envío rápido', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextFormField(
                controller: _endpointCtl,
                decoration: const InputDecoration(
                  labelText: 'Endpoint (URL) opcional',
                  hintText: 'https://api.tuempresa.com/upload',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.url],
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return null;
                  return SettingsService.urlValidator(s);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextFormField(
                controller: _emailCtl,
                decoration: const InputDecoration(
                  labelText: 'Email destino por defecto (opcional)',
                  hintText: 'cliente@dominio.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _save(),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return null;
                  return SettingsService.emailValidator(s);
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                '• Si hay endpoint, los Excel se envían por HTTP.\n'
                    '• Si no hay endpoint y hay email, se abre el envío por correo.\n'
                    '• Ambos campos son opcionales; usa el que prefieras.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _clear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
