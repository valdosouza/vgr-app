/// Two-axis taxonomy KEY lists (decisions 3/9/140) — copied from
/// `api/src/shared/taxonomy/taxonomy.ts` (`CATEGORIES` / `SUBJECTS`), the
/// same mirror `apps/mobile/.../report/domain/entity/report_taxonomy.dart`
/// keeps. Modules never import each other (ARCHITECTURE.md), so the panel
/// carries its own copy; the three MUST change together. Labels are i18n
/// keys (`reports.category.<key>` / `reports.subject.<key>`).
const reportCategories = [
  'assault',
  'environmental',
  'robbery',
  'homicide',
  'illegal_commerce',
  'missing',
  'fugitive',
  'kidnapping',
  'suspicious',
  'trafficking',
  'traffic',
  'vandalism',
];

const reportSubjects = [
  'child',
  'adult',
  'animal',
  'vehicle',
  'property',
  'commerce',
  'weapon',
  'environment',
  'other',
];

/// `RiskTier` values (`api/src/shared/risk`) — the search filter and the
/// list badge speak in these keys (`reports.tier.<key>`).
const reportTiers = ['low', 'medium', 'high'];

/// `tb_report.status` CHECK values — moderation is NOT a status (162).
const reportStatuses = ['open', 'resolved'];
