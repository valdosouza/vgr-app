{{flutter_js}}
{{flutter_build_config}}

// Decision 255: no font comes from a third party at run time. The engine
// would fetch its fallback fonts (Roboto and the Noto set) from
// fonts.gstatic.com, telling Google the app was opened and from which IP.
// Every text is drawn with the fonts bundled in vgr_widgets; the fallback
// base points at this app's own server, where none is published, so a
// glyph outside those fonts stays missing instead of being downloaded.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: 'assets/fonts/fallback/',
  },
});
