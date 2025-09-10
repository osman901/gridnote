// lib/widgets/measurement_tile.dart
import 'package:flutter/material.dart';
import '../models/measurement.dart';
import '../theme/gridnote_theme.dart';

class MeasurementTile extends StatelessWidget {
  final Measurement measurement;
  final GridnoteTheme theme;
  final VoidCallback? onTap;

  const MeasurementTile({
    super.key,
    required this.measurement,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Ícono o avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics,
                  color: theme.accent,
                ),
              ),
              const SizedBox(width: 12),
              // Contenido principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      measurement.progresiva.isNotEmpty
                          ? measurement.progresiva
                          : 'Sin código',
                      style: TextStyle(
                        color: theme.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '1mΩ: ${measurement.ohm1m}',
                          style: TextStyle(color: theme.textFaint, fontSize: 12),
                        ),
                        ...[
                        const SizedBox(width: 8),
                        Text(
                          '3mΩ: ${measurement.ohm3m}',
                          style: TextStyle(color: theme.textFaint, fontSize: 12),
                        ),
                      ],
                      ],
                    ),
                  ],
                ),
              ),
              // Icono de navegación
              Icon(
                Icons.chevron_right,
                color: theme.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
