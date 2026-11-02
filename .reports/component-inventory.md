# Upstream component inventory — Junction

Survey for the full-parity port. Upstream is GJS + Blueprint on `origin/main`
(`src/*.js`, `src/*.blp`, `data/*`); the port is `lib/junction_rb/*.rb` on
`ruby`. Every user-facing component upstream builds is listed with the file(s)
it is made of, the `lib/*.rb` file it maps to, its kind, and whether the port
already has it.

Upstream splits several components across two files — the `.blp` holds the
widget tree, the CSS classes and the signal names, the `.js` beside it holds the
callbacks and everything built at runtime. The rows below union both halves,
because that pair is one component and one port file.

## Summary

| | Count |
|---|---:|
| Components identified | 22 |
| Already present in `lib/` or `data/` | 22 |
| Missing | 0 |
| Blockers | 0 (3 recorded deviations, all deliberate) |

## Components, in the order a user meets them

| # | Upstream file(s) | Port file | Kind | Present |
|---:|---|---|---|---|
| 1 | `src/main.js`, `src/bin.js`, `src/local.js` | `lib/junction_rb.rb` | app bootstrap / constants / gettext | yes |
| 2 | `src/application.js` | `lib/junction_rb/application.rb` | application class, actions, accelerators | yes |
| 3 | `src/window.js` + `src/window.blp` | `lib/junction_rb/window.rb` | main window (chooser) | yes |
| 4 | `src/window.blp` — `Adw.Breakpoint` | `Window#portrait_breakpoint` in `window.rb` | adaptive breakpoint (portrait) | yes |
| 5 | `src/window.blp` — `menu menu_model` | `lib/junction_rb/menu_model.rb` | menu model (3 sections, 4 items + custom slot) | yes |
| 6 | `troll/src/widgets/ThemeSelector.js` (submodule) | `lib/junction_rb/theme_switcher.rb` | menu popover widget in the `themeswitcher` custom slot | yes |
| 7 | `src/AppButton.blp` + `TileButton` in `src/AppButton.js` | `lib/junction_rb/tile_button.rb` | reusable grid tile (base) | yes |
| 8 | `AppButton` default export in `src/AppButton.js` | `lib/junction_rb/app_button.rb` | application tile (repeater, one per candidate app) | yes |
| 9 | `popupActionsMenu` in `src/AppButton.js` | `AppButton#popup_actions_menu` in `app_button.rb` | context popover of desktop actions | yes |
| 10 | `ShowInFolderButton` in `src/AppButton.js` | `lib/junction_rb/show_in_folder_button.rb` | "Open Location" tile (conditional) | yes |
| 11 | `src/Entry.js` (+ `entry` in `window.blp`) | `lib/junction_rb/uri_entry.rb` | URI bar, incl. insecure-http icon + tooltip | yes |
| 12 | `src/welcome.js` + `src/welcome.blp` | `lib/junction_rb/welcome_window.rb` | welcome window / empty state | yes |
| 13 | `src/about.js` | `lib/junction_rb/about_dialog.rb` | about dialog + debug report | yes |
| 14 | `src/ShortcutsWindow.js` + `src/ShortcutsWindow.blp` | `lib/junction_rb/shortcuts_dialog.rb` | keyboard-shortcuts reference (2 groups, 8 entries) | yes |
| 15 | `src/style.css` | `data/style.css` (loaded by `application.rb`) | stylesheet | yes |
| 16 | `data/re.sonny.Junction.gschema.xml` + `src/common.js` | `lib/junction_rb/settings.rb`, `data/schemas/re.sonny.Junction.Rb.gschema.xml` | preferences (`show-app-names`, `color-scheme`) | yes |
| 17 | `src/util.js` — `readResource`, `parse`, x-junction unwrap | `lib/junction_rb/resource.rb` | resource model (what is being opened) | yes |
| 18 | `src/util.js` — key file, `openWithApplication`, `openWithAction`, `flatpakify`; `getApplications` in `window.js` | `lib/junction_rb/desktop_entry.rb` | candidate app model + launching + exclusion list | yes |
| 19 | `src/util.js` — `spawn_sync`, `getOSRelease`, `getFlatpakInfo`, `getIconFilename`, `getRealPath`; portal use in `application.js`/`AppButton.js` | `lib/junction_rb/host.rb`, `lib/junction_rb/portal.rb`, `lib/junction_rb/background_request.rb` | host / Flatpak / portal layer | yes |
| 20 | `src/main.js` dev block | `Application#register_restart_action` | development-only restart action | yes |

