// lib/screens/sheet_editor_screen.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class SheetEditorScreen extends StatefulWidget {
  const SheetEditorScreen({super.key, this.sheetId, this.sheetName});
  final int? sheetId;
  final String? sheetName;

  @override
  State<SheetEditorScreen> createState() => _SheetEditorScreenState();
}

class _SheetEditorScreenState extends State<SheetEditorScreen> {
  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy:
        Platform.numberOfProcessors >= 8 ? LocationAccuracy.best : LocationAccuracy.medium,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'UbicaciÃƒÆ’Ã‚Â³n: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error obteniendo ubicaciÃƒÆ’Ã‚Â³n: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.sheetName?.isNotEmpty == true ? widget.sheetName! : 'Editor de planilla';
    final idLabel = widget.sheetId != null ? ' ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ ID: ${widget.sheetId}' : '';
    return Scaffold(
      appBar: AppBar(
        title: Text('$title$idLabel', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'GPS',
            icon: const Icon(CupertinoIcons.location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: const SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        child: SizedBox.shrink(), // acÃƒÆ’Ã‚Â¡ va tu grilla/DataGrid
      ),
    );
  }
}
