# Component identification — Junction-rb vs `origin/main`

> **Round 4 re-derivation (this commit, `86c1f6c`).** `origin/main` has not
> moved (`70560b6`, same sha round 3 recorded) and `troll` is still pinned to
> the same commit, so there is nothing new to scan on the upstream side.
> Re-ran `component-scan.sh` on the port's `lib/` anyway, since four commits
> landed since round 3 (`c057f09` parity reports, `3faff07` screenshots,
> `c81d6b5` theme-switcher + gem fix, `26f7272` drive-script window closing,
> `86c1f6c` the commit under audit). Only `c81d6b5` touched a file the unit
> list covers: `lib/junction_rb/theme_switcher.rb` gained one
> `signal_connect('notify::system-supports-color-schemes')`. That is a
> `controller`/signal-axis row, not a new widget, and it does not change the
> unit list or the file mapping below — carried to `component-parity.md`
> round 4, where it closes C6.
>
> One thing this round found that is not a scan result: `86c1f6c` added
> `.reports/component-inventory.md`, a second, independent component
> inventory of the same app, built without this skill's four-facet method —
> it lists widget *types* per file and nothing else; no CSS classes, no
> signals, no actions, no counts. It also never names the `ThemeSelector`
> submodule problem this file's round 1 spent a paragraph on, and asserts
> "No missing components found" from a method (grep for file existence) that
> cannot see a missing CSS class or an unconnected signal — exactly the
> failure mode this skill's own "Rules" section warns against ("Never list a
> widget type without its CSS classes and signals"). It does not contradict
> any row below, because it checks less than this file does, but a reader who
> opens it instead of this one walks away with a weaker claim dressed as a
> clean inventory. Logged here and in `.reports/accountability-ensurance.md`
> round 4, not fixed here — this document's job is the identification, not
> cleaning up a sibling report.
>
> Verdict for this round: the unit list, file mapping and scan counts below
> are unchanged and still current. Nothing re-derived this round moved any
> row.