| 21 | `data/re.sonny.Junction.desktop`, `.metainfo.xml`, `.service`, `data/icons/*` | `data/re.sonny.Junction.Rb.*`, `data/icons/**` | install surface: launcher entry, MIME claims, AppStream, D-Bus activation, icons | yes |
| 22 | `src/junction` (launcher wrapper widening `XDG_DATA_DIRS`/`GI_TYPELIB_PATH`) | `exe/junction-rb` + the `makeWrapper` block in `flake.nix` | launcher wrapper | yes |

Not components: `src/meson.build`, `data/meson.build`, `meson.build`,
`eslint.config.mjs`, `package.json`, `.husky/*`, `test/util.test.js`,
`re.sonny.Junction.json`, `build-aux/flatpak/glib-appinfo.patch`,
`src/importmap.json`, `notes.md` — build, lint and packaging plumbing, which the
port replaces with its own (`Rakefile`, `nix/`, `flake.nix`,
`junction-rb.gemspec`).

## Chooser window — widget tree

`src/window.blp` + `src/window.js` → `lib/junction_rb/window.rb`

| Widget | × | CSS | Signals / actions | Present |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `main`, `devel` (dev build) | — | yes |
| `Adw.Breakpoint` | 1 | — | 5 setters (`list.halign/valign`, both bottom widgets' `visible`, `reveal-top-bars`) | yes |
| `Adw.ToolbarView` | 1 | — | `reveal-top-bars: false` | yes |
| `Adw.HeaderBar` | 1 | — | start child = top menu button | yes |
| `Gtk.MenuButton` | 2 | `circular`, `flat` | `menu-model`, `primary: true`, tooltip `Main Menu` | yes |
| `Gtk.WindowHandle` | 1 | — | — | yes |
| `Gtk.ScrolledWindow` | 1 | — | `vexpand` | yes |
| `Gtk.FlowBox` | 1 | `list` | max 5 / min 2 per line, homogeneous, 12/12 spacing, `selection-mode: none`, `activate-on-single-click` | yes |
| `Gtk.FlowBoxChild` | N (repeater) | — | `focusable: false` | yes |
| `Gtk.Box` (bottom bar) | 1 | `bar` | spacing 12 | yes |
| `Gtk.Entry` | 1 | `uri` | `input-purpose: url`, `xalign: 0.5`, `hexpand` | yes |
| `Gtk.WindowControls` | 1 | — | `decoration-layout: "close"` | yes |
| `Gtk.EventControllerKey` | 1 (controller) | — | `key-pressed` / `key-released` → focus/activate tile 1…9 | yes |

Repeaters: one `Gtk.FlowBoxChild` + `AppButton` per recommended application.
Conditional: the "Open Location" tile, only when the scheme is `file` and the
content type is neither `inode/directory` nor `application/octet-stream`.

Window actions: `win.copy`, `win.show-app-names` (stateful, from GSettings),
`win.run_action` (port: `win.run-action`).

## Application tile

`src/AppButton.blp` + `src/AppButton.js` → `tile_button.rb` + `app_button.rb`

| Widget | × | CSS | Signals | Present |
|---|---:|---|---|---|
| `Gtk.Button` | 1 | `flat` | `clicked` → open, 134×134 | yes |
| `Gtk.Box` | 1 | — | vertical, centered | yes |
| `Gtk.Image` | 1 | `icon-dropshadow` | pixel size 92 (48 for "Open Location") | yes |
| `Gtk.Label` | 1 | — | ellipsize end, max 10 chars, bound to `show-app-names` | yes |
| `Gtk.PopoverMenu` | 1 | — | populated per popup from the app's desktop actions | yes |
| `Gtk.GestureClick` | 1 (controller) | — | `pressed`: secondary → actions menu, middle → open and stay, primary → open (Ctrl = stay) | yes |
| `Gtk.GestureLongPress` | 1 (controller) | — | `pressed` → actions menu | yes |
| `Gtk.EventControllerKey` | 1 (controller) | — | `key-released`: `Menu` → actions menu; Ctrl+Return/space → open and stay | yes |

## Welcome window

`src/welcome.blp` + `src/welcome.js` → `lib/junction_rb/welcome_window.rb`

| Widget | × | CSS | Signals | Present |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `welcome`, `devel` (dev) | title `Junction`, `hide-on-close` | yes |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | yes |
| `Gtk.Button` (about) | 1 | — | `action-name: app.about`, `help-about-symbolic` | yes |
| `Gtk.Box` | 1 | `#content` (named, padded by CSS) | vertical, spacing 14, centered | yes |
| `Gtk.Image` | 1 | — | app icon, pixel size 128 | yes |
| `Gtk.LinkButton` | 1 | — | `Test Junction` → `/demo` | yes |
| `Gtk.Button` (install) | 1 | — | `clicked` → claim http/https, then open `/success` or `/error` | yes |

Error state: the install button routes to `/error` when `gio mime` fails — the
port reads the exit status to reach the same page.

## Dialogs and menus

- **About** (`src/about.js` → `about_dialog.rb`): `Adw.AboutDialog`, debug
  report (versions, `XDG_DATA_DIRS`, `PATH`, `FLATPAK_ID`,
  `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, os-release, flatpak version),
  developers / designers / artists, `translator-credits`, extra "Contributors"
  credit section. Present.
- **Shortcuts** (`src/ShortcutsWindow.blp` → `shortcuts_dialog.rb`): two
  untitled groups, eight shortcut entries, msgids unchanged. Present.
- **Main menu** (`window.blp` → `menu_model.rb`): section 1 = `custom:
  "themeswitcher"`; section 2 = `Show App Names` (`win.show-app-names`), `Copy
  to Clipboard` (`win.copy`); section 3 = `Keyboard Shortcuts`
  (`app.shortcuts`), `About Junction` (`app.about`). Present.
- **Desktop-action popover** (`popupActionsMenu`): one item per `Desktop Action`
  whose `Exec` contains `%U`/`%u`/`%f`/`%F`; pops up only when non-empty.
  Present.

## Actions and accelerators

| Action | Owner | Accelerator | Present |
|---|---|---|---|
| `app.quit` | `application.js` | `<Primary>Q` | yes |
| `app.about` | `application.js` | — | yes |
| `app.shortcuts` | `application.js` | `<Primary>question` | yes |
| `app.color-scheme` (stateful) | `application.js` + GSettings | — | yes |
| `app.restart` (dev only) | `main.js` | `<Primary><Shift>Q` | yes |
| `window.close` | built in | `<Primary>W`, `Escape` | yes |
| `win.copy` | `window.js` | `<Primary>C` | yes |
| `win.show-app-names` (stateful) | `window.js` + GSettings | — | yes |
| `win.run_action` | `window.js` | — | yes (as `win.run-action`) |
| main option `terminate_after_init` | `application.js` | — | yes |

## Translations

`origin/main` ships no `po/` directory — the catalogues live on `origin/l10n`.
The port carries 32 catalogues in `po/`, compiled into `locale/`, bound to
upstream's `re.sonny.Junction` domain so the donated translations keep working.
No component on either side is missing a msgid.

## Deviations, recorded not blocking

1. **`win.run_action` → `win.run-action`, and an `as` target instead of
   `a{ss}`.** ruby-gnome cannot marshal the `a{ss}` dictionary, so the target is
   `[desktop id, action name]` and the location is read from the entry at
   activation.
2. **`Gtk.ShortcutsWindow` → `Adwaita::ShortcutsDialog`.** GTK deprecated the
   former in 4.18; the eight entries and their msgids are unchanged.
3. **Theme switcher CSS lives in `data/style.css`.** Upstream gets it from the
   `troll` submodule, which is not checked out here, so the port's stylesheet
   carries the `.themeswitcher` rules (45 extra lines) that upstream's
   `src/style.css` does not.

## Blockers

None. Every user-facing component upstream builds has a counterpart in `lib/`,
and the remaining work is verification rather than porting.
