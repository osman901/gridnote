// lib/widgets/spreadsheet_menu.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Meta de cada planilla almacenada.
class SheetMeta {
  SheetMeta({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  String name;
  DateTime createdAt;
  DateTime updatedAt;
  double? latitude;
  double? longitude;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lat': latitude,
        'lon': longitude,
      };

  static SheetMeta fromJson(Map<String, dynamic> j) => SheetMeta(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        latitude: (j['lat'] as num?)?.toDouble(),
        longitude: (j['lon'] as num?)?.toDouble(),
      );
}

/// Persistencia simple con SharedPreferences.
class SheetsStore {
  static const _key = 'gridnote.sheets.v1';

  static Future<List<SheetMeta>> list() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final data = sp.getStringList(_key) ?? const <String>[];
      return data
          .map((s) => SheetMeta.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // En caso de corrupciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n, devolvemos vacÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­o (evita crashear la UI).
      return <SheetMeta>[];
    }
  }

  static Future<void> _saveAll(List<SheetMeta> all) async {
    final sp = await SharedPreferences.getInstance();
    final payload = all.map((e) => jsonEncode(e.toJson())).toList();
    await sp.setStringList(_key, payload);
  }

  static Future<SheetMeta> create(
      {String? name, double? lat, double? lon}) async {
    final now = DateTime.now();
    final suggested = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()
        : _suggestDefaultName(now);
    final m = SheetMeta(
      id: now.microsecondsSinceEpoch.toString(),
      name: suggested,
      createdAt: now,
      updatedAt: now,
      latitude: lat,
      longitude: lon,
    );

    // OperaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n atÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³mica: leer -> modificar -> escribir.
    final all = await list()
      ..add(m);
    await _saveAll(all);
    return m;
  }

  /// OperaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n ATÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œMICA: leer -> modificar -> escribir (evita perder cambios).
  static Future<void> rename(String id, String newName) async {
    final all = await list(); // 1) leer snapshot
    final i = all.indexWhere((e) => e.id == id);
    if (i != -1) {
      all[i].name = newName.trim();
      all[i].updatedAt = DateTime.now();
      await _saveAll(all); // 2) escribir
    }
  }

  /// OperaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n ATÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œMICA: leer -> modificar -> escribir.
  static Future<void> delete(String id) async {
    final all = await list();
    all.removeWhere((e) => e.id == id);
    await _saveAll(all);
  }

  static String _suggestDefaultName(DateTime now) {
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'Planilla $y$m$d-$hh$mm';
  }
}

class SpreadsheetMenu extends StatefulWidget {
  const SpreadsheetMenu({super.key, required this.onOpen});
  final void Function(SheetMeta meta) onOpen;

  @override
  State<SpreadsheetMenu> createState() => _SpreadsheetMenuState();
}

class _SpreadsheetMenuState extends State<SpreadsheetMenu> {
  List<SheetMeta> _items = [];

  // Formateadores creados una sola vez (mejor rendimiento)
  late final DateFormat _dateFmt;
  late final DateFormat _dateTimeFmt;

  @override
  void initState() {
    super.initState();
    _dateFmt = DateFormat('dd/MM/yyyy');
    _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');
    _load();
  }

  Future<void> _load() async {
    _items = await SheetsStore.list();
    if (mounted) setState(() {});
  }

  // UI optimista: actualizamos estado local sin recargar del disco.
  Future<void> _create() async {
    final meta = await SheetsStore.create();
    if (!mounted) return;
    setState(() => _items.insert(0, meta));
    widget.onOpen(meta);
  }

  Future<void> _rename(SheetMeta m) async {
    final controller = TextEditingController(text: m.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar planilla'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );

    final newName = controller.text.trim();
    if (ok == true && newName.isNotEmpty) {
      await SheetsStore.rename(m.id, newName);
      if (!mounted) return;
      setState(() {
        m.name = newName;
        m.updatedAt = DateTime.now();
      });
    }
  }

  Future<void> _delete(SheetMeta m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar planilla'),
        content: Text('ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂSeguro que querÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s borrar "${m.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok == true) {
      await SheetsStore.delete(m.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.id == m.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planillas')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No hay planillas aÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºn'))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = _items[i];
                return ListTile(
                  title: Text(m.name),
                  subtitle: Text(
                    'Creada: ${_dateFmt.format(m.createdAt)} ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· ÃƒÆ’Ã†â€™Ãƒâ€¦Ã‚Â¡ltima: ${_dateTimeFmt.format(m.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _rename(m)),
                      IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _delete(m)),
                    ],
                  ),
                  onTap: () => widget.onOpen(m),
                );
              },
            ),
    );
  }
}
