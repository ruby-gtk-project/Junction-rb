# Component identification — Junction-rb vs `origin/main`

Inventory of every window, dialog, widget, CSS class, signal, action,
accelerator, preference, empty state and error state on both sides. Upstream is
GJS + Blueprint (`src/*.js`, `src/*.blp`) on `origin/main`; the port is
`lib/junction_rb/*.rb` on `ruby`.

Facets recorded per component: **type**, **CSS classes**, **signals**,
**actions**, **owner**.

## Top-level surfaces

| Surface | Upstream owner | Port owner | Type |
|---|---|---|---|
| Chooser window | `src/window.js` + `window.blp` | `lib/junction_rb/window.rb` | `Adw.ApplicationWindow` / `Adwaita::ApplicationWindow` |
| Welcome window | `src/welcome.js` + `welcome.blp` | `lib/junction_rb/welcome_window.rb` | `Adw.ApplicationWindow` |
| About dialog | `src/about.js` | `lib/junction_rb/about_dialog.rb` | `Adw.AboutDialog` |
| Shortcuts reference | `src/ShortcutsWindow.js` + `.blp` | `lib/junction_rb/shortcuts_dialog.rb` | `Gtk.ShortcutsWindow` → `Adwaita::ShortcutsDialog` |
| Main menu (×2 buttons) | `window.blp` `menu menu_model` | `lib/junction_rb/menu_model.rb` | `Gio.Menu` |
| Theme switcher | `troll/src/widgets/ThemeSelector.js` (submodule) | `lib/junction_rb/theme_switcher.rb` | `Gtk.Box` of 3 `Gtk.CheckButton` |
| Application tile | `src/AppButton.js` + `AppButton.blp` | `lib/junction_rb/app_button.rb` + `tile_button.rb` | `Gtk.Button` |
| "Open Location" tile | `ShowInFolderButton` in `AppButton.js` | `lib/junction_rb/show_in_folder_button.rb` | `Gtk.Button` |
| URI bar | `src/Entry.js` | `lib/junction_rb/uri_entry.rb` | `Gtk.Entry` |
| Desktop-action popover | `popupActionsMenu` in `AppButton.js` | `AppButton#popup_actions_menu` | `Gtk.PopoverMenu` |

## Chooser window tree

| Node | Upstream (`window.blp`) | Port (`window.rb`) |
|---|---|---|
| window | `styles ["main"]`, 772×218, min 360×218 | `add_css_class('main')`, same sizes ✓ |
| window (dev) | `__DEV__` → `devel` class | `JunctionRb.dev?` → `devel` ✓ |
| breakpoint | `max-aspect-ratio: 1`, 5 setters | `Adwaita::BreakpointCondition.parse`, `apply`/`unapply` → same 5 ✓ |
| `toolbar_view` | `Adw.ToolbarView`, `reveal-top-bars: false` | ✓ |
| `header_bar` | `Adw.HeaderBar` [top], start `button_menu_top` | ✓ |
| `button_menu_top` / `_bottom` | `MenuButton`, `open-menu-symbolic`, tooltip `Main Menu`, `valign: center`, `primary: true`, `styles ["circular","flat"]` | ✓ both, each with its own model and `ThemeSwitcher` in the `themeswitcher` slot ✓ |
| content | `WindowHandle > ScrolledWindow(vexpand) > FlowBox list` | ✓ |
| `list` | `styles ["list"]`, max 5 / min 2 per line, homogeneous, 12/12 spacing, `selection-mode: none`, `activate-on-single-click: true`, halign/valign center | ✓ all nine |
| flow-box child | `Gtk.FlowBoxChild { focusable: false }` | ✓ |
| bottom bar | `Box`, spacing 12, `styles ["bar"]` | ✓ |
| `entry` | `hexpand`, `input-purpose: url`, `xalign: 0.5`, `styles ["uri"]` | ✓ |
| `window_controls_bottom` | `WindowControls`, `decoration-layout: "close"`, **side defaults to start** | `Gtk::WindowControls.new(:end)` — **differs**, see component-parity P2 |

## Signals and controllers

