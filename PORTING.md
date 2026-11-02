# Port status — Junction-rb

Resume point for the next run. State only; no estimates and no claims of
nearness. The parity reports in `.reports/` are the evidence behind the
"Open gaps" section and are more detailed than this file.

## Upstream

Junction is a desktop link dispatcher: handed a URI or a file it shows a grid
of the applications that can open it, launches the one picked, and quits. It
is implemented in JavaScript (GJS) with the interface in Blueprint `.blp`
files compiled into a GResource, plus the `troll` submodule, which supplies
the builder helper and the `ThemeSelector` widget.

The spec lives on the `origin/main` ref of this repo. Read it with
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
Never check out that ref and never merge it. The translation catalogue is not
on `origin/main` — it lives on upstream's `l10n` branch, which is where `po/`
came from.

## Done

Implemented and believed complete. One upstream source file per `lib` file,
in the house style (`# frozen_string_literal: true`, memoized widget
accessors, `.tap` configuration, a class comment naming the upstream file).

| Port | Upstream |
|---|---|
| `lib/junction_rb.rb` | `src/main.js`, `src/bin.js`, `src/local.js` (app id, website, dev flag, gettext init) |
| `lib/junction_rb/application.rb` | `src/application.js` |
| `lib/junction_rb/window.rb` | `src/window.js` + `src/window.blp` |
| `lib/junction_rb/menu_model.rb` | the `menu menu_model` block of `src/window.blp` |
| `lib/junction_rb/welcome_window.rb` | `src/welcome.js` + `src/welcome.blp` |
| `lib/junction_rb/about_dialog.rb` | `src/about.js` |
| `lib/junction_rb/shortcuts_dialog.rb` | `src/ShortcutsWindow.js` + `src/ShortcutsWindow.blp` |
| `lib/junction_rb/app_button.rb` | `src/AppButton.js` + `src/AppButton.blp` (`AppButton`, `popupActionsMenu`) |
| `lib/junction_rb/tile_button.rb` | the `TileButton` template of `src/AppButton.blp` |
| `lib/junction_rb/show_in_folder_button.rb` | `ShowInFolderButton` in `src/AppButton.js` |
| `lib/junction_rb/uri_entry.rb` | `src/Entry.js` |
| `lib/junction_rb/resource.rb` | `readResource` / `parse` in `src/util.js` |
| `lib/junction_rb/desktop_entry.rb` | the app-discovery, key-file and icon code of `src/util.js` and `src/common.js` |
| `lib/junction_rb/host.rb` | `prefixCommandLineForHost`, `getIconFilename` and the sandbox predicate in `src/util.js` |
| `lib/junction_rb/portal.rb` | the `Xdp` / `XdpGtk4` use in `src/util.js` and `src/window.js` (GI typelib loader; no libportal gem exists) |
| `lib/junction_rb/background_request.rb` | `xdp_portal_request_background` in `src/application.js` (Fiddle; see Blockers) |
| `lib/junction_rb/settings.rb` | `src/common.js` + `data/re.sonny.Junction.gschema.xml` |
| `lib/junction_rb/theme_switcher.rb` | `troll/src/widgets/ThemeSelector.js`, reconstructed (see Blockers) |
| `exe/junction-rb` | `src/junction` |
| `data/style.css` | `src/style.css`, byte-identical except for the appended ThemeSelector rules |
| `data/re.sonny.Junction.Rb.desktop` | `data/re.sonny.Junction.desktop` |
| `data/re.sonny.Junction.Rb.metainfo.xml` | `data/re.sonny.Junction.metainfo.xml` (partial — see Open gaps) |
| `data/re.sonny.Junction.Rb.service` | `data/re.sonny.Junction.service` |
| `data/schemas/re.sonny.Junction.Rb.gschema.xml` | `data/re.sonny.Junction.gschema.xml` |
| `data/icons/**` | `data/icons/*.svg`, `data/icons/re.sonny.Junction.png` |
| `po/` (32 languages), `locale/**/*.mo` | upstream's `l10n` branch, copied untouched |
| `test/resource_test.rb`, `test/desktop_entry_test.rb` | all four tests of `test/util.test.js` |

