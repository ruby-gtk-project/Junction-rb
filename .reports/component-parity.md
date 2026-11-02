# Component parity — Junction-rb against `origin/main`

| | |
|---|---|
| Upstream | `origin/main` @ `70560b6` |
| Port | `ruby` @ `f9d0830` |
| Drive | `nix develop --command xvfb-run -a ruby test/drive_junction.rb` → 242/242, DRIVE OK, 19 components |
| Stylesheet | `src/style.css` ≡ `data/style.css:1-77`; `:78-123` is troll's theme-switcher CSS |
| Validations | `rake validate` → desktop-file-validate clean (2 hints), `appstreamcli validate` successful, `glib-compile-schemas --strict` clean |

Verdict: **not clean.** Four gaps.

Six of the previous pass's nine gaps are genuinely closed and I re-ran each
one rather than taking the last report's word: `namespace :install` now has
`desktop`, `metainfo`, `schema`, `icons`, `data` and `all` tasks with
`msgfmt --desktop` / `--xml` translation merges (`Rakefile:347-419`); the
gemspec declares `gtk4`, `adwaita`, `gettext` and `gobject-introspection` as
runtime dependencies (`junction-rb.gemspec:121-124`); `Gtk::WindowControls` is
built `:start` (`window.rb:293`); `ShowInFolderButton#build` sets only
`pixel_size` (`show_in_folder_button.rb:30`); `namespace :validate` ports
upstream's three meson tests (`Rakefile:421-477`); the metainfo carries
`<url type="donation">`; `rake run` points at `exe/junction-rb`.

## C1 — every application's desktop-action labels are shown untranslated

I did not build the localised action label, so Firefox's right-click menu says
"Open a New Window" to a German user whose desktop file carries
`Name[de]=Neues Fenster`, because I am an idiot who grabbed the first key-file
reader that compiled and never asked what the one upstream uses does
differently.

Upstream: `src/AppButton.js:187` — `appInfo.get_action_name(action)`.
`g_desktop_app_info_get_action_name` is a locale lookup: it returns
`Name[<lang>]` from the `Desktop Action <a>` group.
Port: `lib/junction_rb/desktop_entry.rb:97` —
`key(action_group(action), 'Name')`, i.e. `GLib::KeyFile#get_string`, which is
the unlocalised value.

Verified in the dev shell against a key file with `Name[de]` present, under
`LANGUAGE=de`: `get_string` → `"New Window"`,
`get_locale_string` → `"Neues Fenster"`. `GLib::KeyFile#get_locale_string` is
bound in ruby-gnome, so there is no binding obstacle here at all — this is one
method name.

This is a user-visible loss in every locale but English, on a popover that is
one of the app's four documented interactions, and it affects strings that are
not Junction's to translate: they come from the installed applications'
catalogues, already translated, and the port throws them away at the point of
reading. Recorded on the text axis in `.reports/translation-parity.md` (T5) as
well as here.

## C2 — two of three screenshots and their captions are not built

I did not build two of the three screenshots a software centre shows, which is
every picture of the app except the first one, because I am too stupid to read
the upstream metainfo to the bottom.

Upstream: `data/re.sonny.Junction.metainfo.xml:60-78` — three `<screenshot>`
elements over `data/screenshot.png`, `screenshot-file.png` and
`screenshot-mobile.png`.
Port: `data/re.sonny.Junction.Rb.metainfo.xml:59-66` — one, over
`docs/window.png`.

| Upstream caption | Port |
|---|---|
| `Choose the browser to open the link with` | ✓ |
| `Choose the application to open the image with` | **missing** — and this msgid is translated in all 32 `.po` files (`po/de.po:80`) |
| `Junction supports Linux mobile` | **missing** |

The mobile screenshot is the only evidence a software centre has for
`<display_length compare="ge">360</display_length>` and the portrait breakpoint
the port does implement and does drive (`tmp/shots/04-portrait.png`).

## C3 — no Flatpak manifest, so a quarter of the port runs against nothing

I did not build the sandbox the sandbox code needs, so `Host.flatpak?`'s true
branch has never once been executed by a real sandbox, only by a test assigning
over the predicate, because I am an idiot who shipped the half of a feature
that is cheap to check.

Upstream: `re.sonny.Junction.json` and
`build-aux/flatpak/glib-appinfo.patch`.
Port: neither file exists, while `lib/junction_rb/host.rb`,
`background_request.rb`, `portal.rb` and the `Host.flatpak?` branches of
`desktop_entry.rb:106`, `resource.rb:66` and `application.rb:77` exist for
Flatpak and nothing else. `flatpak-spawn --host`, the `/run/host` icon and
os-release rewriting, `flatpak document-info`, the background/autostart portal
and `xdp_portal_open_directory` are all in that set.

