import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/company_info_service.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class CompanyConfigScreen extends StatefulWidget {
  const CompanyConfigScreen({super.key});
  @override
  State<CompanyConfigScreen> createState() => _CompanyConfigScreenState();
}

class _CompanyConfigScreenState extends State<CompanyConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _mailCtrl = TextEditingController();
  Color _color = Colors.cyan;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await CompanyInfoService.load();
    setState(() {
      _nombreCtrl.text = info.nombre;
      _dirCtrl.text = info.direccion;
      _mailCtrl.text = info.email;
      _color = info.color;
      _logoPath = info.logoPath;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await CompanyInfoService.saveLogo(File(picked.path));
      setState(() => _logoPath = picked.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo actualizado!')),
      );
    }
  }

  Future<void> _pickColor() async {
    Color temp = _color;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ElegÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ un color principal'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: temp,
            onColorChanged: (c) => temp = c,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _color = temp);
              },
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final info = CompanyInfo(
      nombre: _nombreCtrl.text,
      direccion: _dirCtrl.text,
      email: _mailCtrl.text,
      color: _color,
      logoPath: _logoPath,
    );
    await CompanyInfoService.save(info);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos guardados!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Empresa')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        _logoPath != null ? FileImage(File(_logoPath!)) : null,
                    child: _logoPath == null
                        ? const Icon(Icons.image, size: 40)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre empresa'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _dirCtrl,
                decoration: const InputDecoration(labelText: 'DirecciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _mailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Color principal'),
                trailing: CircleAvatar(backgroundColor: _color),
                onTap: _pickColor,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
                onPressed: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
