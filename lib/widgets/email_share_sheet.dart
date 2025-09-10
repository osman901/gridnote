// lib/widgets/email_share_sheet.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

Future<String?> showEmailShareSheet(BuildContext context) async {
  final settings = SettingsService.instance;
  await settings.init();
  final snap = await settings.snapshot();

  final formKey = GlobalKey<FormState>();
  final ctl = TextEditingController(text: snap.defaultEmail ?? '');
  bool guardar = (snap.defaultEmail ?? '').isNotEmpty;

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true, // <- permite crecer con el teclado
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final inset = MediaQuery.viewInsetsOf(ctx).bottom;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, inset + 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Theme.of(ctx).colorScheme.surface,
              child: SingleChildScrollView( // <- evita overflow
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Enviar por correo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Podés guardar el email como frecuente',
                          style: TextStyle(color: Theme.of(ctx).hintColor)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ctl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email destino',
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => SettingsService.emailValidator((v ?? '').trim()),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: guardar,
                        onChanged: (v) => guardar = v ?? false,
                        title: const Text('Guardar como frecuente'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await settings.setFrom(defaultEmail: null);
                              ctl.clear();
                              Navigator.pop(ctx); // cerrar; el usuario puede reabrir
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Borrar guardado'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              if (!(formKey.currentState?.validate() ?? false)) return;
                              final email = ctl.text.trim();
                              if (guardar) {
                                await settings.setFrom(defaultEmail: email.isEmpty ? null : email);
                              }
                              Navigator.pop(ctx, email);
                            },
                            child: const Text('Aceptar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  return result; // null si canceló
}
