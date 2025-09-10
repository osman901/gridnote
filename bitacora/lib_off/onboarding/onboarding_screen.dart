import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Tile(
            icon: Icons.cloud_off_outlined,
            title: 'Trabajo offline',
            subtitle: 'CreÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ y editÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ planillas incluso sin conexiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n.',
          ),
          SizedBox(height: 16),
          _Tile(
            icon: Icons.place_outlined,
            title: 'UbicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n precisa',
            subtitle: 'GuardÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ coordenadas por planilla o por fila.',
          ),
          SizedBox(height: 16),
          _Tile(
            icon: Icons.ios_share_outlined,
            title: 'ExportaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n fÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡cil',
            subtitle: 'GenerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ XLSX y compartilo por correo o apps.',
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.primary.withValues(alpha: .06),
        border: Border.all(color: cs.primary.withValues(alpha: .25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
