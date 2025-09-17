import 'package:flutter/material.dart';

class QuickHub {
  static void show(BuildContext context) {
    late OverlayEntry entry;
    var expanded = false;

    entry = OverlayEntry(
      builder: (_) => _QuickHubOverlay(
        onClose: () => entry.remove(),
        onToggle: () {
          expanded = !expanded;
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }
}

class _QuickHubOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onToggle;
  const _QuickHubOverlay({required this.onClose, required this.onToggle});

  @override
  State<_QuickHubOverlay> createState() => _QuickHubOverlayState();
}

class _QuickHubOverlayState extends State<_QuickHubOverlay> {
  bool _expanded = false;
  final _dur = const Duration(milliseconds: 220);
  final _curve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    // pequeÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â±a demora para animar apariciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _expanded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top + 12;

    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          // fondo para tap-cerrar
          Positioned.fill(
            child: GestureDetector(onTap: () {
              setState(() => _expanded = false);
              Future.delayed(_dur, widget.onClose);
            }),
          ),
          // pill superior
          AnimatedPositioned(
            duration: _dur, curve: _curve,
            top: top,
            left: media.size.width * 0.15,
            right: media.size.width * 0.15,
            child: AnimatedContainer(
              duration: _dur, curve: _curve,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: kElevationToShadow[6],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.bolt_rounded),
                  const Text("Atajos rÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡pidos", style: TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            ),
          ),

          // grid expandible
          AnimatedPositioned(
            duration: _dur, curve: _curve,
            top: _expanded ? top + 66 : -300,
            left: 16, right: 16,
            child: AnimatedOpacity(
              duration: _dur, opacity: _expanded ? 1 : 0,
              child: _QuickGrid(onClose: () {
                setState(() => _expanded = false);
                Future.delayed(_dur, widget.onClose);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  final VoidCallback onClose;
  const _QuickGrid({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final items = <_QuickItem>[
      _QuickItem("Nueva mediciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n", Icons.add_circle, () => Navigator.pushNamed(context, "/new")),
      _QuickItem("Importar Excel", Icons.upload_file, () => Navigator.pushNamed(context, "/import")),
      _QuickItem("Fotos", Icons.photo_library_rounded, () => Navigator.pushNamed(context, "/photos")),
      _QuickItem("UbicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n", Icons.place_rounded, () => Navigator.pushNamed(context, "/location")),
      _QuickItem("Reportes", Icons.assessment_rounded, () => Navigator.pushNamed(context, "/reports")),
      _QuickItem("Ajustes", Icons.settings_rounded, () => Navigator.pushNamed(context, "/settings")),
    ];

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GridView.count(
          crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          children: items.map((i) => _Tile(i: i, onTapDone: onClose)).toList(),
        ),
      ),
    );
  }
}

class _QuickItem {
  final String label;
  final IconData icon;
  final VoidCallback action;
  _QuickItem(this.label, this.icon, this.action);
}

class _Tile extends StatelessWidget {
  final _QuickItem i;
  final VoidCallback onTapDone;
  const _Tile({required this.i, required this.onTapDone});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () { i.action(); onTapDone(); },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(i.icon, size: 28),
          const SizedBox(height: 8),
          Text(i.label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
