import 'package:flutter/material.dart';

void showTopBanner(BuildContext context, String message,
    {IconData icon = Icons.check_circle, Color? iconColor}) {
  final m = ScaffoldMessenger.of(context);
  m.clearMaterialBanners();
  m.showMaterialBanner(
    MaterialBanner(
      content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
      leading: Icon(icon, color: iconColor ?? Colors.green),
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        TextButton(
          onPressed: () => m.hideCurrentMaterialBanner(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
