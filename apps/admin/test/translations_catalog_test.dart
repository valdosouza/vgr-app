import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard for the translation catalogs: a duplicated key at any level is
/// silently resolved by the JSON decoder (last one wins), which is how the
/// `legal` block of the Legal Gate blocked view stayed dead in the panel
/// for weeks — the second `legal` block (Legal Gate screens) shadowed the
/// first (blocked view of packages/core). Found and merged on 2026-09-03.
/// Both locales must also carry the same key set, so a screen never falls
/// back to the raw key in one language only.
void main() {
  const catalogs = ['assets/translations/en-US.json', 'assets/translations/pt-BR.json'];

  Set<String> flatKeys(Map<String, dynamic> map, [String prefix = '']) {
    final keys = <String>{};
    map.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        keys.addAll(flatKeys(v, '$prefix$k.'));
      } else {
        keys.add('$prefix$k');
      }
    });
    return keys;
  }

  /// Walks the raw text and reports any object that declares a key twice.
  List<String> duplicateKeys(String text) {
    final duplicates = <String>[];
    final stack = <Map<String, int>>[<String, int>{}];
    final path = <String>[];
    var i = 0;
    String? pendingKey;
    while (i < text.length) {
      final ch = text[i];
      if (ch == '"') {
        final end = text.indexOf('"', i + 1);
        final token = text.substring(i + 1, end);
        var j = end + 1;
        while (j < text.length && text[j] == ' ') j++;
        if (j < text.length && text[j] == ':') {
          final scope = stack.last;
          scope[token] = (scope[token] ?? 0) + 1;
          if (scope[token]! > 1) duplicates.add([...path, token].join('.'));
          pendingKey = token;
        }
        i = end + 1;
        continue;
      }
      if (ch == '{') {
        stack.add(<String, int>{});
        path.add(pendingKey ?? '');
        pendingKey = null;
      } else if (ch == '}') {
        stack.removeLast();
        path.removeLast();
      }
      i++;
    }
    return duplicates;
  }

  test('no catalog declares the same key twice in one object', () {
    for (final file in catalogs) {
      final text = File(file).readAsStringSync();
      expect(duplicateKeys(text), isEmpty, reason: file);
    }
  });

  test('en-US and pt-BR carry exactly the same keys', () {
    final sets = {
      for (final file in catalogs)
        file: flatKeys(jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>),
    };
    final en = sets[catalogs[0]]!;
    final pt = sets[catalogs[1]]!;
    expect(en.difference(pt), isEmpty, reason: 'only in en-US');
    expect(pt.difference(en), isEmpty, reason: 'only in pt-BR');
  });
}
