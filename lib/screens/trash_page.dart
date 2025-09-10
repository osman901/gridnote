import 'package:flutter/material.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Papelera')),
      body: const Center(
        child: Text('Acá va tu UI de recuperar datos borrados.'),
      ),
    );
  }
}
