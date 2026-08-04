/// Two-axis taxonomy (decisions 3/9/140) — canonical seed lives in CODE on
/// both sides (140d): this list mirrors `api/src/shared/taxonomy/taxonomy.ts`
/// and MUST change with it. Labels/icons are i18n keys
/// (`report.category.<key>` / `report.subject.<key>`), free to differ from
/// the key wording.
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

/// Second axis, ALWAYS required (decision 140). `other` is the one-tap
/// generic fallback protecting decision 123 (no forced friction).
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

/// Client-side mirror of MEDIA_MAX_PER_REPORT (decision 129) — the server
/// remains the authority; this only stops the 11th photo from being picked.
const maxPhotosPerReport = 10;

/// Version of the EXIF warning text shown when the reporter keeps the
/// original (decisions 86/130/139 — text approved as v1 in the plan §5).
const exifWarningVersion = 'exif-warning/v1';
