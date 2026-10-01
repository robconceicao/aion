import 'dart:convert';
import 'dart:math';

/// Journal persisted before the network call. One unresolved command per owner.
class DreamCommandJournal {
  final dynamic Function(String) read;
  final Future<void> Function(String, dynamic) write;
  DreamCommandJournal(this.read, this.write);

  static String key(String owner) => 'dream_command:$owner';
  static dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  Future<Map<String, dynamic>> prepare(String owner, Map<String, dynamic> payload) async {
    if (owner.isEmpty) throw StateError('Entre novamente para enviar o sonho.');
    final encoded = jsonEncode(_canonical(payload));
    final old = read(key(owner));
    if (old != null) {
      if (old['payload'] != encoded) {
        throw StateError('Há uma análise pendente. Recupere as respostas originais antes de enviar outro sonho.');
      }
      return Map<String, dynamic>.from(old as Map);
    }
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    final command = <String, dynamic>{'command_id': id, 'payload': encoded};
    await write(key(owner), command); // Storage failure MUST prevent POST.
    return command;
  }
}
