import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gridnote/models/measurement.dart';
import 'package:gridnote/state/measurement_async_provider.dart';
import 'fakes/fake_repository.dart';

Measurement m({int? id, String p = 'A', double o1 = 1, double o3 = 3}) => Measurement(
  id: id,
  progresiva: p,
  ohm1m: o1,
  ohm3m: o3,
  observations: '',
  date: DateTime(2024, 1, 1),
);

void main() {
  const sheetId = 'sheet_test';

  test('optimistic add + repo reconcile id', () async {
    final repo = FakeDelayRepo(seed: [], delay: const Duration(milliseconds: 1));

    final container = ProviderContainer(overrides: [
      // measurementRepoProvider es FAMILY → pasar clave
      measurementRepoProvider(sheetId).overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    // Cargar inicial
    await container.read(measurementAsyncProvider(sheetId).future);

    final notifier = container.read(measurementAsyncProvider(sheetId).notifier);

    final future = notifier.add(m(p: 'N'));
    final during = container.read(measurementAsyncProvider(sheetId));
    expect(during.value?.length, 1); // optimista ya añadió

    await future;
    final after = container.read(measurementAsyncProvider(sheetId)).value!;
    expect(after.first.id != null, true); // id reconciliado
  });

  test('undo/redo workflow', () async {
    final repo = FakeDelayRepo(seed: [m(id: 1, p: 'X')], delay: Duration.zero);

    final c = ProviderContainer(overrides: [
      measurementRepoProvider(sheetId).overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);

    await c.read(measurementAsyncProvider(sheetId).future);
    final n = c.read(measurementAsyncProvider(sheetId).notifier);

    await n.updateRow(m(id: 1, p: 'Y'));
    expect(c.read(measurementAsyncProvider(sheetId)).value!.first.progresiva, 'Y');

    await n.undo();
    expect(c.read(measurementAsyncProvider(sheetId)).value!.first.progresiva, 'X');

    await n.redo();
    expect(c.read(measurementAsyncProvider(sheetId)).value!.first.progresiva, 'Y');
  });

  test('search filter provider', () async {
    final repo = FakeDelayRepo(seed: [m(id: 1, p: 'Alpha'), m(id: 2, p: 'Beta')], delay: Duration.zero);

    final c = ProviderContainer(overrides: [
      measurementRepoProvider(sheetId).overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);

    await c.read(measurementAsyncProvider(sheetId).future);
    expect(c.read(measurementFilteredAsyncProvider(sheetId)).value!.length, 2);

    // searchQueryProvider es FAMILY → pasar clave
    c.read(searchQueryProvider(sheetId).notifier).state = 'alp';
    expect(c.read(measurementFilteredAsyncProvider(sheetId)).value!.length, 1);
  });
}