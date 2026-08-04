import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/photo_draft.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_input.dart';

ReportInput _input({String? category = 'assault', String? freeTag}) => ReportInput(
      clientKey: 'key-1',
      category: category,
      freeTag: freeTag,
      subject: 'adult',
      lat: -23.5,
      lng: -46.6,
      anonymous: true,
    );

void main() {
  group('ReportInput taxonomy invariant (decisions 9/140 — amendment MA1)', () {
    test('accepts category without freeTag', () {
      expect(_input().category, 'assault');
    });

    test('accepts freeTag without category', () {
      expect(_input(category: null, freeTag: 'loud dispute').freeTag, 'loud dispute');
    });

    test('rejects construction when both axes of the XOR are set', () {
      expect(() => _input(freeTag: 'x'), throwsArgumentError);
    });

    test('rejects construction when neither category nor freeTag is given', () {
      expect(() => _input(category: null), throwsArgumentError);
    });

    test('rejects a blank freeTag — whitespace is not a taxonomy', () {
      expect(() => _input(category: null, freeTag: '   '), throwsArgumentError);
    });
  });

  group('submit body (POST /app-reports contract)', () {
    test('carries exactly one axis plus the mandatory subject', () {
      final body = _input().toSubmitBody();
      expect(body['category'], 'assault');
      expect(body.containsKey('freeTag'), isFalse);
      expect(body['subject'], 'adult');
      expect(body['clientKey'], 'key-1');
      expect(body['position'], {'lat': -23.5, 'lng': -46.6});
      expect(body['anonymous'], isTrue);
    });

    test('photos never ride the submit body — they go through /app-media', () {
      final input = ReportInput(
        clientKey: 'key-1',
        category: 'assault',
        subject: 'adult',
        lat: 0,
        lng: 0,
        anonymous: true,
        photos: const [PhotoDraft(path: '/tmp/a.jpg')],
      );
      expect(input.toSubmitBody().containsKey('photos'), isFalse);
    });
  });

  group('queue round-trip (decision 137: same draft, same clientKey)', () {
    test('fromJson(toJson) is identity, photos and EXIF choice included', () {
      final input = ReportInput(
        clientKey: 'key-1',
        category: null,
        freeTag: 'street racing',
        subject: 'vehicle',
        detailFields: const {'plate': 'ABC1234'},
        lat: -1.1,
        lng: -2.2,
        anonymous: true,
        photos: const [
          PhotoDraft(path: '/tmp/a.jpg'),
          PhotoDraft(path: '/tmp/b.jpg', keepOriginal: true, exifWarningVersion: 'exif-warning/v1'),
        ],
      );
      expect(ReportInput.fromJson(input.toJson()), input);
    });
  });
}
