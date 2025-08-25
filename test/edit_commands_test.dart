// test/edit_commands_test.dart
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/measurement.dart';
import '../lib/state/edit_commands.dart';
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
  test('AddRowCommand execute/unexecute + save/unsave', () async {
    final repo = FakeDelayRepo(seed: [m(id: 1, p: 'X')], delay: Duration.zero);
    final cmd = AddRowCommand(m(p: 'N'), 1);

    var cur = [m(id: 1, p: 'X')];
    cur = cmd.execute(cur);
    expect(cur.length, 2);
    expect(cur[1].progresiva, 'N');

    cur = await cmd.save(repo, cur);
    expect(cur[1].id != null, true);

    cur = await cmd.unsave(repo, cur);
    expect(cur.length, 1);
  });

  test('UpdateRowCommand execute/unexecute + save/unsave', () async {
    final repo = FakeDelayRepo(seed: [m(id: 1, p: 'X')], delay: Duration.zero);
    final cmd = UpdateRowCommand(m(id: 1, p: 'X'), m(id: 1, p: 'Y'), 0);

    var cur = [m(id: 1, p: 'X')];
    cur = cmd.execute(cur);
    expect(cur.first.progresiva, 'Y');

    cur = await cmd.save(repo, cur);
    expect(cur.first.progresiva, 'Y');

    cur = cmd.unexecute(cur);
    expect(cur.first.progresiva, 'X');

    cur = await cmd.unsave(repo, cur);
    expect(cur.first.progresiva, 'X');
  });

  test('DeleteRowCommand execute/unexecute + save/unsave', () async {
    final repo = FakeDelayRepo(seed: [m(id: 1, p: 'X')], delay: Duration.zero);
    final cmd = DeleteRowCommand(m(id: 1, p: 'X'), 0);

    var cur = [m(id: 1, p: 'X')];
    cur = cmd.execute(cur);
    expect(cur.isEmpty, true);

    cur = await cmd.save(repo, cur);
    expect(cur.isEmpty, true);

    cur = cmd.unexecute(cur);
    expect(cur.length, 1);

    cur = await cmd.unsave(repo, cur);
    expect(cur.length, 1);
  });
}
