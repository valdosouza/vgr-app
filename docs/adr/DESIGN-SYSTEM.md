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
- Origin: `D:\Gestao2027\Infra-IA\setes-app\prompt_fase1_fundacao.md` §B
