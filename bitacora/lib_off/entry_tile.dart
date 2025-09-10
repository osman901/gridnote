// lib/widgets/entry_tile.dart
import 'dart:io';
import 'package:flutter/material.dart';

import '../data/local_db.dart';        // Entry
import '../repositories/sheets_repo.dart';
import '../services/location_service.dart';
import '../services/media_service.dart';

class _Loc {
  const _Loc(this.lat, this.lng, this.acc, this.provider);
  final double lat;
  final double lng;
  final double? acc;
  final String? provider;
}

class EntryTile extends StatefulWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.repo,
  });

  final Entry entry;
  final SheetsRepo repo;

  @override
  State<EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<EntryTile> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  final _suggestions = const [
    'Inspección',
    'Muestreo',
    'Observación',
    'Reparación',
    'Chequeo',
  ];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.entry.title ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _saveTitle(String v) async {
    await widget.repo.updateEntry(widget.entry.id, title: v.trim());
  }

  Future<void> _addPhoto() async {
    final taken = await MediaService.instance.takePhoto();
    if (taken == null) return;

    await widget.repo.addAttachment(
      entryId: widget.entry.id,
      path: taken.path,
      thumbPath: taken.thumbPath,
      sizeBytes: taken.size,
      hash: taken.hash,
    );
    if (mounted) setState(() {});
  }

  Future<_Loc?> _getLocationFromService() async {
    final svc = LocationService.instance as dynamic;
    try {
      final r = await svc.get();
      final lat = (r.lat as num).toDouble();
      final lng = (r.lng as num).toDouble();
      final acc = (r.acc as num?)?.toDouble();
      final provider = r.provider as String?;
      return _Loc(lat, lng, acc, provider);
    } catch (_) {
      try {
        final r = await svc.current();
        final lat = (r.lat as num).toDouble();
        final lng = (r.lng as num).toDouble();
        final acc = (r.acc as num?)?.toDouble();
        final provider = r.provider as String?;
        return _Loc(lat, lng, acc, provider);
      } catch (_) {
        try {
          final r = await svc.getLocation();
          final lat = (r.lat as num).toDouble();
          final lng = (r.lng as num).toDouble();
          final acc = (r.acc as num?)?.toDouble();
          final provider = r.provider as String?;
          return _Loc(lat, lng, acc, provider);
        } catch (_) {
          return null;
        }
      }
    }
  }

  Future<void> _addLocation() async {
    final messenger = ScaffoldMessenger.of(context);

    final loc = await _getLocationFromService();
    if (loc == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación.')),
      );
      return;
    }

    await widget.repo.updateEntry(
      widget.entry.id,
      lat: loc.lat,
      lng: loc.lng,
      accuracy: loc.acc,
      provider: loc.provider,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue t) {
                      if (t.text.isEmpty) return const Iterable.empty();
                      return _suggestions.where(
                            (s) => s.toLowerCase().contains(t.text.toLowerCase()),
                      );
                    },
                    initialValue: TextEditingValue(text: _controller.text),
                    onSelected: (s) {
                      _controller.text = s;
                      _saveTitle(s);
                    },
                    fieldViewBuilder: (ctx, controller, focus, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: _focus,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Título (editable)...',
                        ),
                        style: theme.textTheme.titleMedium,
                        onSubmitted: (v) => _saveTitle(v),
                      );
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Adjuntar foto',
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: _addPhoto,
                ),
                IconButton(
                  tooltip: 'Agregar ubicación',
                  icon: const Icon(Icons.my_location_outlined),
                  onPressed: _addLocation,
                ),
              ],
            ),

            if (widget.entry.lat != null && widget.entry.lng != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '(${widget.entry.lat!.toStringAsFixed(5)}, ${widget.entry.lng!.toStringAsFixed(5)})'
                      ' • ±${(widget.entry.accuracy ?? 0).toStringAsFixed(0)}m',
                  style: theme.textTheme.bodySmall,
                ),
              ),

            FutureBuilder(
              future: widget.repo.listAttachments(widget.entry.id),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty) {
                  return const SizedBox(height: 8);
                }
                final atts = snap.data!;
                return SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: atts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final a = atts[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(a.thumbPath),
                          height: 82,
                          width: 82,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
