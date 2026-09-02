/// vgr_validators — shared format validators and input masks of the vgr-app
/// (decisions 153–157).
///
/// - Every rule mirrors ONE Zod rule in the API, named in the validator's
///   doc comment and proved identical by the tests (decision 154). The API
///   is the source of truth and ALWAYS revalidates — this package is
///   feedback, never security (decisions 47/110).
/// - A validator returns a [VgrFieldError] (the API's own per-field code,
///   decision 83), never text: the screen translates it (decision 157).
/// - Pure functions plus a [TextInputFormatter] mask; no widgets, no i18n,
///   no network. Screens hand [VgrMask] to `VgrTextField.mask`, never touch
///   the formatter directly (decision 133).
library;

export 'src/br_tax_id.dart';
export 'src/field_error.dart';
export 'src/mask.dart';
export 'src/validators.dart';
