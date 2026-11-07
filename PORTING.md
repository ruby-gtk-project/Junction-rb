# Port status — Junction-rb

Resume point for the next run. State only; no estimates and no claims of
nearness. The parity reports in `.reports/` are the evidence behind "Open
gaps" and are more detailed than this file.

## Upstream

Junction is a desktop link dispatcher (dispatcher app: chooses an
application to open a URL/file): handed a URI or a file it shows a grid of
the applications that can open it, launches the one picked, and quits. It is
implemented in JavaScript (GJS) with the interface in Blueprint `.blp` files
compiled into a GResource, plus the `troll` submodule, which supplies the
builder helper and the `ThemeSelector` widget. This port is written in Ruby
(GTK4/Libadwaita).

The spec lives on the `origin/main` ref of this repo. Read it with
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
Never check out that ref and never merge it. The translation catalogue is not
on `origin/main` — it lives on upstream's `l10n` branch, which is where `po/`
came from.

## Done

Implemented and observed working by `test/drive_junction.rb` /
`test/drive_locale.rb` or by the per-file `test/*_test.rb` scripts. One
upstream source file per `lib` file, in the house style
(`# frozen_string_literal: true`, memoized widget accessors, `.tap`
configuration, a class comment naming the upstream file).

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
| `data/re.sonny.Junction.Rb.metainfo.xml` | `data/re.sonny.Junction.metainfo.xml` (field-level content not byte-diffed this pass — see Blockers) |
| `data/re.sonny.Junction.Rb.service` | `data/re.sonny.Junction.service` |
| `data/schemas/re.sonny.Junction.Rb.gschema.xml` | `data/re.sonny.Junction.gschema.xml` (key default values not byte-diffed this pass — see Blockers) |
| `data/icons/**` | `data/icons/*.svg`, `data/icons/re.sonny.Junction.png` |
| `po/` (32 languages), `locale/**/*.mo` | upstream's `l10n` branch, copied untouched |
| `test/resource_test.rb`, `test/desktop_entry_test.rb`, `test/welcome_test.rb`, `test/url_test.rb`, `test/settings_test.rb`, `test/portal_test.rb`, `test/window_test.rb`, `test/cli_test.rb` | the per-component suites, re-run this pass via `rake test` (exit 0) |

`lib/junction_rb/version.rb` and the other `test/*.rb` files have no upstream
counterpart; they pin the ruby-gnome divergences listed under Blockers.

The original blank-window skeleton (`lib/junction.rb`, `lib/junction/`) has
been deleted; all live code is under `JunctionRb`.

## Runtime

    nix develop --command xvfb-run -a ruby test/drive_junction.rb

Result this run: drive_ok=true, **247 passed / 0 failed**, 17 components
covered (the component list in `.reports/drive.md`'s "What the run covers"
table: `JunctionRb`, `Application`, `WelcomeWindow`, `Window`, `UriEntry`,
`ThemeSwitcher`, `MenuModel`, `TileButton`, `AppButton`,
`ShowInFolderButton`, `AboutDialog`, `ShortcutsDialog`, `Settings`,
`Resource`, `DesktopEntry`, `Host`, `Portal`/`BackgroundRequest` grouped, and
`Version`).

`nix develop --command xvfb-run -a ruby test/drive_locale.rb` also ran this
pass: 16 of 16 checks passed, DRIVE OK.

`nix develop --command xvfb-run -a rake test` (the per-file `test/*_test.rb`
suites) also ran this pass and exited 0; the last suite in the run
(`test/welcome_test.rb`) reported **specs 17 passed / 0 failed**, matching
every other suite's own DRIVE OK line in the same run.

## Not started

- **Flatpak manifest.** Upstream ships `re.sonny.Junction.json` and
  `build-aux/flatpak/glib-appinfo.patch`; the port ships neither. Every
  sandbox code path (`lib/junction_rb/host.rb`, `lib/junction_rb/portal.rb`,
  `lib/junction_rb/background_request.rb`, parts of
  `lib/junction_rb/desktop_entry.rb`, `lib/junction_rb/resource.rb` and
  `lib/junction_rb/application.rb`) is written and unit-tested through the
  `Host.flatpak?` seam but has never run inside a real sandbox, because
  building the manifest needs `flatpak-builder` and a Ruby/gem base-app
  story neither available in this environment.
