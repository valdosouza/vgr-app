import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';

/// "Page 1 of 3 · 42 records" — the one pager summary of the panel
/// (decision 220), the record count pluralized ("1 registro", not
/// "1 registros" — browser test of 2026-10-04).
String pageSummary(PagedResult<dynamic> page) => 'register.pageSummary'.tr(namedArgs: {
      'page': '${page.page}',
      'pages': '${page.pageCount}',
      'records': 'register.records'.plural(page.total),
    });