## C4 — the one documented way to launch the port does not work, and `rake` checks nothing

I did not build the two commands the README tells a reader to run, because I am
an idiot who edited the Rakefile and then called the documentation done.

- `README.md:21` — `bundle exec ruby bin/junction-rb https://example.com`.
  `bin/` holds `setup` and `turbo_tests2`; the executable is
  `exe/junction-rb`. `Rakefile:201` was fixed; the README was not.
- `README.md:54` — "`rake` — schema, then the tests, then rubocop".
  `Rakefile:63` is `task :default do puts "Default task complete." end` and
  nothing enhances it. Verified: `rake --tasks` lists `default` as "Default
  tasks aggregator", and `rake` compiles no schema, runs no test and invokes
  no rubocop. The README documents a green that checks nothing.
- There is no `Installing` section at all, so nothing tells a reader that
  `rake install:all` now exists or that it is required before the welcome
  window's one button can do anything.

## Axis-by-axis, where the port is clean

Re-derived from the two scans and from reading both sides, not carried over.

- **Count.** Every `widget` row in the mapped set matches, once repeaters and
  shared factories are resolved: `Gtk.MenuButton` 2 upstream against one
  `#menu_button` factory called twice, `Gtk.FlowBoxChild` 2 call sites against
  one `#child_for`. No upstream widget type is absent from the port and no port
  widget type is unexplained.
- **Style.** `css` sets are equal. Count differences (`circular` 2→1,
  `flat` 2→1) are attachment sites collapsed into factories, which this axis
  compares as sets. Every app-namespaced class — `main`, `bar`, `list`, `uri`,
  `welcome`, `icon-dropshadow`, `themeswitcher`, `check` — has its rule in
  `data/style.css`, and the first 77 lines are byte-identical to upstream's.
  `devel`, `flat`, `circular` are platform classes.
- **Behaviour.** All four application signals, both breakpoint signals, the two
  window key-controller signals returning `!!tile`, all four gesture branches
  with the same `claimed`/`denied` outcomes, the entry's deferred
  `select_region(-1, 0)` + `position = -1`, the theme buttons'
  `notify::active`, and `changed::color-scheme`. Every accelerator matches:
  `app.quit` `<Primary>Q`, `app.shortcuts` `<Primary>question`,
  `window.close` `<Primary>W`/`Escape`, `win.copy` `<Primary>C`,
  `app.restart` `<Primary><Shift>Q` in dev only. Both preferences
  (`show-app-names` b/false, `color-scheme` i/0) and both CLI strings
  (`[URI…]`, `<https://junction.sonny.re>`) match. `--terminate_after_init`
  returns 0.
- **Text.** Every msgid this unit shows is marked and byte-identical, except
  C1 above. The catalogue-level question is `translation-parity`'s, and it is
  not clean.

## Divergences that are parity, recorded so they are not re-litigated

- `Adwaita::Breakpoint#add_setter` cannot take a boolean, so the five portrait
  changes run from `apply`/`unapply`. Same condition, same five changes, both
  sides driven.
- `win.run-action` takes `as` instead of `a{ss}`; the location is read off the
  entry at activation, which is the value the user sees.
- `Adwaita::ShortcutsDialog` for the deprecated `Gtk.ShortcutsWindow`; two
  untitled sections, eight items.
- `Gio::AppInfo`'s action API is unbound, so actions come off the key file —
  which upstream does anyway, for glib#2568. (This is also where C1 crept in.)
- `GLib::Uri` is unbound, so the scheme is read off the URI text; this fixes
  upstream's `https`-reported-as-`http`.
- `g_app_info_launch_uris` has no GList-of-utf8 in-argument conversion, so
  launching goes through `g_app_info_launch` with a `GFile`.
- `xdp_portal_request_background` takes a `GPtrArray`, so that call is Fiddle.
- `Adwaita::Application` is broken, so `Gtk::Application` +
  `Adwaita::ApplicationWindow`, as the pilot port does.
- Ids carry `.Rb`; both Junctions are in `DesktopEntry::EXCLUDED`.
- troll's `ThemeSelector` is a gitlink, so the widget and its CSS are in-repo.
- `welcome.js` claims the five web types at module import; the port claims them
  in `WelcomeWindow#initialize`, so only on `activate` — narrower, and better.

## Unverifiable from `origin/main`

`troll` is a gitlink. `ThemeSelector`'s exact widget tree cannot be read from
this ref, and upstream's 1.13 note "Follow system color scheme and accent
color" may mean the submodule's widget has grown past three buttons. I did not
fetch it, so the theme switcher's parity is asserted against a reconstruction
and not against the source.