- Byte-level parity of packaging/metadata *content* (desktop actions,
  metainfo release notes, schema key defaults) against upstream — presence
  of these files was confirmed, their field values were not diffed this
  pass.

## Open gaps

The last audit (`.reports/component-parity.md`, `.reports/test-parity.md`)
reported **2 gap(s), clean=false**:

1. No Flatpak manifest (component-parity C3 / the "Not started" item above),
   so none of the sandbox code paths has been exercised against a real
   sandbox.
2. Translation coverage gaps carried from the `l10n`-branch merge: the two
   restored screenshot captions and the eight msgids the donated catalogues
   predate (`Main Menu`, `Show App Names`, `Open Location`,
   `View File in File Manager`, `Run Junction in the background.`,
   `Light Style`, `Follow System Style`, `Dark Style`) remain untranslated
   (or fuzzy, for `Show App Names`) in some or all of the 32 languages;
   `rake gettext:merge` has wired the mechanism but no translations were
   invented to fill them.

## Blockers

Cannot be ported as upstream writes it, with the reason. All are mechanism
changes with the behaviour preserved, except the first.

- **Translations are not wired from a single spec ref.** Every upstream
  string goes through `_()` against the `re.sonny.Junction` gettext domain,
  and the port keeps that domain so the 32 catalogues are still found, but
  the catalogue itself lives on `origin/l10n`, not `origin/main`.
- **`win.run_action`'s `a{ss}` dictionary variant cannot be built through
  ruby-gnome**, so the port's target is `as` (`[desktop id, action]`) with
  the location read off the entry at activation time.
- **`Adw.Breakpoint` setters cannot take a boolean through ruby-gnome**;
  the five portrait setters are reimplemented as `apply`/`unapply` handlers.
- **`Gtk.ShortcutsWindow` is deprecated/unavailable in GTK 4.18**, so the
  shortcuts reference is an `Adwaita::ShortcutsDialog` instead.
- **The `troll/` submodule is a gitlink that is not checked out** in this
  repo's working tree, so `ThemeSelector` is reconstructed in
  `lib/junction_rb/theme_switcher.rb` without a direct diff against the
  pinned upstream commit.
- **The Flatpak manifest and `glib-appinfo.patch` cannot be ported to a
  gem-packaged app** — see Not started.
- **`xdp_portal_request_background` takes a `GPtrArray` in-argument**, which
  ruby-gnome refuses, so that call goes through Fiddle
  (`lib/junction_rb/background_request.rb`).
- **`Gio::AppInfo`'s action API is unbound**, so desktop actions are parsed
  out of the key file directly.
- **`GLib::Uri` is unbound**, so the URI scheme is read off the text with a
  regex.
- **`Adwaita::Application` is broken in the bindings**, so the application
  is a `Gtk::Application` with `Adwaita::ApplicationWindow` windows — the
  shape the pilot port `gnome-contacts-rb` uses.
- **Fixture `.desktop` files cannot be planted for `Gio` to discover**
  because `XDG_DATA_DIRS` cannot be narrowed away from the system dirs;
  discovery is tested against real installed applications, key-file parsing
  against fixtures handed to `DesktopEntry` directly.
- **`__DEV__` is compiled in by upstream's `gjspack` bundler**; there is no
  bundler here, so `JUNCTION_RB_DEV=1` substitutes.

Survey-flagged, not a code blocker:

- No other blocking issue was found by this survey. Packaging/metadata file
  *content* (desktop actions, metainfo release notes, schema key defaults)
  was not byte-diffed against upstream this pass — presence was confirmed
  but field-level parity should be checked in a follow-up
  component-parity/translation-parity pass.
- A prior `.reports/component-inventory.md` already existed on the `ruby`
  branch from an earlier run (git history shows 4 earlier commits with the
  same subject). This run's survey overwrote it with a fresh pass rather
  than diffing against the previous content — worth noting in case the
  earlier version had findings this pass didn't re-derive.
