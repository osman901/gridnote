import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firebase_test_service.dart'; // <--- IMPORTANTE

class CloudFilesScreen extends StatefulWidget {
  const CloudFilesScreen({super.key});

  @override
  State<CloudFilesScreen> createState() => _CloudFilesScreenState();
}

class _CloudFilesScreenState extends State<CloudFilesScreen> {
  String _search = '';
  String _filtroFecha = 'Todos';

  // Helper para filtrar por fecha
  bool _matchFiltroFecha(String fechaIso) {
    if (_filtroFecha == 'Todos') return true;
    final fecha = DateTime.tryParse(fechaIso) ?? DateTime.now();
    final hoy = DateTime.now();
    if (_filtroFecha == 'Hoy') {
      return fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
    }
    if (_filtroFecha == 'Semana') {
      final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
      return fecha.isAfter(inicioSemana.subtract(const Duration(days: 1)));
    }
    if (_filtroFecha == 'Mes') {
      return fecha.year == hoy.year && fecha.month == hoy.month;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planillas en la Nube'),
        backgroundColor: Colors.cyan[900],
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _filtroFecha = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'Todos', child: Text('Todos')),
              const PopupMenuItem(value: 'Hoy', child: Text('Hoy')),
              const PopupMenuItem(value: 'Semana', child: Text('Esta semana')),
              const PopupMenuItem(value: 'Mes', child: Text('Este mes')),
            ],
            icon: const Icon(Icons.filter_alt),
            tooltip: "Filtrar por fecha",
          ),
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: 'Test conexión Firebase',
            onPressed: () async {
              final ok = await FirebaseTestService.testConnection();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Conexión a Firebase OK 🔥'
                      : 'Error de conexión Firebase'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('planillas')
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs.where((doc) {
                  final planilla = doc.data() as Map<String, dynamic>;
                  final nombre = planilla['nombre']?.toString().toLowerCase() ?? '';
                  final fecha = planilla['fecha'] ?? '';
                  final matchesSearch = _search.isEmpty || nombre.contains(_search.toLowerCase());
                  final matchesFecha = _matchFiltroFecha(fecha);
                  return matchesSearch && matchesFecha;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No hay planillas que coincidan.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final planilla = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    final nombre = planilla['nombre'] ?? 'Sin nombre';
                    final fecha = planilla['fecha'] ?? '';
                    final fechaFormat = fecha.isNotEmpty
                        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(fecha) ?? DateTime.now())
                        : '-';
                    final lat = planilla['latitud'];
                    final lon = planilla['longitud'];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.cloud_done, color: Colors.cyan),
                        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha: $fechaFormat'),
                            if (lat != null && lon != null)
                              GestureDetector(
                                onTap: () async {
                                  final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: Text(
                                  'Ubicación: $lat, $lon',
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline),
                                ),
                              ),
                            Text('Mediciones: ${planilla['mediciones']?.length ?? 0}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'ver') {
                              _mostrarDetalles(context, planilla);
                            } else if (value == 'borrar') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('¿Eliminar planilla?'),
                                  content: const Text('Esta acción no se puede deshacer.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await FirebaseFirestore.instance.collection('planillas').doc(id).delete();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Planilla eliminada')));
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'ver', child: Text('Ver detalles')),
                            const PopupMenuItem(value: 'borrar', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                        onTap: () => _mostrarDetalles(context, planilla),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- DIALOGO DETALLES EN TABLA -----------------
  void _mostrarDetalles(BuildContext context, Map<String, dynamic> planilla) {
    final mediciones = planilla['mediciones'] as List<dynamic>? ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(planilla['nombre'] ?? 'Sin nombre'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Fecha: ${planilla['fecha'] ?? ''}'),
              Text('Ubicación: ${planilla['latitud']} / ${planilla['longitud']}'),
              const SizedBox(height: 8),
              const Text('Mediciones:', style: TextStyle(fontWeight: FontWeight.bold)),
              MeasurementTableDialog(mediciones: mediciones),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

// ---------- TABLA DETALLE MEDICIONES ----------
class MeasurementTableDialog extends StatelessWidget {
  final List<dynamic> mediciones;

  const MeasurementTableDialog({super.key, required this.mediciones});

  @override
  Widget build(BuildContext context) {
    if (mediciones.isEmpty) {
      return const Text('Sin mediciones.');
    }
    final headers = mediciones.first.keys.where((k) => k != 'id').toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: headers
            .map((h) => DataColumn(label: Text(h.toString().toUpperCase())))
            .toList(),
        rows: mediciones
            .map(
              (m) => DataRow(
            cells: headers
                .map((h) => DataCell(Text('${m[h] ?? ''}')))
                .toList(),
          ),
        )
            .toList(),
      ),
    );
  }
}