`lib/junction_rb/version.rb` and the other `test/*.rb` files have no upstream
counterpart; they pin the ruby-gnome divergences listed under Blockers.

The original blank-window skeleton (`lib/junction.rb`, `lib/junction/`) has
been deleted; all live code is under `JunctionRb`.

## Not started

Upstream components with no Ruby counterpart at all:

- `meson.build` and `data/meson.build` — the install rules for the desktop
  file, the metainfo, the schema and the two icons, the `i18n.merge_file`
  translation merge, and the three build-time validation tests.
  `namespace :install` in the `Rakefile` contains only `:service`.
- `data/screenshot-file.png` and `data/screenshot-mobile.png`, and the two
  `<screenshot>` elements that reference them.
- `re.sonny.Junction.json` (Flatpak manifest) and
  `build-aux/flatpak/glib-appinfo.patch`.
- `po/re.sonny.Junction.pot` — no committed message template, so the port's
  msgid set has no reviewable record.
- `src/importmap.json`, `src/meson.build`, `package.json`, `eslint.config.mjs`,
  `.husky/*`, `Makefile` — GJS/npm build and lint plumbing with no analogue in
  a gem-packaged app, and not intended to be ported.

## Open gaps

The last audit reported **15 gaps** and `clean=false`. Every parity report in
`.reports/` returns "not clean". By report:

`.reports/component-parity.md` (P0–P8)

1. **P0** Nothing installs the desktop file, the metainfo, the schema or the
   icons. The schema is found only because `rake run` / `rake test` export
   `GSETTINGS_SCHEMA_DIR`; launched any other way, start-up aborts in
   `Application#start_up`. Without a `.desktop` in `applications/` the port
   can never be registered as a handler, which is the app's whole purpose,
   and `WelcomeWindow#claim_web_types` is a no-op.
2. **P1** `junction-rb.gemspec` declares no runtime dependencies at all;
   `gtk4`, `adwaita`, `gettext` and `gobject-introspection` are only in the
   `Gemfile`. An installed gem dies at `lib/junction_rb.rb:3`.
3. **P2** `window.rb` builds `Gtk::WindowControls.new(:end)` with layout
   `close`; upstream leaves `side` at `start`. The end group is empty, so the
   landscape bottom bar has no close button.
4. **P3** `Rakefile` and `README.md` both document `bin/junction-rb`, which
   does not exist — the executable is `exe/junction-rb`.
5. **P4** Two of three screenshots and their captions are missing; one of the
   dropped captions has 32 translations in `po/`.
6. **P5** No Flatpak manifest, so none of the sandbox code paths can be
   exercised against a real sandbox.
7. **P6** Upstream's three build-time validations are not ported;
   `rake schema` omits `--strict`.
8. **P7** `<url type="donation">` is dropped from the metainfo.
9. **P8** `show_in_folder_button.rb` sets `width_request`/`height_request` to
   48 as well as `pixel_size`, so the "Open Location" tile collapses to 48
   instead of keeping the 92×92 box every other tile has.

`.reports/test-parity.md` (Gaps 1–3)

10. Upstream's three `meson` validation tests (`desktop-file-validate`,
    `appstreamcli validate`, `glib-compile-schemas --strict --dry-run`) have
    no port equivalent.
11. The suite cannot be executed in this checkout (`gtk4`/`adwaita` not
    installed, so every file fails at require time) and `.gitlab-ci.yml` is
    the unmodified kettle template that never invokes `rake test`. **No
    assertion in the port's suite has been observed to pass**; the test-parity
    census is static. Also: `rake test` uses `sh`, so the first failing file
    hides the seven after it.
12. `rake test` depends on `gettext:mo:update`, which degrades to a
    `warn`-only stub when the gettext gem is missing, so the suite can report
    success with no catalogue compiled.

`.reports/translation-parity.md` (Gaps 1–4)

13. The desktop file and the metainfo are never merged with the catalogue
    (`msgfmt --desktop` / `msgfmt --xml`), so `Comment=`, `<summary>` and the
    caption ship English-only while all 32 translations sit in `po/`.
14. Eight strings the port displays have no msgid in any of the 32
    catalogues.
15. One msgid with 32 translations was deleted outright by dropping a
    screenshot (same root cause as P4).
