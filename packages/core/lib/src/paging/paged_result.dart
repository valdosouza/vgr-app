import 'package:equatable/equatable.dart';

/// One page of a panel list (decision 220) — the client side of the API's
/// `{ items, page, pageSize, total }` envelope (`api/src/shared/http/
/// paged-query.ts`), the same shape `reports` and `admin-audit` already
/// answered before PS0 generalized it.
class PagedResult<T> extends Equatable {
  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  /// No rows at all — what a list shows before its first answer.
  const PagedResult.empty({this.pageSize = PagedQuery.defaultPageSize})
      : items = const [],
        page = 1,
        total = 0;

  final List<T> items;
  final int page;
  final int pageSize;

  /// Rows matching the filter across every page, not just this one.
  final int total;

  /// At least 1, so "page 1 of 1" reads right on an empty list.
  int get pageCount => total <= 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

  bool get hasPrevious => page > 1;
  bool get hasNext => page < pageCount;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) =>
      PagedResult(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => itemFromJson(item as Map<String, dynamic>))
            .toList(),
        page: (json['page'] as num).toInt(),
        pageSize: (json['pageSize'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

/// What a paged list asks for (decision 220): `page` (from 1), `pageSize`
/// (1..[maxPageSize]) and an optional free-text `filter`. Mirrors the API's
/// `pagedQueryDto`, so the limits here are the ones the server enforces.
class PagedQuery extends Equatable {
  const PagedQuery({this.page = 1, this.pageSize = defaultPageSize, this.filter = ''});

  static const defaultPageSize = 20;
  static const maxPageSize = 100;

  /// The sizes a list offers to pick from — all within [maxPageSize].
  static const pageSizes = [10, 20, 50, 100];

  final int page;
  final int pageSize;

  /// Blank means no filter, the same rule the API applies after trimming.
  final String filter;

  PagedQuery copyWith({int? page, int? pageSize, String? filter}) => PagedQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        filter: filter ?? this.filter,
      );

  /// `page=1&pageSize=20[&filter=...]`, values URL-encoded; the filter is
  /// left out when blank.
  String toQueryString() {
    final trimmed = filter.trim();
    return Uri(queryParameters: {
      'page': '$page',
      'pageSize': '$pageSize',
      if (trimmed.isNotEmpty) 'filter': trimmed,
    }).query;
  }

  @override
  List<Object?> get props => [page, pageSize, filter];
}
