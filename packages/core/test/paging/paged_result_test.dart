import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PagedResult (decision 220 — the API envelope { items, page, pageSize, total })', () {
    test('fromJson maps every field and each item through the given parser', () {
      final page = PagedResult<int>.fromJson(
        {
          'items': [
            {'id': 3},
            {'id': 4},
          ],
          'page': 2,
          'pageSize': 2,
          'total': 5,
        },
        (json) => json['id'] as int,
      );

      expect(page.items, [3, 4]);
      expect(page.page, 2);
      expect(page.pageSize, 2);
      expect(page.total, 5);
    });

    test('pageCount rounds up and never drops below 1', () {
      expect(const PagedResult<int>(items: [], page: 1, pageSize: 20, total: 41).pageCount, 3);
      expect(const PagedResult<int>(items: [], page: 1, pageSize: 20, total: 40).pageCount, 2);
      expect(const PagedResult<int>(items: [], page: 1, pageSize: 20, total: 0).pageCount, 1);
    });

    test('hasPrevious / hasNext follow the page position', () {
      const middle = PagedResult<int>(items: [], page: 2, pageSize: 10, total: 30);
      expect(middle.hasPrevious, isTrue);
      expect(middle.hasNext, isTrue);

      const last = PagedResult<int>(items: [], page: 3, pageSize: 10, total: 30);
      expect(last.hasNext, isFalse);

      const first = PagedResult<int>.empty();
      expect(first.hasPrevious, isFalse);
      expect(first.hasNext, isFalse);
    });
  });

  group('PagedQuery — mirrors the API pagedQueryDto', () {
    test('defaults to page 1, 20 per page, no filter', () {
      expect(const PagedQuery().toQueryString(), 'page=1&pageSize=20');
    });

    test('a blank filter is left out, a real one is trimmed and URL-encoded', () {
      expect(const PagedQuery(filter: '   ').toQueryString(), 'page=1&pageSize=20');
      expect(
        const PagedQuery(page: 3, pageSize: 50, filter: ' ana & co ').toQueryString(),
        'page=3&pageSize=50&filter=ana+%26+co',
      );
    });

    test('every offered page size is within the API maximum', () {
      expect(PagedQuery.pageSizes.every((size) => size <= PagedQuery.maxPageSize), isTrue);
      expect(PagedQuery.pageSizes, contains(PagedQuery.defaultPageSize));
    });

    test('copyWith keeps what it is not given', () {
      const query = PagedQuery(page: 2, pageSize: 10, filter: 'x');
      expect(query.copyWith(page: 1), const PagedQuery(page: 1, pageSize: 10, filter: 'x'));
      expect(query.copyWith(filter: ''), const PagedQuery(page: 2, pageSize: 10));
    });
  });
}