| Component | Upstream | Port |
|---|---|---|
| window | `Gtk.EventControllerKey` → `key-pressed` focus nth tile, `key-released` activate nth tile, both return `!!button` | ✓ `key_controller`, returns `!tile.nil?` |
| tile | `clicked` → open+close | ✓ `TileButton#build` |
| tile | `Gtk.GestureClick{button: 0}` → `pressed`: secondary = actions menu, middle = open and stay, primary = open, Ctrl held = stay; else `DENIED` | ✓ `AppButton#handle_press`, same four branches, same `claimed`/`denied` |
| tile | `Gtk.GestureLongPress` → actions menu, `CLAIMED` | ✓ |
| tile | `Gtk.EventControllerKey` → `key-released`: `Menu` = actions menu; Ctrl+`Return`/`space` = open and stay | ✓ `AppButton#handle_key` |
| entry | `Gtk.EventControllerFocus` → `enter`, deferred `select_region(-1,0)` + `position = -1` via timeout | ✓ `UriEntry#scroll_to_end` |
| welcome install button | `clicked => $onInstall()` | ✓ |
| theme buttons | `notify::active` → check icon visible | ✓ |
| settings | `changed::color-scheme` → `StyleManager.set_color_scheme` | ✓ `Settings#on_color_scheme_change` |
| app | `startup`, `open`, `activate`, `handle-local-options` | ✓ all four |

## Actions, accelerators, preferences

| Action | Upstream | Port |
|---|---|---|
| `app.quit` | `<Primary>Q` | ✓ |
| `app.about` | no accel | ✓ |
| `app.shortcuts` | `<Primary>question` | ✓ |
| `app.color-scheme` | `settings.create_action` | ✓ |
| `app.restart` | `__DEV__` only, `<Primary><Shift>Q` | ✓ `JunctionRb.dev?` |
| `window.close` | `<Primary>W`, `Escape` | ✓ |
| `win.copy` | `<Primary>C` | ✓ |
| `win.show-app-names` | `settings.create_action` | ✓ |
| `win.run_action` | `a{ss}` target | `win.run-action`, `as` target — renamed on both sides consistently |
| CLI `--terminate_after_init` | `handle-local-options` → 0 | ✓ |
| CLI parameter string / description | `[URI…]`, `<https://junction.sonny.re>` | ✓ |
| GSettings `show-app-names` (b, false) | ✓ | ✓ |
| GSettings `color-scheme` (i, 0) | ✓ | ✓ |

## Empty and error states

| State | Upstream | Port |
|---|---|---|
| no application handles the type | empty `FlowBox`, no placeholder | ✓ same (empty grid) |
| content type unknowable | `logError`, fall back to `application/octet-stream` | ✓ `Resource#query_content_type` rescue |
| insecure (`http`) resource | primary entry icon `channel-insecure-symbolic`, insensitive, non-activatable, tooltip | ✓ `UriEntry#mark_insecure` |
| launch failed | `console.error("Could not launch …")`, window stays open | ✓ `warn`, window stays |
| key file unreadable | `console.error`, return `null` | ✓ `DesktopEntry#load_key_file` rescue |
| actions menu empty | no popup | ✓ `if menu.n_items.positive?` |
| "Open Location" refused by portal | window stays open | ✓ `ShowInFolderButton#open_containing_folder` |
| default-handler registration failed | opens `<site>/error` | ✓ `WelcomeWindow#claim` checks exit status |
| icon is neither themed nor a file | no image set (blank tile) | port adds `application-x-executable-symbolic` (addition) |

## Components upstream has that the port has no counterpart for

- `data/screenshot.png`, `data/screenshot-file.png`, `data/screenshot-mobile.png`
  and two of the three `<screenshot>` entries that reference them.
- `re.sonny.Junction.json` (Flatpak manifest) and
  `build-aux/flatpak/glib-appinfo.patch`.
- `data/meson.build` / `meson.build`: the install rules for the desktop file,
  metainfo, schema and icons, the `i18n.merge_file` translation merge, and the
  three validation tests (`desktop-file-validate`, `appstreamcli validate`,
  `glib-compile-schemas --strict`).
- `<url type="donation">`, `<update_contact>` in the metainfo.

## Components the port adds

`lib/junction_rb/host.rb` (sandbox predicate + portal wrappers),
`lib/junction_rb/portal.rb` (GI loader for Xdp/XdpGtk4),
`lib/junction_rb/background_request.rb` (Fiddle call for the GPtrArray
argument), `lib/junction_rb/theme_switcher.rb` (an in-repo copy of troll's
widget, including its CSS, appended to `data/style.css`),
`lib/junction_rb/tile_button.rb` (the shared tile shape upstream expresses as
one `.blp` used twice). All five are mechanism, not new UI.
