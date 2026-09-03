/// Anti-contact filter of the masked chat — the app-side MIRROR of
/// `api/src/shared/chat/contact-filter.ts` (decisions 171/154). Rule by
/// rule the same, proved by the same fixtures in `test/contact_filter_test`.
/// The server is the authority and always re-checks; this exists so the
/// sender sees the offending excerpt before the round-trip (and before an
/// offline-queued message is refused hours later).
///
/// What is detected (contract of decision 171):
///  - phone numbers: >= 8 digits, tolerant to spaces / dots / dashes /
///    parentheses / a leading '+'. Under 8 digits is an ordinary number;
///  - e-mail addresses;
///  - URLs: http(s)://, www., or a bare domain.tld (>= 2-letter TLD);
///  - @handles of >= 3 characters;
///  - a messenger name (whatsapp, whats, instagram, insta, facebook,
///    telegram, signal, discord, tiktok, zap) followed within 40
///    characters by a number or a handle.
/// Matching is case-insensitive with accents stripped first.
library;

/// Wire names of the API's `ContactKind` — `name` is what goes into the
/// `kind` param of `CONTACT_NOT_ALLOWED`.
enum ContactKind { phone, email, url, handle, messenger }

class ContactHit {
  const ContactHit({required this.kind, required this.match});

  final ContactKind kind;

  /// The offending excerpt, as written by the sender.
  final String match;

  @override
  bool operator ==(Object other) =>
      other is ContactHit && other.kind == kind && other.match == match;

  @override
  int get hashCode => Object.hash(kind, match);

  @override
  String toString() => 'ContactHit(${kind.name}, $match)';
}

const _phoneMinDigits = 8;
const _messengerWindow = 40;

final _email = RegExp(r'[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}');
final _url = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+|\b[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}\b)');

/// A run of digits and phone separators, starting and ending on a digit.
final _phoneCandidate = RegExp(r'\+?\(?\d[\d\s().+-]*\d');
final _messenger = RegExp(
  r'\b(whatsapp|whats|instagram|insta|facebook|telegram|signal|discord|tiktok|zap)\b'
  '[\\s\\S]{0,$_messengerWindow}?(\\d|@[a-z0-9_])',
);

/// '@' not glued to an e-mail's local part, then >= 3 handle characters.
final _handle = RegExp(r'(?<![a-z0-9._%+-])@[a-z0-9_.]{3,}');
final _digit = RegExp(r'\d');

/// Lowercase + accents stripped. Dart has no NFD normalizer, so the Latin
/// letters with diacritics (U+00C0–U+017F, what Portuguese and its
/// neighbours use) map to their base letter one-to-one; the result keeps
/// the original length, so indexes map back onto the sender's text for
/// the excerpt — the same property the API relies on.
String _normalize(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    buffer.write(_stripAccent(rune));
  }
  return buffer.toString().toLowerCase();
}

String _stripAccent(int rune) {
  if (rune < 0x00C0 || rune > 0x017F) return String.fromCharCode(rune);
  for (final entry in _accentTable.entries) {
    if (entry.value.contains(String.fromCharCode(rune))) return entry.key;
  }
  return String.fromCharCode(rune);
}

const _accentTable = <String, String>{
  'A': 'ÀÁÂÃÄÅĀĂĄ',
  'a': 'àáâãäåāăą',
  'C': 'ÇĆĈĊČ',
  'c': 'çćĉċč',
  'D': 'ĎĐ',
  'd': 'ďđ',
  'E': 'ÈÉÊËĒĔĖĘĚ',
  'e': 'èéêëēĕėęě',
  'G': 'ĜĞĠĢ',
  'g': 'ĝğġģ',
  'H': 'ĤĦ',
  'h': 'ĥħ',
  'I': 'ÌÍÎÏĨĪĬĮİ',
  'i': 'ìíîïĩīĭįı',
  'J': 'Ĵ',
  'j': 'ĵ',
  'K': 'Ķ',
  'k': 'ķ',
  'L': 'ĹĻĽĿŁ',
  'l': 'ĺļľŀł',
  'N': 'ÑŃŅŇ',
  'n': 'ñńņň',
  'O': 'ÒÓÔÕÖØŌŎŐ',
  'o': 'òóôõöøōŏő',
  'R': 'ŔŖŘ',
  'r': 'ŕŗř',
  'S': 'ŚŜŞŠ',
  's': 'śŝşš',
  'T': 'ŢŤŦ',
  't': 'ţťŧ',
  'U': 'ÙÚÛÜŨŪŬŮŰŲ',
  'u': 'ùúûüũūŭůűų',
  'W': 'Ŵ',
  'w': 'ŵ',
  'Y': 'ÝŶŸ',
  'y': 'ýÿŷ',
  'Z': 'ŹŻŽ',
  'z': 'źżž',
};

int _digitCount(String value) => _digit.allMatches(value).length;

String _excerpt(String original, int start, int end) => original.substring(start, end);

RegExpMatch? _findPhone(String normalized) {
  for (final candidate in _phoneCandidate.allMatches(normalized)) {
    if (_digitCount(candidate[0]!) >= _phoneMinDigits) return candidate;
  }
  return null;
}

/// Returns the first contact found in the text, or null when it is clean.
/// Detection order — e-mail → URL → phone → messenger → handle — is the
/// API's, so both sides name the same `kind` for the same text.
ContactHit? findContact(String text) {
  final normalized = _normalize(text);

  final email = _email.firstMatch(normalized);
  if (email != null) {
    return ContactHit(kind: ContactKind.email, match: _excerpt(text, email.start, email.end));
  }

  final url = _url.firstMatch(normalized);
  if (url != null) {
    return ContactHit(kind: ContactKind.url, match: _excerpt(text, url.start, url.end));
  }

  final phone = _findPhone(normalized);
  if (phone != null) {
    return ContactHit(kind: ContactKind.phone, match: _excerpt(text, phone.start, phone.end));
  }

  // Messenger BEFORE handle: "telegram @ana" is reported as the messenger
  // invitation it is, not as a bare handle.
  final messenger = _messenger.firstMatch(normalized);
  if (messenger != null) {
    return ContactHit(
      kind: ContactKind.messenger,
      match: _excerpt(text, messenger.start, messenger.end),
    );
  }

  final handle = _handle.firstMatch(normalized);
  if (handle != null) {
    return ContactHit(kind: ContactKind.handle, match: _excerpt(text, handle.start, handle.end));
  }

  return null;
}
