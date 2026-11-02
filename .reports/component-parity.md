# Component parity — Junction-rb against `origin/main`

Verdict: **not clean.**

The nine gaps the previous pass found in the application code are closed:
`SETTINGS_PATH` exists, `exe/junction` and `lib/junction/` are gone, the
welcome window's `/error` path is reachable, the debug report carries `datadir`
and `libadwaita`, the shortcuts dialog no longer invents a section title, the
theme switcher now targets `app.color-scheme` with `i` variants and writes
nothing itself, the desktop file claims upstream's three MIME types and no
more, and the raster icon is present.

What remains is almost entirely **the half of upstream that is not in `src/`**:
the port reproduces the widget tree faithfully and then has no way to install
itself, so the application cannot do the one thing it exists for — be the thing
the desktop hands a link to.

## P0 — nothing installs the desktop file, the metainfo, the schema or the icons

Upstream `data/meson.build` installs five things and validates three of them:

| Upstream install | Port |
|---|---|
| `re.sonny.Junction.desktop` → `$datadir/applications` (via `i18n.merge_file`) | **nothing** |
| `re.sonny.Junction.metainfo.xml` → `$datadir/metainfo` (via `i18n.merge_file`) | **nothing** |
| `re.sonny.Junction.gschema.xml` → `$datadir/glib-2.0/schemas` | **nothing** |
| `icons/re.sonny.Junction.svg` → `hicolor/scalable/apps` | **nothing** |
| `icons/re.sonny.Junction-symbolic.svg` → `hicolor/symbolic/apps` | **nothing** |
| `re.sonny.Junction.service` → `$datadir/dbus-1/services` | ✓ `rake install:service` |

`Rakefile:282` — `namespace :install` contains exactly one task, `:service`.
`gem install junction-rb` therefore puts `exe/junction-rb` on `$PATH` and
nothing else anywhere:

- No `.desktop` in `applications/`, so `x-scheme-handler/https` can never be
  pointed at Junction-rb. `WelcomeWindow#claim_web_types` runs
  `gio mime x-scheme-handler/http re.sonny.Junction.Rb.desktop` against a
  desktop id that does not exist, so the welcome window's one button is a
  no-op on an installed copy.
- No compiled schema in any XDG data dir, so `Gio::Settings.new` aborts the
  process (`GLib-GIO-ERROR **: Settings schema 're.sonny.Junction.Rb' is not
  installed`). `data/schemas/gschemas.compiled` is found only because
  `rake run` and `rake test` export `GSETTINGS_SCHEMA_DIR`
  (`Rakefile:174-178`). Run `junction-rb` any other way and start-up dies in
  `Application#start_up`.
- No icons in `hicolor`, so `JunctionRb.icon_name` resolves to nothing outside
  a checkout (`Application#load_icons` adds `data/icons`, which is inside the
  gem, so this one survives — but the dock and the shell do not see it).
- No metainfo, so no software-centre entry at all.

Fix: an `install:data` task (or `install:all`) that copies the desktop file,
the metainfo, the schema and the two icons into
`$XDG_DATA_HOME/{applications,metainfo,glib-2.0/schemas,icons/hicolor/...}`,
runs `glib-compile-schemas` and `update-desktop-database` on the target, and
merges the translations (see translation-parity P1). Upstream's
`gnome.post_install(glib_compile_schemas: true, gtk_update_icon_cache: true,
update_desktop_database: true)` is the list.

## P1 — the gem declares no runtime dependencies

`junction-rb.gemspec` has 20+ `add_development_dependency` calls and **not one
`add_dependency`**. `gtk4`, `adwaita`, `gettext` and `gobject-introspection`
appear only in `Gemfile:62-69`, which an installed gem never reads.

```
$ gem install junction-rb && junction-rb
lib/junction_rb.rb:3:in 'require': cannot load such file -- gtk4 (LoadError)
```

Upstream's equivalent — `meson.build` + `re.sonny.Junction.json` — pins gjs,
gtk4, libadwaita and libportal explicitly. Fix: add
`spec.add_dependency("gtk4", "~> 4.3")`, `adwaita`, `gettext`,
`gobject-introspection`.

## P2 — the bottom bar's close button does not render

`lib/junction_rb/window.rb:270`

```ruby
Gtk::WindowControls.new(:end).tap { |c| c.decoration_layout = 'close' }
```

Upstream `src/window.blp:446` declares `WindowControls window_controls_bottom
{ decoration-layout: "close"; }` and never sets `side`, so it keeps the default
`GTK_PACK_START`. `GtkWindowControls` splits `decoration-layout` on `":"` and a
`side` of `start` renders the tokens before the colon while `end` renders the
tokens after it. `"close"` has no colon, so the end group is empty: with
`side = :end` the widget has nothing to show.

Consequence: in landscape — the default, and the only orientation where the
bottom bar carries the window controls — there is no close button at all. The
window is still dismissible with `Escape`/`Ctrl+W`, which is why this is easy
to miss, but the control upstream puts in the bar is gone.

Fix: `Gtk::WindowControls.new(:start)`, or keep `:end` and set the layout to
`':close'`.

