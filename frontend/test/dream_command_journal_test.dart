import 'package:flutter_test/flutter_test.dart';
import '../lib/src/core/dream_command_journal.dart';

void main() {
  test('restart and lost response retain the same owner command', () async {
    final disk = <String, dynamic>{};
    final first = DreamCommandJournal((k) => disk[k], (k, v) async { disk[k] = v; });
    final command = await first.prepare('alice', {'text': 'sonho', 'tags': ['a']});
    final restarted = DreamCommandJournal((k) => disk[k], (k, v) async { disk[k] = v; });
    expect(await restarted.prepare('alice', {'tags': ['a'], 'text': 'sonho'}), command);
    final other = await restarted.prepare('bob', {'text': 'sonho', 'tags': ['a']});
    expect(other['command_id'], isNot(command['command_id']));
    expect(command['command_id'], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    await expectLater(restarted.prepare('alice', {'text': 'alterado'}), throwsStateError);
    expect(disk[DreamCommandJournal.key('alice')], command);
  });
  test('storage failure blocks request creation', () async {
    final journal = DreamCommandJournal((_) => null, (_, value) async { throw StateError('disk full'); });
    await expectLater(journal.prepare('alice', {'text': 'sonho'}), throwsStateError);
  });
}
