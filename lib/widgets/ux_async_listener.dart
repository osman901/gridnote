// lib/widgets/ux_async_listener.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/measurement.dart';
import '../state/measurement_async_provider.dart';

class UxAsyncListener extends ConsumerWidget {
  const UxAsyncListener({
    super.key,
    required this.child,
    required this.sheetId,
  });

  final Widget child;
  final String sheetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<Measurement>>>(
      measurementAsyncProvider(sheetId),
          (previous, next) {
        next.whenOrNull(
          error: (err, _) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $err')),
            );
          },
        );
      },
    );
    return child;
  }
}
