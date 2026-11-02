# Component parity — Junction-rb against `origin/main`

Verdict: **not clean.** One gap stops the application starting at all; eight
more are real behaviour or assets upstream has and the port does not.

## P0 — `JunctionRb::SETTINGS_PATH` does not exist

`lib/junction_rb/settings.rb:17`

```ruby
def settings = @settings ||= Gio::Settings.new(APPLICATION_ID, path: SETTINGS_PATH)
```

`SETTINGS_PATH` is defined nowhere in the repository —
`grep -rn SETTINGS_PATH lib exe test spec data PORTING.md` returns that one
line and nothing else. Commit 8b79115 added `APPLICATION_ID`, `DESKTOP_ID`,
`WEBSITE` and `JunctionRb.dev?` to `lib/junction_rb.rb` ("the constants every
other file already referenced and nothing defined") and missed this one.

Every path through the app reaches it:

- `Application#start_up` → `settings.apply_color_scheme` → `NameError`, so
  start-up aborts before any window is presented.
- `Application#register_actions` → `settings.create_action('color-scheme')`.
- `Window#register_actions` → `create_action('show-app-names')`.
- `TileButton#build` → `@settings.bind('show-app-names', …)`, i.e. every tile.
- `ThemeSwitcher#build` → `@settings.color_scheme`.

Upstream: `src/common.js` — `new Gio.Settings({schema_id: "re.sonny.Junction",
path: "/re/sonny/Junction/"})`.
Fix: define `SETTINGS_PATH = '/re/sonny/Junction/Rb/'` in `lib/junction_rb.rb`,
matching `path` in `data/schemas/re.sonny.Junction.Rb.gschema.xml`, and add a
test that constructs `Settings` and reads both keys.

## P1 — `exe/junction` launches the unwritten scaffold

`exe/junction:4-6` requires `junction` and runs `Junction::Application`, which
is `lib/junction/application.rb` — an `Adw.StatusPage` reading **"The Ruby port
has not been written yet."** `lib/junction.rb` and `lib/junction/application.rb`
are the original skeleton under a stale `Junction` module that nothing in
`lib/junction_rb.rb` requires.

The gemspec lists only `junction-rb` in `spec.executables`, but
`enumerate_package_files.call("exe")` puts `exe/junction` in `spec.files`, so
the file ships; and anyone running `exe/junction` from a checkout gets the
status page. Upstream's only entry points are `src/bin.js` (installed) and
`src/local.js` (checkout), both of which run the real application.
Fix: delete `exe/junction`, `lib/junction.rb` and `lib/junction/`.

## P2 — the welcome window's error path is unreachable

`lib/junction_rb/welcome_window.rb:103-109`

```ruby
def set_as_default_for_web
  SCHEMES.each { |type| Host.spawn_sync("gio mime #{type} #{DESKTOP_ID}") }
  true
rescue StandardError => e
  ...
  false
end
```

`GLib::Spawn.command_line_sync` returns `[stdout, stderr, status]`; it does not
raise when `gio mime` exits non-zero. So `set_as_default_for_web` returns
`true` whatever happened, and `install` always opens `<site>/success`.
Upstream `src/welcome.js:32-42` checks the result of each `spawn_sync` and
returns `false`, which is what routes the user to `<site>/error`.
Fix: inspect the exit status of both spawns, as `Host.real_path` already does.

## P3 — the debug report drops two lines upstream puts in it

`lib/junction_rb/about_dialog.rb:40-60` vs `src/about.js:19-39`.

- `datadir ${pkg.datadir}` has no counterpart. On a checkout this is the line
  that says where the icons and stylesheet were loaded from.
- `libadwaita ${getGIRepositoryVersion(Adw)}` is missing. The port reports
  Ruby, ruby-gnome, GTK and GLib but not libadwaita, which is the library most
  likely to differ between a bug report and the developer's machine.

## P4 — two of three screenshots, and their captions, are not ported

Upstream `data/re.sonny.Junction.metainfo.xml` ships three `<screenshot>`s:
`screenshot.png` ("Choose the browser to open the link with"),
`screenshot-file.png` ("Choose the application to open the image with") and
`screenshot-mobile.png` ("Junction supports Linux mobile"). The port ships one.
`data/screenshot-file.png` and `data/screenshot-mobile.png` have no port
counterpart, and the two captions are translatable msgids with 32 translations
each (see `.reports/translation-parity.md`).

## P5 — `data/icons/re.sonny.Junction.png` is not ported

Upstream ships a raster app icon beside the SVGs. The port ships
`.Rb.svg`, `.Rb.Devel.svg`, `.Rb-symbolic.svg` and `.Rb.Source.svg` but no PNG,
so any consumer that wants a raster (some docks, some software centres, the
Flatpak `--filesystem` icon cache) falls back to rendering or to nothing.

## P6 — the shortcuts dialog invents a section title

`lib/junction_rb/shortcuts_dialog.rb:24` titles the second section
`'Application'`. Upstream's `src/ShortcutsWindow.blp` gives both
`ShortcutsGroup`s no title. The string is also a bare literal with no `N_()`,
so it is user-visible and untranslatable. Either drop it, matching upstream, or
mark it and add it to `po/POTFILES` — but the first is parity.

## P7 — the theme switcher bypasses `app.color-scheme`

Upstream's `troll` `ThemeSelector` gives its three `Gtk.CheckButton`s
`action-name: "app.color-scheme"` with integer targets, so the stateful action
GSettings created is the single source of truth. The port
(`theme_switcher.rb:40-52`) connects `notify::active` and writes
`@settings.color_scheme` directly, with a `@syncing` flag to break the loop it
creates. `app.color-scheme` is still registered
(`application.rb:122`) with nothing targeting it. The visible behaviour is the
same today; the duplicated authority is the kind of thing that drifts.

## P8 — the desktop entry claims four MIME types upstream does not

`data/re.sonny.Junction.Rb.desktop` `MimeType=` adds `text/html`, `text/xml`
and `application/xhtml+xml` to upstream's three. Upstream claims those types
only imperatively, from `welcome.js`, when the user asks. Declaring them in the
desktop file means the port offers itself for every local HTML file the moment
it is installed, which upstream deliberately does not do (see its metainfo
release note "Do not automatically set as default application").

## Divergences that are parity, recorded so they are not re-litigated

Each is forced by the bindings and preserves the behaviour; `PORTING.md`
documents all of them.

- `Adwaita::Breakpoint#add_setter` cannot take a boolean, so the five portrait
  changes run from `apply`/`unapply`. Same condition, same five changes.
- `win.run-action` takes `as` (`[desktop id, action]`) instead of `a{ss}`;
  the location is read off the entry at activation time.
- `Adwaita::ShortcutsDialog` replaces the deprecated `Gtk.ShortcutsWindow`.
- `Gio::AppInfo`'s action API is unbound, so desktop actions are parsed from
  the key file — which upstream does anyway, for glib#2568.
- `GLib::Uri` is unbound, so the scheme is read off the URI text with a regex.
- `xdp_portal_request_background` takes a `GPtrArray`, so that one call goes
  through Fiddle (`background_request.rb`).
- `Adwaita::Application` is broken in the bindings, so the application is
  `Gtk::Application` with `Adwaita::ApplicationWindow` windows — the same shape
  the pilot port `gnome-contacts-rb` uses.
- Ids carry `.Rb` so the port installs beside the original; both Junctions are
  in `DesktopEntry::EXCLUDED`.
- `welcome.js` claims the five web types at module-import time, which fires on
  every launch including `open`; the port claims them in
  `WelcomeWindow#initialize`, so only on `activate`. Narrower, and better.