16. `po/POTFILES` lists three data files the extraction task never reads
    (`Rakefile` globs `lib/**/*.rb` and `exe/*`), so the manifest asserts
    coverage that does not exist.

That enumeration gives 16 numbered headings against the audit's count of 15;
gap 16 and gap 13 overlap in the data-file translation path, and
`.reports/accountability-ensurance.md` counts them as one.

`.reports/accountability-ensurance.md` adds no gaps of its own — the code
carries zero deferral markers, zero disabled features and no feature-swallowing
`rescue` — but it records that `README.md` has no "Installing" section, so none
of the above is acknowledged anywhere a reader would look.

## Blockers

Cannot be ported as upstream writes it, with the reason. All are mechanism
changes with the behaviour preserved, except the first.

- **Translations are not wired at all.** Every upstream string goes through
  `_()` against the `re.sonny.Junction` gettext domain, and the port keeps that
  domain (`JunctionRb::TEXT_DOMAIN`) so the 32 catalogues are still found. But
  the catalogue itself is not on `origin/main` — it lives on `origin/l10n` — so
  porting the message set requires a second spec ref. The eight strings in gap
  14 and the merge in gap 13 are both downstream of this.
- **`win.run_action`'s `a{ss}` dictionary variant cannot be built through
  ruby-gnome**, so the port's target is `as` (`[desktop id, action]`) and the
  location is read off the entry at activation time rather than carried in the
  target. Behaviour is the same, and arguably better: an edit made after the
  menu opened is honoured.
- **`Adw.Breakpoint` setters cannot take a boolean through ruby-gnome** —
  `adw_breakpoint_add_setter` is reached without a `GValue` and the call is
  dropped with a critical. The five portrait setters are reimplemented as
  `apply`/`unapply` handlers; same condition, same five changes.
- **`Gtk.ShortcutsWindow` is deprecated in GTK 4.18** and unavailable in the
  form upstream uses it, so the shortcuts reference is an
  `Adwaita::ShortcutsDialog` and upstream's modal / transient-for handling is
  dropped.
- **The `troll/` submodule is a gitlink that is not checked out**, so
  `ThemeSelector` and its 52 lines of CSS have no upstream rows in this repo.
  They are reconstructed in `lib/junction_rb/theme_switcher.rb` and appended
  to `data/style.css`, and the exact upstream widget tree cannot be diffed
  from `origin/main`. Upstream's 1.13 note "Follow system color scheme and
  accent color" suggests the real widget may now do more than the port's
  three-button copy; unconfirmable here.
- **The Flatpak manifest and `glib-appinfo.patch` cannot be ported to a
  gem-packaged app**, so the sandbox branches in `host.rb`, `portal.rb`,
  `background_request.rb`, `desktop_entry.rb`, `resource.rb` and
  `application.rb` are only exercisable against a real Flatpak install. The
  `Host.flatpak =` seam lets the tests enter both branches, but nothing
  exercises the real sandbox.
- **`xdp_portal_request_background` takes a `GPtrArray` in-argument**, which
  ruby-gnome refuses with `TODO: in Ruby -> GIArgument(array/GPtrArray)`, so
  that one call goes through Fiddle (`background_request.rb`).
- **`Gio::AppInfo`'s action API is unbound**, so desktop actions are parsed out
  of the key file — which upstream does anyway, because GLib cannot launch a
  desktop action with a URI argument (glib#2568).
- **`GLib::Uri` is unbound**, so the URI scheme is read off the text with a
  regex. This is also why the port gets `https` right where
  `g_file_get_uri_scheme` reports `http`.
- **`Adwaita::Application` is broken in the bindings**, so the application is a
  `Gtk::Application` with `Adwaita::ApplicationWindow` windows — the shape the
  pilot port `gnome-contacts-rb` uses.
- **Fixture `.desktop` files cannot be planted for Gio to discover**, because
  GLib always includes the system data directories and `XDG_DATA_DIRS` cannot
  be narrowed. Discovery is tested against the real installed applications;
  key-file parsing against fixtures handed to `DesktopEntry` directly.
- **`__DEV__` is compiled in by upstream's `gjspack` bundler.** There is no
  bundler here, so `JUNCTION_RB_DEV=1` turns on the same two things.
