import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/license_manager.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({
    super.key,
    required this.manager,
    required this.status,
    required this.onActivated,
  });

  final LicenseManager manager;
  final LicenseStatus status;
  final VoidCallback onActivated;

  @override
  State<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _msg;

  static const _purchaseUrl = 'https://gridnote.app/licencias';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() { _busy = true; _msg = null; });
    final token = _ctrl.text.trim();
    final ok = await widget.manager.activate(token);
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() { _busy = false; _msg = ok ? 'Licencia activada' : 'Clave inválida'; });
    if (ok) widget.onActivated();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    _ctrl.text = data?.text?.trim() ?? '';
  }

  Future<void> _openBuy() async {
    final uri = Uri.parse(_purchaseUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0E0E10) : const Color(0xFFF7F7F8);
    final card = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF141417) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              color: card,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gridnote • Licencia requerida', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(widget.status.hasValidLicense ? 'Tu licencia venció.' : 'Tu prueba terminó.', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    if (widget.status.expiresAtUtc != null)
                      Text(
                        'Expiró: ${widget.status.expiresAtUtc!.toLocal()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _ctrl,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Clave de activación',
                        hintText: 'pega aquí tu clave firmada',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(onPressed: _busy ? null : _paste, icon: const Icon(Icons.paste), tooltip: 'Pegar'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : _activate,
                            child: _busy
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Activar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _openBuy,
                          icon: const Icon(Icons.shopping_cart_outlined),
                          label: const Text('Comprar licencia'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: cs.primary.withOpacity(.5)),
                          ),
                        ),
                      ],
                    ),
                    if (_msg != null) ...[
                      const SizedBox(height: 10),
                      Text(_msg!, style: TextStyle(color: _msg == 'Licencia activada' ? Colors.green : Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
