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

## What I have not ported, and what that costs a user

This section used to be headed "Not started", over the sentence "Upstream
components with no Ruby counterpart at all". I wrote both, and both were
excuses: "not started" reads as a scope boundary a reader can accept, and "no
Ruby counterpart" reads as a technical impossibility. Neither was true of the
things on this list. A Flatpak manifest is a JSON file and a screenshot is a
PNG; nothing about Ruby prevents either. The entries below say what is
missing, what a user loses by it, and where upstream does the thing I did not.

The screenshots used to be the first entry here, under the claim that this
machine has no browser and no image viewer installed so any grid captured on
it would be empty. That was true of the machine and false as a reason: the
drive script had already been planting its own applications in a scratch
`XDG_DATA_HOME` for months, and I had read that file. `test/screenshot_apps.rb`
plants a presentation set the same way and `test/capture_screenshots.rb`
(`rake screenshots`) photographs all three of upstream's views — the link, the
image file and the phone-width window — into `docs/`, with a check on each one
so an empty grid fails the run instead of being published. All three
`<screenshot>` elements and their captions are in the metainfo, and
`rake gettext:merge` has put both restored msgids back in front of the
translators who had already translated one of them.

- **I have not ported the Flatpak manifest, so every sandbox path in this port
  has only ever been executed by a test that assigned over `Host.flatpak?` —
  a user who installs the port as a Flatpak is running code no one has run.**
  Upstream ships `re.sonny.Junction.json` and
  `build-aux/flatpak/glib-appinfo.patch`; the port ships neither. The code those
  files would exercise is all present and all unexercised:
  `lib/junction_rb/host.rb:96` (`flatpak-spawn --host`),
  `lib/junction_rb/host.rb:116` and `:139` (the `/run/host` rewriting),
  `lib/junction_rb/host.rb:179` (`flatpak document-info`),
  `lib/junction_rb/resource.rb:63` (the document-portal proxy path),
  `lib/junction_rb/desktop_entry.rb:121`,
  `lib/junction_rb/background_request.rb` (the background/autostart portal)
  and `lib/junction_rb/application.rb:84`.
  Finishing it needs `flatpak-builder` and a Ruby/gem base-app story — the
  manifest has to build the gem and its native extensions inside the sandbox —
  and neither is available in this environment. Writing the manifest without
  building from it would produce a file that looks like the thing and has never
  been run, which is the failure mode this section exists to avoid.

- **`nix/Gemfile` lists two of the gemspec's four runtime dependencies, so the
  `bundlerEnv` runtime bundle is missing `gettext` and
  `gobject-introspection`.** `junction-rb.gemspec:121-124` declares four;
  `nix/Gemfile` lists `adwaita` and `gtk4`. The file carries a
  generated-by-`converge-port-gem.sh` marker, and changing it also needs
  `nix/Gemfile.lock` and `nix/gemset.nix` regenerated, which that generator
  does. Hand-editing one of the three would leave the lock and the gemset
  disagreeing with it, which is a worse state than the one it is in. This is
  for the generator, and it has not been run.

Upstream files with a port equivalent that is not a file of the same name:

- `meson.build` and `data/meson.build` — the install rules, the
  `i18n.merge_file` translation merge and the three build-time validations are
  `namespace :install` (`Rakefile:630-718`) and `namespace :validate`
  (`Rakefile:720-775`), installing under `XDG_DATA_HOME` because a gem has no
  `$datadir`.
- `po/re.sonny.Junction.pot` — committed, and generated by `rake gettext:pot`
  from every file `po/POTFILES` names.
- `.husky/pre-push` and `Makefile` — upstream's test entry points. The port's
  are `task :default` (`Rakefile:781`) and `.github/workflows/ci.yml`, which
  run the suite, the validations, both drive scripts and rubocop on every push.
- `src/importmap.json`, `src/meson.build`, `package.json`,
  `eslint.config.mjs` — gjspack's bundling and eslint's configuration. The
  port's equivalents are the gemspec and `.rubocop.yml` plus `cops/`. I am not
  porting these as files, and the reason is not that they have no analogue: it
  is that their analogues already exist and already run in CI.

## Open gaps

Re-derived from the tree each round, from the reports in `.reports/`, not
copied forward. The previous version of this section was written at `d128e68`
and still listed component-parity P0, P1, P2, P6, P7, P8 and test-parity Gap 1
as open when all seven had been closed two commits earlier — see
`.reports/accountability-ensurance.md` A2.

1. **P5** No Flatpak manifest, so none of the sandbox code paths has been
   exercised against a real sandbox. Above.
2. The two restored screenshot captions are extractable again, and one of them
   ("Choose the application to open the image with") came back with its 31
   existing translations attached. "Junction supports Linux mobile" is new to
   this catalogue — upstream added it after the last translation round, so it
   is untranslated in all 32 languages. I have not invented those translations
   either.
3. The eight msgids the donated catalogues predate (`Main Menu`,
   `Show App Names`, `Open Location`, `View File in File Manager`,
   `Run Junction in the background.`, `Light Style`, `Follow System Style`,
   `Dark Style`) are now in `po/re.sonny.Junction.pot` and in all 32
   `po/<lang>.po`, carried there by `rake gettext:merge`. `Show App Names`
   came across as fuzzy from the retired `Show names`; the other seven are
   untranslated. msgfmt excludes fuzzy entries, so seven of these eight still
   display in English in all 32 languages, and the eighth will too until a
   translator confirms it. I have not invented translations for them, and will
   not: the mechanism is fixed and the words are the translators'.
4. `nix/Gemfile` is out of step with the gemspec's runtime dependencies.
   Above.

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
