import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_view_entity.dart';

Map<String, dynamic> _owner({bool? hidden}) => {
      'access': 'owner',
      'reportId': 5,
      'category': 'assault',
      'subject': 'adult',
      'tier': 'high',
      'status': 'open',
      if (hidden != null) 'hidden': hidden,
    };

void main() {
  group('ReportViewEntity.hidden — the owner\'s mark (B2, decision 167)', () {
    test('defaults to false when the API does not send the field', () {
      expect(ReportViewEntity.fromJson(_owner()).hidden, isFalse);
    });

    test('reads the flag when present, and it takes part in equality', () {
      final hidden = ReportViewEntity.fromJson(_owner(hidden: true));
      expect(hidden.hidden, isTrue);
      expect(hidden, isNot(ReportViewEntity.fromJson(_owner(hidden: false))));
    });
  });

  group('ReportViewEntity.chat — the served chat facet (C2, decision 169)', () {
    test('absent → null (public and summary views, anonymous helper)', () {
      expect(ReportViewEntity.fromJson(_owner()).chat, isNull);
    });

    test('owner: {threads, unread}', () {
      final view = ReportViewEntity.fromJson({..._owner(), 'chat': {'threads': 2, 'unread': 3}});
      expect(view.chat, const ReportChatFacetEntity(threads: 2, unread: 3));
      expect(view.chat!.isOwner, isTrue);
    });

    test('helper participant: {threadId, unread}, threadId null before the first message', () {
      final withThread = ReportViewEntity.fromJson(
          {..._owner(), 'access': 'participant', 'chat': {'threadId': 9, 'unread': 1}});
      expect(withThread.chat, const ReportChatFacetEntity(threadId: 9, unread: 1));
      expect(withThread.chat!.isOwner, isFalse);

      final noThread = ReportViewEntity.fromJson(
          {..._owner(), 'access': 'participant', 'chat': {'threadId': null, 'unread': 0}});
      expect(noThread.chat!.threadId, isNull);
      expect(noThread.chat!.isOwner, isFalse);
    });
  });

  group('OfferViewEntity.rating — the owner-view rating facet (RT2, decisions 180/183/184)', () {
    test('absent → null, handled defensively even though the owner view always sends it', () {
      final offer = OfferViewEntity.fromJson({'helpOfferId': 1, 'helpType': 'physical_presence'});
      expect(offer.rating, isNull);
    });

    test('ratable, not yet rated: {score: null, ratable: true}', () {
      final offer = OfferViewEntity.fromJson({
        'helpOfferId': 1,
        'helpType': 'physical_presence',
        'rating': {'score': null, 'ratable': true},
      });
      expect(offer.rating, const OfferRatingEntity(score: null, ratable: true));
    });

    test('already rated: {score, ratable: false} — immutable (183)', () {
      final offer = OfferViewEntity.fromJson({
        'helpOfferId': 1,
        'helpType': 'physical_presence',
        'rating': {'score': 4, 'ratable': false},
      });
      expect(offer.rating, const OfferRatingEntity(score: 4, ratable: false));
    });

    test('helper has no account: {score: null, ratable: false} — never ratable (180)', () {
      final offer = OfferViewEntity.fromJson({
        'helpOfferId': 1,
        'helpType': 'physical_presence',
        'rating': {'score': null, 'ratable': false},
      });
      expect(offer.rating!.score, isNull);
      expect(offer.rating!.ratable, isFalse);
    });
  });

  group('ReportViewEntity.directionEstimate — the shared READ facet '
      '(decisions 202-204)', () {
    test('absent → null (below the floor, ineligible category, or summary tier)', () {
      expect(ReportViewEntity.fromJson(_owner()).directionEstimate, isNull);
    });

    test('present → the single winning Direction, never a count or distribution (203)', () {
      final view = ReportViewEntity.fromJson({
        ..._owner(),
        'directionEstimate': {'direction': 'N'},
      });
      expect(view.directionEstimate, Direction.n);
    });

    test('parses every one of the 8 compass points', () {
      for (final direction in Direction.values) {
        final view = ReportViewEntity.fromJson({
          ..._owner(),
          'directionEstimate': {'direction': direction.wire},
        });
        expect(view.directionEstimate, direction);
      }
    });

    test('it takes part in equality', () {
      final withEstimate = ReportViewEntity.fromJson({
        ..._owner(),
        'directionEstimate': {'direction': 'S'},
      });
      expect(withEstimate, isNot(ReportViewEntity.fromJson(_owner())));
    });

    test('copyWithOffers carries the estimate over unchanged', () {
      final view = ReportViewEntity.fromJson({
        ..._owner(),
        'directionEstimate': {'direction': 'E'},
      });

      final patched = view.copyWithOffers(const []);

      expect(patched.directionEstimate, Direction.e);
    });
  });

  group('ReportViewEntity.copyWithOffers', () {
    test('replaces only the offers list, keeping every other field', () {
      final view = ReportViewEntity.fromJson({
        ..._owner(hidden: true),
        'offers': [
          {'helpOfferId': 1, 'helpType': 'physical_presence'},
        ],
      });

      final patched = view.copyWithOffers(const [
        OfferViewEntity(
          helpOfferId: 1,
          helpType: 'physical_presence',
          rating: OfferRatingEntity(score: 5, ratable: false),
        ),
      ]);

      expect(patched.offers!.single.rating!.score, 5);
      expect(patched.reportId, view.reportId);
      expect(patched.hidden, view.hidden);
      expect(patched.access, view.access);
    });
  });
}
