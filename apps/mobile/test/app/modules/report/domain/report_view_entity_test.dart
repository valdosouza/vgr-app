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
}