> **Round 3 re-derivation (this commit, `3faff07`).** Re-ran the scan on both
> sides from scratch rather than trusting the round-2 counts. Two things
> changed how this round could read upstream: `origin/main` HEAD moved to
> `70560b6` (same as round 2 — no upstream drift), and the `troll` gitlink
> (pinned `37b53b291`) was cloned into a scratch directory at that exact
> commit and merged into the scan tree, which neither round 1 nor round 2
> did — both recorded the submodule as unreadable. `gjspack`'s own demo and
> test fixtures under `troll/` were scanned incidentally; they are troll's
> tooling, not anything Junction imports, and are excluded from the counts
> below by hand after reading what `src/window.js`/`AppButton.js`/etc.
> actually `import` from the submodule (only `src/main.js`, confirming the
> builder helper, and `src/widgets/ThemeSelector.js`, confirming the one real
> widget).
>
> Rebuilt symbol table from the current `nix develop` shell: 1209 symbols
> (GTK4 4.22, libadwaita, no Vte/GtkSource/Shumate/WebKit/Panel typelibs
> installed, matching this app's actual dependency set).
>
> | | Upstream (`src/` + `troll/src/widgets/ThemeSelector.*`) | Port (`lib/`) |
> |---|---|---|
> | Scan rows | 70 (plus 76 troll-tooling rows excluded as not imported) | 94 |
> | Files with rows | 10 | 19 |
>
> Nothing in the re-scan changes the unit list below: every upstream template
> root and every named top-level object still maps one-to-one to a `lib`
> file, including `ThemeSelector`, whose actual upstream source is now
> readable rather than assumed. See `.reports/component-parity.md` C6 for
> what reading it changed.

| | |
|---|---|
| Upstream | `origin/main` @ `70560b6` ("Follow the system style (#220)") |
| Port | `ruby` @ `f9d0830` |
| Scan | `component-identification/scripts/component-scan.sh`, symbol table from the port's `nix develop` shell |
| Rows | upstream 81, port 94 |

Upstream is GJS + Blueprint (`src/*.js` beside `src/*.blp`), so every component
is split across two files and the rows are unioned per unit before anything is
compared. The port has no `.blp`/`.ui` at all — checked, not assumed
(`find lib data -name '*.ui' -o -name '*.blp'` is empty) — and builds every
widget as a memoized method, so its side is scan-plus-reading only.

## Unit list and file mapping

| Unit | Upstream files | Port file |
|---|---|---|
| application | `src/application.js`, `src/main.js`, `src/bin.js`, `src/local.js`, `src/common.js` | `lib/junction_rb/application.rb`, `lib/junction_rb.rb`, `lib/junction_rb/settings.rb`, `exe/junction-rb` |
| chooser window | `src/window.js` + `src/window.blp` | `lib/junction_rb/window.rb` |
| main menu (standalone `menu` object, no backing source) | `src/window.blp` `menu menu_model` | `lib/junction_rb/menu_model.rb` |
| theme switcher | `troll/src/widgets/ThemeSelector.js` (gitlink — unreadable from this ref) | `lib/junction_rb/theme_switcher.rb` + `data/style.css:78-123` |
| application tile | `src/AppButton.js` + `src/AppButton.blp` | `lib/junction_rb/tile_button.rb`, `lib/junction_rb/app_button.rb` |
| "Open Location" tile | `ShowInFolderButton` in `src/AppButton.js` | `lib/junction_rb/show_in_folder_button.rb` |
| URI bar | `src/Entry.js` (widget declared in `src/window.blp`) | `lib/junction_rb/uri_entry.rb` |
| welcome window | `src/welcome.js` + `src/welcome.blp` | `lib/junction_rb/welcome_window.rb` |
| about dialog | `src/about.js` | `lib/junction_rb/about_dialog.rb` |
| shortcuts reference | `src/ShortcutsWindow.js` + `src/ShortcutsWindow.blp` | `lib/junction_rb/shortcuts_dialog.rb` |
| resource / launching / sandbox | `src/util.js` | `lib/junction_rb/resource.rb`, `desktop_entry.rb`, `host.rb`, `portal.rb`, `background_request.rb` |
| data files | `data/*.desktop`, `*.metainfo.xml`, `*.gschema.xml`, `icons/`, `*.service`, `data/meson.build`, `meson.build` | `data/*`, `Rakefile:331-477` |

`src/importmap.json`, `src/meson.build`, `package.json`, `eslint.config.mjs`,
`.husky/*`, `Makefile`, `troll/` are GJS/npm plumbing with no widget in them.

## Chooser window (`src/window.blp` ∪ `src/window.js` → `window.rb`)

| Widget | Up × | Port × | CSS | Signals / actions |
|---|---:|---:|---|---|
| `Adw.ApplicationWindow` | 1 | 1 | `main`, `devel` (dev only) | — |
| `Adw.Breakpoint` (`type`) | 1 | 1 | — | port: `apply`/`unapply`; upstream: 5 `setters` |
| `Adw.ToolbarView` | 1 | 1 | — | `reveal-top-bars: false` |
| `Adw.HeaderBar` | 1 | 1 | — | — |
| `Gtk.MenuButton` | 2 | 1 call site, 2 instances (`top_menu_button`, `bottom_menu_button`) | `circular`, `flat` | tooltip `Main Menu`, `primary`, own `MenuModel` + `ThemeSwitcher` in the `themeswitcher` slot |
| `Gtk.WindowHandle` | 1 | 1 | — | — |
| `Gtk.ScrolledWindow` | 1 | 1 | — | `vexpand` |
| `Gtk.FlowBox` | 1 | 1 | `list` | 5/2 per line, homogeneous, 12/12, `selection-mode: none`, `activate-on-single-click` |
| `Gtk.FlowBoxChild` | 2 call sites | 1 call site (`child_for`), N instances | — | `focusable: false` |
| `Gtk.Box` (bottom bar) | 1 | 1 | `bar` | spacing 12 |
| `Gtk.Entry` | 1 | 1 (in `uri_entry.rb`) | `uri` | `hexpand`, `input-purpose: url`, `xalign 0.5` |
| `Gtk.WindowControls` | 1 | 1 | — | `decoration-layout: "close"`, side `start` on both |
| `Gtk.EventControllerKey` (`controller`) | 1 | 1 | — | `key-pressed` → focus nth tile, `key-released` → activate nth tile, both return `!!tile` |

Actions installed on the window: `win.copy`, `win.show-app-names` (from
`Settings#create_action`), and the desktop-action runner — `win.run_action`
with an `a{ss}` target upstream, `win.run-action` with an `as` target in the
port. Repeaters: the tile grid, one `FlowBoxChild` per candidate application
plus "Open Location" when `Resource#show_in_folder?`.

## Application tile (`src/AppButton.blp` ∪ `src/AppButton.js` → `tile_button.rb` + `app_button.rb`)

| Widget | Up × | Port × | CSS | Signals |
|---|---:|---:|---|---|
| `Gtk.Button` | 1 | 1 | `flat` | `clicked` → open and close |
| `Gtk.Box` | 1 | 1 | — | — |
| `Gtk.Image` | 1 | 1 | `icon-dropshadow` | pixel size 92, 92×92 requests (48 pixel size only on the folder tile) |
| `Gtk.Label` | 1 | 1 | — | `visible` bound to `show-app-names`, GET-only on both sides |
| `Gtk.PopoverMenu` | 1 | 1 | — | populated per popup |
| `Gtk.GestureClick` (`controller`) | 1 | 1 | — | `pressed`: secondary → actions menu, middle → open and stay, primary → open (Ctrl = stay), else `DENIED` |
| `Gtk.GestureLongPress` (`controller`) | 1 | 1 | — | `pressed` → actions menu, `CLAIMED` |
| `Gtk.EventControllerKey` (`controller`) | 1 | 1 | — | `key-released`: `Menu` → actions menu; Ctrl+`Return`/`space` → open and stay |

The popover's items target `win.run_action` / `win.run-action` and are filtered
to actions whose `Exec` carries `%U`, `%u`, `%f` or `%F` on both sides.

**The action label is where the two sides stop matching.** Upstream reads it
with `appInfo.get_action_name(action)` (`src/AppButton.js:187`), which GIO
implements as a *locale* key-file lookup. The port reads
`key_file.get_string("Desktop Action <a>", "Name")`
(`lib/junction_rb/desktop_entry.rb:97`), which is the C-locale value. Verified
in the dev shell against a key file carrying `Name[de]`: `get_string` →
`"New Window"`, `get_locale_string` → `"Neues Fenster"`.

## Welcome window, about dialog, shortcuts reference

| Component | Up | Port |
|---|---|---|
| `Adw.ApplicationWindow` | `title: "Junction"`, `hide-on-close`, `welcome` + `devel` | ✓ |
| `Adw.ToolbarView` / `Adw.HeaderBar` | 1 / 1 | ✓ |
| `Gtk.Button` ×2 | about (`app.about`, `help-about-symbolic`, tooltip) and install (`clicked => $onInstall()`) | ✓ |
| `Gtk.Image`, `Gtk.LinkButton` | icon 128px; `Test Junction` → `/demo` | ✓ |
| `Gtk.Box` `name: "content"` | vertical, 14, centred, expanding | ✓ |
| `Adw.AboutDialog` | 1, with `add_credit_section("Contributors", …)` and a 20-line debug report | ✓ (`Ruby`/`ruby-gnome` lines replace `GJS`) |
| `Gtk.ShortcutsWindow` / `ShortcutsSection` / `ShortcutsGroup` ×2 / `ShortcutsShortcut` ×8 | 1/1/2/8 | `Adwaita::ShortcutsDialog` 1, `Adwaita::ShortcutsSection` ×2, `Adwaita::ShortcutsItem` ×8, all untitled |

## Theme switcher

Upstream's is in the `troll` submodule, which is a gitlink on this ref, so it
produces no upstream rows and cannot be read from `origin/main`. The port's
copy: `Gtk.Box` `themeswitcher` (homogeneous, spacing 18) holding three
`Gtk.Overlay`s, each a `Gtk.CheckButton` (`light` / `system` / `dark`, grouped,
`action-name: app.color-scheme`, explicit `i` targets 1/0/4) overlaid with a
`Gtk.Image` `object-select-symbolic` carrying `check`, `visible` following
`notify::active`. Its 46 lines of CSS are appended to `data/style.css`; the
first 77 lines of that file are byte-identical to `src/style.css`.

Upstream's 1.13 release note "Follow system color scheme and accent color"
suggests the submodule's widget may now do more than three buttons. I could
not confirm or deny it from this ref, and I did not fetch the submodule.

## Empty and error states

| State | Upstream | Port |
|---|---|---|
| nothing handles the type | empty `FlowBox`, no placeholder | ✓ |
| content type unknowable | `logError`, fall back to `application/octet-stream` | ✓ `Resource#query_content_type` |
| insecure `http` | primary icon `channel-insecure-symbolic`, insensitive, non-activatable, GNOME's tooltip | ✓ `UriEntry#mark_insecure` |
| launch failed | `console.error`, window stays | ✓ `warn`, window stays |
| key file unreadable | `console.error`, `null` | ✓ |
| actions menu empty | no popup | ✓ `if menu.n_items.positive?` |
| portal refuses "Open Location" | window stays | ✓ |
| handler registration failed | opens `<site>/error` | ✓ `WelcomeWindow#install` reads the exit status |
| icon neither themed nor a file | nothing set (blank tile) | port sets `application-x-executable-symbolic`, and sets any other `GIcon` with `set_from_gicon` — two additions |

## Upstream components with no counterpart in the port

- `data/screenshot-file.png`, `data/screenshot-mobile.png` and the two
  `<screenshot>` elements that reference them.
- `re.sonny.Junction.json` (Flatpak manifest) and
  `build-aux/flatpak/glib-appinfo.patch`.
- `troll/` as a readable component source.

## Components the port adds

`host.rb` (the sandbox seam plus the portal wrappers), `portal.rb` (the GI
loader for `Xdp`/`XdpGtk4`), `background_request.rb` (one Fiddle call for the
`GPtrArray` argument), `tile_button.rb` (the shared tile shape upstream
expresses as one `.blp` instantiated twice), `theme_switcher.rb` (the
submodule's widget reproduced in-repo). All five are mechanism; none is new UI.
