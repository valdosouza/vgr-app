# Atkinson Hyperlegible Next (decision 255)

The app's only typeface, bundled here and never fetched at run time:
downloading it would tell a third party that the app was opened, and from
which IP.

- Source: `ofl/atkinsonhyperlegiblenext/AtkinsonHyperlegibleNext[wght].ttf`
  in github.com/google/fonts, by the Braille Institute.
- License: SIL Open Font License 1.1 (`OFL.txt`, also registered with
  `LicenseRegistry` by `VgrTheme.registerFontLicense`).
- The four files are static instances of the variable font at weights 400,
  600, 700 and 800, made with fontTools so every platform gets the right
  weight without relying on variable-font support:

  ```sh
  python3 -c "from fontTools.ttLib import TTFont; from fontTools.varLib import instancer
  for w, n in [(400, 'Regular'), (600, 'SemiBold'), (700, 'Bold'), (800, 'ExtraBold')]:
      instancer.instantiateVariableFont(TTFont('AtkinsonHyperlegibleNext[wght].ttf'), {'wght': w},
          updateFontNames=True).save(f'AtkinsonHyperlegibleNext-{n}.ttf')"
  ```

800 is only used by the wordmark of `VgrLogo`.

`AtkinsonHyperlegibleMono-Regular.ttf` is the 400 instance of
`ofl/atkinsonhyperlegiblemono/AtkinsonHyperlegibleMono[wght].ttf`, made the
same way, with its own `OFL-Mono.txt`: the fixed-width text of
`VgrText(monospace: true)` (2FA secrets, audit values), so not even a
generic "monospace" is left to a system or downloaded font.
