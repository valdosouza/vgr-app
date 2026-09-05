/// The 8-point compass direction sighted for a fleeing subject (DS front,
/// round 15, decisions 200-207).
///
/// Shared by the `report` module (rendering the read-only
/// `directionEstimate` facet on the detail view and the feed) and the
/// `direction_sighting` module (submitting a sighting and reading its own
/// private write-response `estimate`) — promoted here rather than one
/// module importing the other's entity file (`docs/adr/ARCHITECTURE.md`'s
/// "a module never imports another module"), the same reason `RiskTier`
/// lives in `packages/core`.
///
/// Deliberately NOT used by `packages/vgr_widgets`' `VgrCompass` widget:
/// the design system depends on nothing but `vgr_validators` today (no
/// `packages/core`, no business logic — the Style layer's own rule in
/// `docs/adr/ARCHITECTURE.md`). `VgrCompass` works with the plain wire
/// strings ('N', 'NE', ...) instead; the conversion to/from [Direction]
/// happens at the call site (`report_detail_page.dart`), which already has
/// both `core` and `easy_localization` in scope.
enum Direction {
  n('N'),
  ne('NE'),
  e('E'),
  se('SE'),
  s('S'),
  sw('SW'),
  w('W'),
  nw('NW');

  const Direction(this.wire);

  /// The value the API speaks (`POST /app-direction-sightings`'s
  /// `direction`, the READ facet's `direction`, the write response's
  /// `estimate`) — and the i18n key suffix (lowercased: `compass.<name>`).
  final String wire;
}

extension DirectionJson on Direction {
  static Direction fromJson(String value) =>
      Direction.values.firstWhere((d) => d.wire == value);

  String toJson() => wire;
}