## P3 — `rake run` points at a file that does not exist

`Rakefile:201-208` runs `ruby bin/junction-rb`. `bin/` contains `setup` and
`turbo_tests2`; the executable is `exe/junction-rb`. The documented way to
launch the port from a checkout fails with `No such file or directory`.

## P4 — two of three screenshots, and their captions, are still missing

Upstream ships three `<screenshot>` elements and the three PNGs behind them.
The port ships one, pointing at `docs/window.png`.

| Upstream | Caption | Port |
|---|---|---|
| `data/screenshot.png` | "Choose the browser to open the link with" | ✓ (`docs/window.png`) |
| `data/screenshot-file.png` | "Choose the application to open the image with" | **missing** — and this msgid has 32 translations in `po/` |
| `data/screenshot-mobile.png` | "Junction supports Linux mobile" | **missing** |

The mobile screenshot is the one that evidences `<display_length compare="ge">360`
and the portrait breakpoint the port does implement.

## P5 — no Flatpak manifest, so no sandbox exists to run the sandbox code in

Upstream ships `re.sonny.Junction.json` and
`build-aux/flatpak/glib-appinfo.patch`. The port ships neither, while
`lib/junction_rb/host.rb`, `background_request.rb`, `portal.rb` and the
`Host.flatpak?` branches of `desktop_entry.rb`, `resource.rb` and
`application.rb` exist only for Flatpak. Every one of those paths —
`flatpak-spawn --host`, `/run/host` icon rewriting, `flatpak document-info`,
the background/autostart portal, `xdp_portal_open_directory` — is therefore
unexercised by anything, test or human.

## P6 — upstream's three build-time validations are not ported

`data/meson.build` registers `desktop-file-validate`, `appstreamcli validate
--no-net --explain` and `glib-compile-schemas --strict --dry-run` as *tests*.
The port's `rake schema` runs `glib-compile-schemas` without `--strict`, and
nothing validates the desktop file or the metainfo. The port's metainfo is the
one of the three files that has been rewritten most (new ids, new releases, new
urls), so it is the one most likely to be invalid.

## P7 — `<url type="donation">` dropped

Upstream carries `<url type="donation">https://junction.sonny.re/donate</url>`.
The port carries homepage, bugtracker and vcs-browser only. Junction is
donation-funded; dropping the link is a user-visible loss in every software
centre. (`<update_contact>junction@sonny.re</update_contact>` is also dropped,
which is correct — bug mail for the port should not go to upstream.)

## P8 — "Open Location" shrinks its tile

`show_in_folder_button.rb:28-30` sets `image.width_request` and
`image.height_request` to 48 as well as `pixel_size`. Upstream's
`TileButton({icon_size: 48})` calls only `image.set_pixel_size(48)`
(`AppButton.js:629-631`), leaving the 92×92 requests the `.blp` sets, so the
folder tile occupies the same box as every application tile and its icon is
centred in it. In the port the box collapses to 48 and the tile's contents sit
higher than its neighbours'.

## Divergences that are parity, recorded so they are not re-litigated

Each is forced by the bindings or by installing beside the original, preserves
the behaviour, and is documented in `PORTING.md`.

- `Adwaita::Breakpoint#add_setter` cannot take a boolean, so the five portrait
  changes run from `apply`/`unapply`. Same condition, same five changes.
- `win.run-action` takes `as` (`[desktop id, action]`) instead of `a{ss}`; the
  location is read off the entry at activation time.
- `Adwaita::ShortcutsDialog` replaces the deprecated `Gtk.ShortcutsWindow`;
  both sections stay untitled, as upstream's do.
- `Gio::AppInfo`'s action API is unbound, so desktop actions are parsed from
  the key file — which upstream does anyway, for glib#2568.
- `GLib::Uri` is unbound, so the scheme is read off the URI text with a regex
  (and this is *why* the port gets `https` right where `g_file_get_uri_scheme`
  reports `http`).
- `xdp_portal_request_background` takes a `GPtrArray`, so that one call goes
  through Fiddle (`background_request.rb`).
- `Adwaita::Application` is broken in the bindings, so the application is
  `Gtk::Application` with `Adwaita::ApplicationWindow` windows — the shape the
  pilot port `gnome-contacts-rb` uses (`lib/main.rb:202-211`).
- Ids carry `.Rb` so the port installs beside the original; both Junctions are
  in `DesktopEntry::EXCLUDED`.
- troll's `ThemeSelector` is a submodule upstream, so the widget and its CSS
  are reproduced in `theme_switcher.rb` and appended to `data/style.css`. The
  rest of `data/style.css` is byte-identical to `src/style.css`.
- `welcome.js` claims the five web types at module-import time, which fires on
  every launch including `open`; the port claims them in
  `WelcomeWindow#initialize`, so only on `activate`. Narrower, and better.

## Unverifiable from `origin/main`

The `troll` submodule is a gitlink, so `ThemeSelector`'s exact widget tree
cannot be read from this ref. Upstream's 1.13 release note "Follow system color
scheme and accent color" suggests the widget may now do more than the port's
three-button copy; it cannot be confirmed or denied here.
