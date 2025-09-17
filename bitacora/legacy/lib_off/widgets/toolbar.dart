// lib/widgets/toolbar.dart
import 'package:flutter/material.dart';

class Toolbar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onSave;
  final VoidCallback onExport;

  const Toolbar({
    super.key,
    required this.onAdd,
    required this.onSave,
    required this.onExport,
  });

  static const _pad = EdgeInsets.symmetric(horizontal: 14, vertical: 7);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey[900] : Colors.grey[100];

    return Container(
      color: bg,
      padding: _pad,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _ToolBtn(
            icon: Icons.add,
            label: 'Nueva fila',
            tooltip: 'Agregar una nueva fila',
            color: Colors.cyan[400],
            onTap: onAdd,
          ),
          _ToolBtn(
            icon: Icons.save,
            label: 'Guardar',
            tooltip: 'Guardar planilla',
            color: Colors.blue[700],
            onTap: onSave,
          ),
          _ToolBtn(
            icon: Icons.upload_file,
            label: 'Exportar',
            tooltip: 'Exportar datos',
            color: Colors.green[700],
            onTap: onExport,
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final Color? color;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(80, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    );

    return (tooltip != null && tooltip!.isNotEmpty)
        ? Tooltip(message: tooltip!, child: btn)
        : btn;
  }
}
