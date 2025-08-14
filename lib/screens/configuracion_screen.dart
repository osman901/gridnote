// lib/screens/configuracion_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _logoPath;
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  Color _color = Colors.cyan;

  bool _isLoading = true;

  // --------------- LIFECYCLE ---------------
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // --------------- IO HELPERS ---------------
  Future<Directory> _appDir() => getApplicationDocumentsDirectory();

  Future<File> _jsonFile() async {
    final dir = await _appDir();
    return File(p.join(dir.path, 'empresa_info.json'));
  }

  Future<File> _legacyTxtFile() async {
    final dir = await _appDir();
    return File(p.join(dir.path, 'empresa_info.txt'));
  }

  Future<File> _logoFile() async {
    final dir = await _appDir();
    return File(p.join(dir.path, 'logo_empresa.png'));
  }

  // --------------- LOAD / SAVE ---------------
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Logo (si existe)
      final lf = await _logoFile();
      if (await lf.exists()) _logoPath = lf.path;

      // JSON principal
      final jf = await _jsonFile();
      if (await jf.exists()) {
        final content = await jf.readAsString();
        final m = jsonDecode(content) as Map<String, dynamic>;

        _nombreCtrl.text = (m['nombre'] as String?) ?? '';
        _direccionCtrl.text = (m['direccion'] as String?) ?? '';
        _emailCtrl.text = (m['email'] as String?) ?? '';
        final c = m['color'];
        if (c is int) _color = Color(c);
        final lp = m['logoPath'];
        if (lp is String && lp.isNotEmpty) _logoPath = lp;
      } else {
        // Migración simple desde .txt (legacy)
        final tf = await _legacyTxtFile();
        if (await tf.exists()) {
          try {
            final lines = await tf.readAsLines();
            if (lines.isNotEmpty) _nombreCtrl.text = lines[0];
            if (lines.length >= 2) _direccionCtrl.text = lines[1];
            if (lines.length >= 3) _emailCtrl.text = lines[2];
            if (lines.length >= 4) {
              final parsed = int.tryParse(lines[3]);
              if (parsed != null) _color = Color(parsed);
            }
            // Guarda inmediatamente en JSON y podés borrar el legacy si querés
            await _guardarInfo(silent: true);
            // await tf.delete(); // opcional
          } catch (e) {
            debugPrint('Migración legacy falló: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar la configuración.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarInfo({bool silent = false}) async {
    setState(() => _isLoading = true);
    try {
      final jf = await _jsonFile();
      final tmp = File('${jf.path}.tmp');

      final data = <String, dynamic>{
        'nombre': _nombreCtrl.text,
        'direccion': _direccionCtrl.text,
        'email': _emailCtrl.text,
        'color': _color.value,
        'logoPath': _logoPath,
      };

      await tmp.writeAsString(jsonEncode(data));
      // Escritura atómica: rename sobre el destino
      if (await jf.exists()) {
        try {
          await jf.delete();
        } catch (_) {}
      }
      await tmp.rename(jf.path);

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Datos guardados!')),
        );
      }
    } catch (e) {
      debugPrint('Error al guardar la información: $e');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error: no se pudieron guardar los datos.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _elegirLogoEmpresa() async {
    setState(() => _isLoading = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final lf = await _logoFile();
      // Intentamos copiar (sobrescribe si existe)
      try {
        await File(picked.path).copy(lf.path);
      } on FileSystemException {
        // Si falla por estar en uso, intentamos borrar y copiar de nuevo
        if (await lf.exists()) {
          await lf.delete();
        }
        await File(picked.path).copy(lf.path);
      }
      _logoPath = lf.path;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo guardado correctamente.')),
        );
      }
    } catch (e) {
      debugPrint('Error al elegir/guardar logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar el logo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --------------- UI ---------------
  String? _emailValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // opcional: permitir vacío
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Email inválido';
    // Si querés hacerlo requerido:
    // return s.isEmpty ? 'Requerido' : (ok ? null : 'Email inválido');
  }

  Future<void> _pickColor() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (_) => _ColorPickerDialog(color: _color),
    );
    if (selected != null) {
      setState(() => _color = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          IconButton(
            onPressed: disabled ? null : () => _guardarInfo(),
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_logoPath != null) ...[
                    AspectRatio(
                      aspectRatio: 6, // alto chico para logo horizontal
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Image.file(
                          File(_logoPath!),
                          height: 64,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ElevatedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Cambiar logo de la empresa'),
                    onPressed: disabled ? null : _elegirLogoEmpresa,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la empresa',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !disabled,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _direccionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !disabled,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email de contacto',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !disabled,
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailValidator,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Color institucional:'),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: disabled ? null : _pickColor,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _color,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Icons.edit, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: disabled
                        ? null
                        : () {
                            if (!(_formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            _guardarInfo();
                          },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Guardar datos'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    var current = color;
    return AlertDialog(
      title: const Text('Elegí el color'),
      content: SingleChildScrollView(
        child: BlockPicker(
          pickerColor: color,
          onColorChanged: (c) => current = c,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, current),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
