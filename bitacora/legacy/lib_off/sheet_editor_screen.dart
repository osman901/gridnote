import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/sheets_repo.dart';
import '../data/local_db.dart';
import '../providers.dart';
import '../widgets/entry_card.dart';

class SheetEditorScreen extends ConsumerWidget {
  const SheetEditorScreen({
    super.key,
    required this.sheetId,
    this.sheetName,
  });

  final int sheetId;
  final String? sheetName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Debe existir en providers.dart como Provider<SheetsRepo>
    final SheetsRepo repo = ref.read(sheetsRepoProvider);

    Future<void> addEntry() async {
      await repo.newEntry(sheetId);
    }

    return Scaffold(
      appBar: AppBar(title: Text(sheetName ?? 'Planilla')),
      body: FutureBuilder<List<Entry>>(
        future: repo.listEntries(sheetId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? const <Entry>[];
          if (entries.isEmpty) {
            return Center(
              child: ElevatedButton(
                onPressed: addEntry,
                child: const Text('Crear primera entrada'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            // EntryCard requiere: entry: Entry  y  repo: SheetsRepo
            itemBuilder: (_, i) => EntryCard(entry: entries[i], repo: repo),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Nueva entrada'),
      ),
    );
  }
}
