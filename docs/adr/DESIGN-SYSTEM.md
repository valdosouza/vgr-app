# Design system — every widget is encapsulated (decision 133)

> Brought over from the setes-app, which applies the same rule with the
> `Setes` prefix (`Infra-IA/setes-app/prompt_fase1_fundacao.md` §B,
> its decision 11). Same rule, this project's prefix.

## The rule

**No Flutter widget — or any external package's widget — is used directly
in a screen.** Every widget is encapsulated in a house widget under
`packages/vgr_widgets`, and only the house widget is used across the
system.

Why: it allows swapping an obsolete or unmaintained widget without
touching the whole system. One implementation changes in one file; the
hundreds of call sites do not move.

Naming: prefix `Vgr` (`Text` → `VgrText`, `ListTile` → `VgrListTile`,
`CircularProgressIndicator` → `VgrLoading`).

**Widget × component**: in Flutter they are the same concept — "component"
is the generic term, "widget" is the Flutter materialization. Official
term here: **widget** (same convention as setes' decision 8).

## What this buys beyond swap-ability

The catalog is where cross-cutting behavior stops being copy-pasted:

- **Semantic roles instead of styles.** `VgrText.title(...)`, never a
  hand-built `TextStyle` — typography changes in one file.
- **Icons named by meaning.** `VgrIconName.delete`, not
  `Icons.delete_outline` — the icon set is swappable, and the name says
  what it does instead of what it draws.
- **Busy state built in.** `VgrPrimaryButton(busy: ...)` replaced the
  hand-rolled "spinner instead of label" each screen had written slightly
  differently.
- **A spacing scale.** `VgrGap.md()` instead of `SizedBox(height: 16)`.
- **Defaults that prevent known bugs.** `VgrRow` shrinks by default,
  because a greedy Row is exactly what breaks a `ListTile` trailing slot —
  the mistake is prevented once here instead of diagnosed per screen.
- **Required tooltips** on icon-only buttons: an unnamed icon is unusable
  with a screen reader.

## Scope and exemptions

| Area | Rule |
|---|---|
| `apps/*/lib` (screens, pages, blocs) | Encapsulated only |
| `packages/core/lib` (shared widgets) | Encapsulated only |
| `packages/vgr_widgets` | **Exempt** — encapsulating raw widgets is its job |
| `test/` | **Exempt** — tests legitimately pump raw widgets |

Structural pieces that are not visual widgets are out of scope:
`MaterialApp`, `Navigator`, `Theme`, `MediaQuery`, `LayoutBuilder`,
`BlocBuilder`, `Key`, `TextEditingController`, and — since the admin
shell (decision 218, 2026-09-21) — flutter_modular's `RouterOutlet` and
the breakpoint helper `VgrResponsive` (which lives in `vgr_widgets` but
draws nothing: it only picks one of the widgets it is handed).

## Shell widgets (decision 215, 2026-09-21)

The admin panel renders every screen inside a persistent shell, so the
catalog gained the pieces the shell is made of: `VgrPage` (a screen
INSIDE the shell — same parameters as `VgrScaffold`, but a content header
instead of an `AppBar`; moving a screen into the shell is a rename),
`VgrNavColumn` / `VgrSidebarLayout` (the two navigation columns beside
the outlet), `VgrDrawer` (the mobile form), `VgrScaffold.drawer` /
`.leading`, `VgrListTile.selected`, `VgrIconName.logout`. `VgrScaffold`
stays for the screens OUTSIDE the shell (login, 2FA).

## Register widgets (PS2, 2026-10-04 — decisions 217/220/221)

The admin register factory (`apps/admin/lib/app/shared/register/`) is
built from these, all translation-free (labels arrive translated):
`VgrFormShell` (back · title · delete · save over a scrolling body, a
`VgrPage` underneath — a null save/delete is not drawn; `busy` spins save
and silences both), `VgrPagingBar` (previous · summary · next + page-size
picker — the one pager of the panel lists), `VgrSearchBar` (filter field
submitted by Enter or the magnifier, never per keystroke), `VgrEmptyState`,
`VgrPage.leading`, `VgrTextField.focusNode` / `.readOnly`, and two dialogs
— `showVgrAlert` (one button) and `showVgrChoice<T>` (N typed answers).
Screens do not call the dialogs themselves: they go through the admin's
feedback bridge (decision 221, see TESTS.md).

## Visual identity (round 24, decisions 255-264 — V2, 2026-10-13)

The theme lives in the design system too, so one file dresses every screen
of both apps. Source of every value: `AI/docs/identidade-visual/v1b/`
(`gerador/tokens.py` for colors, `gerador/mark.py` for the symbol), the
direction Valdo chose in round 24.

| Piece | Where | What it does |
|---|---|---|
| `VgrColors` | `vgr_colors.dart` | The identity's colors by role (`bg`, `surface`, `text`, `muted`, `brand`, `action`, `accent*`, `control`, `danger`, `navStrong`/`navSoft`, `splash`), `light` and `dark`, as a `ThemeExtension`. Widgets read `VgrColors.of(context)`; screens never do. |
| `VgrTheme` | `vgr_theme.dart` | `light()` / `dark()` → `ThemeData`. Both apps pass them with `ThemeMode.system` (decision 256). Navy `brand` is Material's `primary` (selection, links, focus); the main buttons, the FAB and checkboxes are the teal `action`; `error` is the red. |
| Fonts | `vgr_widgets/fonts/` | Atkinson Hyperlegible Next (400/600/700/800) and Atkinson Hyperlegible Mono (400), OFL, bundled and **never fetched at run time** (decision 255). `VgrTheme.registerFontLicense()` puts both licenses on the license page; each app's `main` calls it. |
| `VgrSymbol`, `VgrLogo`, `VgrLogoHeader` | `vgr_mark.dart` | The symbol drawn with a `CustomPainter` (the same geometry as the vector files), the logo, and the logo header of the login screens. |
| `VgrScaffold.showMark` | `vgr_scaffold.dart` | The symbol before the title — only on each app's home (mobile "Por perto", panel shell). |
| `VgrPrimaryButton.danger` | `vgr_button.dart` | Red, for the panic trigger only. `VgrIconButton` paints `VgrIconName.panic` red by itself. Red is kept for panic and errors (decision 253). |

Rules that keep it honest:

- **Contrast is tested.** `vgr_widgets/test/vgr_colors_test.dart` checks
  every token pair and every Material role the theme derives against WCAG
  AA (decision 257: 4.5:1 text, 3:1 graphics and control borders), in
  both themes. A color that breaks the floor fails the build.
- **The gold is not a UI color.** It is the light of the symbol and the
  reward seal of decision 101; there is no trophy, no points (decision
  262). In the light theme it is drawn as `accentGraphic` (#BB8329), the
  only gold that passes 3:1 on white.
- **No hard-coded colors in widgets.** Placeholders and borders take their
  color from `VgrColors` or the scheme, so the dark theme needs no
  per-widget code.
- **No font from a third party on the web either.** Each app's
  `web/flutter_bootstrap.js` points the engine's `fontFallbackBaseUrl` at
  the app's own server, where nothing is published: the engine's default
  Roboto request is answered 404 by our server instead of reaching
  fonts.gstatic.com, and every text is drawn with the bundled fonts.

Platform files (icons, opening screens, names) are generated from the same
vector source by `AI/docs/identidade-visual/v1b/gerador/plataformas.py`
and are not edited by hand:

- Android: adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`, navy
  background, foreground and themed monochrome vector drawables), legacy
  PNG icons, the opening screen as a layer list (`launch_background.xml`,
  `splash_symbol.xml`, light and `-night`) and Android 12+'s splash
  (`values-v31` / `values-night-v31`, `splash_icon.xml`); label "VGR".
- iOS: `AppIcon.appiconset` (opaque), `LaunchImage` with a dark
  appearance, `LaunchBackground` (one pixel per appearance, stretched by
  `LaunchScreen.storyboard`); display name "VGR".
- Web: `favicon.svg` + `favicon.png`, `icons/` (rounded and maskable),
  `manifest.json` and `index.html` (title, colors, the page background
  before Flutter draws, light and dark). The panel is "VGR · Painel".

## Enforcement

`apps/admin/test/design_system_guard_test.dart` scans screen code for a
list of banned widgets and fails the build with file:line for each
offender. The rule was in `vgr_widgets/pubspec.yaml` from day one and was
still violated in ~350 places, because nothing checked it — the test is
what turns the rule from a suggestion into a constraint.

## How to add a widget

1. Is it missing from the catalog? Add it to `packages/vgr_widgets/lib/src/`
   and export it from `vgr_widgets.dart`.
2. Expose **intent**, not Flutter internals: a role, a semantic icon name,
   a `busy` flag — not a `TextStyle` or an `IconData`.
3. Cover it in `packages/vgr_widgets/test/`.
4. If it is a new banned raw widget, add it to the guard's list.

## Testing consequence

Tests assert on the house widget, never on the Flutter internal:
`tester.widget<VgrIconButton>(...)`, not `tester.widget<IconButton>(...)`.
A test reaching past the design system would break on every
implementation swap — which is the exact coupling this rule removes.

## References

- Catalog: `packages/vgr_widgets/lib/vgr_widgets.dart`
- Guard: `apps/admin/test/design_system_guard_test.dart` (its companion for
  feedback, decision 221: `apps/admin/test/feedback_bridge_guard_test.dart`)
- Where the register widgets are used: `ARCHITECTURE.md` § ADMIN PANEL,
  `ADMIN-SCREENS.md`
- Decision 133: `AI/docs/decisions/VGR-plano.md`
- Visual identity: decisions 250-266 (rounds 23-24), `AI/docs/plans/plano-identidade-visual.md`
- Origin: `D:\Gestao2027\Infra-IA\setes-app\prompt_fase1_fundacao.md` §B
