// lib/tabs/cathodic_protection_tab.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../services/excel_template_service.dart';
import '../widgets/excel_datasource.dart';

/// Si [embedded] es true (por defecto), NO crea Scaffold ni FAB (ideal para TabBarView).
/// Si [embedded] es false, se muestra como pantalla completa con FAB de exportación.
class CathodicProtectionTab extends StatefulWidget {
  const CathodicProtectionTab({super.key, this.embedded = true});
  final bool embedded;

  @override
  State<CathodicProtectionTab> createState() => _CathodicProtectionTabState();
}

class _CathodicProtectionTabState extends State<CathodicProtectionTab> {
  final _svc = ExcelTemplateService();
  late ExcelDataSource _ds;
  List<GridColumn> _columns = const [];
  final _sheetName = 'Hoja1';

  bool _ready = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _ready = false;
      _error = null;
    });
    try {
      await _svc.load(sheetNames: [_sheetName]);

      // Matriz y conteo de columnas robusto (máximo entre todas las filas)
      final m = _svc.matrix(_sheetName);
      final colsCount = m.isNotEmpty
          ? m.fold<int>(0, (maxCols, row) => max(maxCols, row.length))
          : 4; // inicio amigable cuando no hay datos

      _columns = ExcelDataSource.defaultColumns(colsCount);

      _ds = ExcelDataSource(
        svc: _svc,
        sheetName: _sheetName,
        columns: _columns,
        allowEditing: true,
      );

      setState(() => _ready = true);
    } catch (e, st) {
      // Evita spinner infinito y muestra causa
      // ignore: avoid_print
      print('Error en _init(): $e\n$st');
      setState(() {
        _error = 'Error al cargar la plantilla: $e';
        _ready = true;
      });
    }
  }

  Future<void> _export() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final path = await _svc.saveToFile(
        fileName: 'gridnote.xlsx',
        openAfterSave: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exportado: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildGrid() {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return SfDataGrid(
      source: _ds,
      allowEditing: true,
      editingGestureType: EditingGestureType.doubleTap,
      columnWidthMode: ColumnWidthMode.fill,
      headerGridLinesVisibility: GridLinesVisibility.both,
      gridLinesVisibility: GridLinesVisibility.both,
      columns: _columns,
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = _buildGrid();

    if (widget.embedded) {
      // Uso como pestaña (sin Scaffold/FAB)
      return grid;
    }

    // Uso como pantalla completa
    return Scaffold(
      body: grid,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _export,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_alt),
        label: Text(_isSaving ? 'Exportando…' : 'Exportar'),
      ),
    );
  }
}
