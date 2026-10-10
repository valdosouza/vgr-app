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

/// Decision 235: a day the operator types in a panel filter (`yyyy-MM-dd`)
/// is THEIR local day — the dates on screen are local (232) — while the
/// API filters `created_at` by instant. The start of that day, 00:00 local,
/// as an ISO instant in UTC; null when [day] is not `yyyy-MM-dd`.
String? localDayStartUtc(String day) => _localDay(day)?.toUtc().toIso8601String();

/// The last millisecond of the local [day] (23:59:59.999 local) as an ISO
/// instant in UTC — the API treats a date-time `to` as inclusive. Built
/// from the NEXT local midnight, so a day with a DST jump still ends right.
String? localDayEndUtc(String day) {
  final start = _localDay(day);
  if (start == null) return null;
  final nextMidnight = DateTime(start.year, start.month, start.day + 1);
  return nextMidnight.subtract(const Duration(milliseconds: 1)).toUtc().toIso8601String();
}

final _dayOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

DateTime? _localDay(String day) {
  final m = _dayOnly.firstMatch(day.trim());
  if (m == null) return null;
  final year = int.parse(m.group(1)!), month = int.parse(m.group(2)!), dayOfMonth = int.parse(m.group(3)!);
  final local = DateTime(year, month, dayOfMonth);
  // DateTime rolls Feb 30 over to Mar 2 — not a day anyone typed.
  return local.month == month && local.day == dayOfMonth ? local : null;
}
