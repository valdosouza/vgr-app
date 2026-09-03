import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_validators/vgr_validators.dart';

/// Mirror of `api/src/shared/chat/__tests__/contact-filter.spec.ts`
/// (decisions 171/154): the SAME fixtures, case by case — every refused
/// sample and every "passes" sample. The server is the authority; this
/// package gives the sender the excerpt to rewrite before the round-trip.
/// If either side changes, the other changes in the same commit.
void main() {
  group('findContact — phone numbers (>= 8 digits, mask-tolerant)', () {
    const flagged = {
      'plain 8 digits': 'me liga 91234567',
      '9 digits with dash': 'chama 91234-5678',
      'area code in parentheses': 'tel (11) 91234-5678',
      'international prefix': 'liga +55 11 91234 5678',
      'dots as separators': 'meu numero 11.9.1234.5678',
      'spaces only': '11 9 1234 5678 me chama',
    };
    for (final entry in flagged.entries) {
      test('flags ${entry.key}', () {
        expect(findContact(entry.value)?.kind, ContactKind.phone, reason: entry.value);
      });
    }

    test('carries the offending excerpt so the client can point at it', () {
      expect(findContact('me liga no (11) 91234-5678 depois')?.match, '(11) 91234-5678');
    });

    test('exactly 8 digits is the boundary: 8 fails, 7 passes', () {
      expect(findContact('protocolo 12345678')?.kind, ContactKind.phone);
      expect(findContact('protocolo 1234567'), isNull);
    });

    test('a masked number under 8 digits passes (case id 1234-567)', () {
      expect(findContact('caso 1234-567 aberto'), isNull);
    });
  });

  group('findContact — false-positive guards, ordinary numbers pass', () {
    const passes = {
      'house number': 'Rua A, 123',
      'bare address with complement': 'Av. Paulista, 1578, apto 42',
      'time with h': 'te encontro às 15h30',
      'time with colon': 'chego 15:30',
      'money': r'custa R$ 1.500,00',
      'date': 'vi no dia 03/09/2026 de manhã',
      'case id under 8 digits': 'boletim 2026-123',
      'distance and age': 'uns 300 metros, criança de 7 anos',
      'plain sentence': 'estou perto da praça, posso ir agora',
      '"face" as an ordinary word (removed from the messenger list, 2026-09-03)':
          'em face de 3 pessoas',
      'empty': '',
    };
    for (final entry in passes.entries) {
      test('${entry.key} passes', () {
        expect(findContact(entry.value), isNull, reason: entry.value);
      });
    }
  });

  group('findContact — e-mails', () {
    test('flags an e-mail address', () {
      expect(
        findContact('manda pra ana.silva@example.com'),
        const ContactHit(kind: ContactKind.email, match: 'ana.silva@example.com'),
      );
    });

    test('is case-insensitive', () {
      expect(findContact('ANA@EXAMPLE.COM')?.kind, ContactKind.email);
    });
  });

  group('findContact — URLs', () {
    const flagged = {
      'http': 'veja http://exemplo.com/x',
      'https': 'https://exemplo.com.br',
      'www': 'entra em www.exemplo.com',
      'bare domain.tld': 'meu site exemplo.com',
      'bare domain with 2-letter tld': 'acessa exemplo.io agora',
    };
    for (final entry in flagged.entries) {
      test('flags ${entry.key}', () {
        expect(findContact(entry.value)?.kind, ContactKind.url, reason: entry.value);
      });
    }

    test('a sentence ending with a period followed by a space is not a domain', () {
      expect(findContact('fui até lá. Nada'), isNull);
    });
  });

  group('findContact — @handles', () {
    test('flags @handle with >= 3 chars', () {
      expect(
        findContact('me acha no @ana_silva'),
        const ContactHit(kind: ContactKind.handle, match: '@ana_silva'),
      );
    });

    test('a handle shorter than 3 chars passes', () {
      expect(findContact('vou @ai'), isNull);
    });

    test('an e-mail is reported as e-mail, not as a handle', () {
      expect(findContact('x@exemplo.com')?.kind, ContactKind.email);
    });
  });

  group('findContact — messenger names followed by a number or handle', () {
    const flagged = {
      'whats + number': 'me chama no whats 4567',
      'whatsapp + number': 'WhatsApp: 4567',
      'zap + number': 'zap 4567',
      'telegram + handle': 'telegram @ana',
      'insta + handle': 'insta @ana',
      'instagram + number': 'instagram 4567',
      'signal + number': 'signal 4567',
      'discord + handle': 'discord @ana',
      'tiktok + handle': 'tiktok @ana',
      'facebook + handle': 'facebook @ana',
      'number within 40 chars': 'me procura no telegram que o final e 4567',
    };
    for (final entry in flagged.entries) {
      test('flags ${entry.key}', () {
        expect(findContact(entry.value)?.kind, ContactKind.messenger, reason: entry.value);
      });
    }

    test('a messenger name alone (no number, no handle nearby) passes', () {
      expect(findContact('nao uso whatsapp, so falo por aqui'), isNull);
    });

    test('a number more than 40 chars after the name passes', () {
      final filler = 'a' * 41;
      expect(findContact('telegram $filler 4567'), isNull);
    });
  });

  group('findContact — accents and case', () {
    test('strips accents before matching (whátsapp 4567 still hits)', () {
      expect(findContact('me chama no whátsapp 4567')?.kind, ContactKind.messenger);
    });

    test('matches uppercase messenger names', () {
      expect(findContact('ZAP 4567')?.kind, ContactKind.messenger);
    });
  });

  group('VgrValidators.noDirectContact — mirrors chat.service text rules (decision 171)', () {
    test('a clean message passes, and so does blank (required is a separate rule)', () {
      expect(VgrValidators.noDirectContact('estou perto da praça, posso ir agora'), isNull);
      expect(VgrValidators.noDirectContact(''), isNull);
    });

    test('a contact → CONTACT_NOT_ALLOWED with kind and match, the API\'s own params', () {
      expect(
        VgrValidators.noDirectContact('me liga no (11) 91234-5678 depois'),
        const VgrFieldError(
          VgrFieldCode.contactNotAllowed,
          {'kind': 'phone', 'match': '(11) 91234-5678'},
        ),
      );
      expect(VgrFieldCode.contactNotAllowed, 'CONTACT_NOT_ALLOWED');
    });

    test('kind is the wire name of the API (email/url/phone/messenger/handle)', () {
      expect(VgrValidators.noDirectContact('x@exemplo.com')?.params['kind'], 'email');
      expect(VgrValidators.noDirectContact('www.exemplo.com')?.params['kind'], 'url');
      expect(VgrValidators.noDirectContact('telegram @ana')?.params['kind'], 'messenger');
      expect(VgrValidators.noDirectContact('@ana_silva')?.params['kind'], 'handle');
    });
  });
}
