/// Decision 232: the API serves instants in UTC (ISO 8601 ending in `Z`);
/// the panel and the mobile app show them in the device's LOCAL time, as
/// `yyyy-MM-dd HH:mm` — the one formatter every screen uses, instead of a
/// cut of the UTC string (3 h ahead in Brazil).
///
/// Only a value that carries its zone (`Z` or `±hh:mm`) is converted. A
/// date-only or zone-less value has no instant to convert and is shown as
/// served; an unparseable one is shown verbatim. Null reads as [empty].
String formatLocalDateTime(String? iso, {String empty = '—'}) =>
    _format(iso, empty: empty, withTime: true);

/// The date part of [formatLocalDateTime] — `yyyy-MM-dd` in local time
/// (validity windows, where the hour is noise).
String formatLocalDate(String? iso, {String empty = '—'}) => _format(iso, empty: empty, withTime: false);

final _zoned = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

String _format(String? iso, {required String empty, required bool withTime}) {
  if (iso == null || iso.trim().isEmpty) return empty;
  final value = iso.trim();
  final parsed = _zoned.hasMatch(value) ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    // As served: the old cut, never a guess at a zone.
    final cut = withTime ? 16 : 10;
    return value.length >= cut ? value.replaceFirst('T', ' ').substring(0, cut) : value;
  }
  final local = parsed.toLocal();
  final date = '${local.year.toString().padLeft(4, '0')}-${_two(local.month)}-${_two(local.day)}';
  return withTime ? '$date ${_two(local.hour)}:${_two(local.minute)}' : date;
}

String _two(int n) => n.toString().padLeft(2, '0');
