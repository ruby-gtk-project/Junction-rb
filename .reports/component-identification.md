# Component identification — Junction (upstream `origin/main`) vs Junction-rb (`ruby`)

Upstream: GJS + blueprint, `src/*.blp` + `src/*.js`, with the `troll/`
submodule (a gitlink, never checked out) supplying `build()` and the
`ThemeSelector` widget. Scans: `.claude/skills/component-identification/scripts/component-scan.sh`
over a clean `git archive origin/main` export and over the working tree.

Upstream scan: 82 rows / 19 distinct widget types / 7 CSS classes / 9 signals /
15 action rows. Port scan: 98 rows. The counts are close because the port is
not a skeleton — the whole app is ported. What the counts do not show is where
the port diverges, so each unit is read below.

## Unit map

Upstream splits a component across a `.blp` (tree, CSS, signals) and a `.js`
(callbacks, actions); both halves join on one `lib/*.rb`.

| Upstream file(s) | Port file | Kind |
|---|---|---|
| `src/application.js`, `src/main.js`, `src/bin.js`, `src/local.js` | `lib/junction_rb/application.rb`, `lib/junction_rb.rb`, `exe/junction-rb` | application / actions / accelerators |
| `src/window.blp` + `src/window.js` | `lib/junction_rb/window.rb` | window (the chooser) |
| `menu menu_model` in `src/window.blp` | `lib/junction_rb/menu_model.rb` | menu model |
| `src/AppButton.blp` + `TileButton()` | `lib/junction_rb/tile_button.rb` | grid-tile base |
| `AppButton()` in `src/AppButton.js` | `lib/junction_rb/app_button.rb` | application tile |
| `ShowInFolderButton()` in `src/AppButton.js` | `lib/junction_rb/show_in_folder_button.rb` | "Open Location" tile |
| `src/Entry.js` + `Entry entry` in `src/window.blp` | `lib/junction_rb/uri_entry.rb` | URI bar |
| `troll/src/widgets/ThemeSelector.js` + its CSS | `lib/junction_rb/theme_switcher.rb`, tail of `data/style.css` | menu custom slot |
| `src/welcome.blp` + `src/welcome.js` | `lib/junction_rb/welcome_window.rb` | welcome window / empty state |
| `src/ShortcutsWindow.blp` + `src/ShortcutsWindow.js` | `lib/junction_rb/shortcuts_dialog.rb` | shortcuts dialog |
| `src/about.js` | `lib/junction_rb/about_dialog.rb` | about dialog + debug report |
| `src/common.js` + `data/*.gschema.xml` | `lib/junction_rb/settings.rb`, `data/schemas/re.sonny.Junction.Rb.gschema.xml` | GSettings |
| `src/util.js` (`readResource`, `parse`, x-junction) | `lib/junction_rb/resource.rb` | model: the thing being opened |
| `getApplications()`, `openWith*`, `getKeyFile`, `flatpakify` | `lib/junction_rb/desktop_entry.rb` | model: candidate application |
| `spawn*`, `getOSRelease`, `getFlatpakInfo`, `getIconFilename`, `getRealPath` | `lib/junction_rb/host.rb` | host / sandbox |
| `Xdp.Portal` use in `application.js`, `AppButton.js` | `lib/junction_rb/portal.rb`, `lib/junction_rb/background_request.rb` | XDG portals |
| `src/style.css` | `data/style.css` | stylesheet |
| `data/re.sonny.Junction.desktop` | `data/re.sonny.Junction.Rb.desktop` | desktop entry |
| `data/re.sonny.Junction.metainfo.xml` | `data/re.sonny.Junction.Rb.metainfo.xml` | AppStream |
| `data/re.sonny.Junction.service` | `data/re.sonny.Junction.Rb.service` | D-Bus activation |
| `data/icons/*` | `data/icons/**` | icons |
| `po/` (on `origin/l10n`) | `po/` | catalogue, 32 languages |
| — | `lib/junction.rb`, `lib/junction/application.rb`, `exe/junction` | **extra: dead scaffold, still wired to an installed executable** |

## Window — `src/window.blp` + `src/window.js` → `lib/junction_rb/window.rb`

| Widget | ×up | ×port | CSS | Signals / actions |
|---|---:|---:|---|---|
| `Adw.ApplicationWindow` | 1 | 1 | `main`, `devel` (dev) | 772×218, min 360×218 |
| `Adw.Breakpoint` | 1 | 1 | — | `max-aspect-ratio: 1`; port drives it from `apply`/`unapply` |
| `Adw.ToolbarView` | 1 | 1 | — | `reveal-top-bars` false, true in portrait |
| `Adw.HeaderBar` | 1 | 1 | — | — |
| `Gtk.MenuButton` | 2 | 2 | `circular`, `flat` | `open-menu-symbolic`, `primary`, tooltip `Main Menu`, `themeswitcher` custom child |
| `Gtk.WindowHandle` | 1 | 1 | — | — |
| `Gtk.ScrolledWindow` | 1 | 1 | — | `vexpand` |
| `Gtk.FlowBox` | 1 | 1 | `list` | 2–5 per line, homogeneous, 12px spacing, single click, no selection |
| `Gtk.FlowBoxChild` | repeater | repeater | — | `focusable: false` |
| `Gtk.Box` (bottom bar) | 1 | 1 | `bar` | spacing 12 |
| `Gtk.Entry` | 1 | 1 | `uri` | see URI bar |
| `Gtk.WindowControls` | 1 | 1 | — | `decoration-layout: "close"`, hidden in portrait |
| `Gtk.EventControllerKey` | 1 | 1 | — | `key-pressed` → focus tile 1…9, `key-released` → activate |

Actions: `win.copy`, `win.show-app-names` (from GSettings), and the desktop-action
runner — upstream `win.run_action` with an `a{ss}` target, port `win.run-action`
with an `as` target.
Repeaters: one tile per recommended application, then one `Open Location` tile
when the resource is a local file that is neither `inode/directory` nor
`application/octet-stream`.

## Menu — `menu menu_model` → `lib/junction_rb/menu_model.rb`

Three sections, one custom slot (`themeswitcher`) plus four labelled items:
`Show App Names`, `Copy to Clipboard` (`win.`), `Keyboard Shortcuts`,
`About Junction` (`app.`). Port matches, and builds a fresh model per button
because a widget can only live in one popover.

## Tiles — `src/AppButton.blp` + `src/AppButton.js` → `tile_button.rb`, `app_button.rb`, `show_in_folder_button.rb`

| Widget | × | CSS | Signals |
|---|---:|---|---|
| `Gtk.Button` | 1 | `flat`, 134×134 | `clicked` → open and close |
| `Gtk.Box` | 1 | — | vertical, centred |
| `Gtk.Image` | 1 | `icon-dropshadow` | 92px (48px on Open Location) |
| `Gtk.Label` | 1 | — | ellipsize end, 10 chars, `visible` bound to `show-app-names` |
| `Gtk.PopoverMenu` | 1 | — | desktop actions, rebuilt on each popup |
| `Gtk.GestureClick` (`button: 0`) | 1 | — | right → actions menu, middle → open-and-stay, Ctrl+left → open-and-stay |
| `Gtk.GestureLongPress` | 1 | — | actions menu |
| `Gtk.EventControllerKey` | 1 | — | `Menu` → actions menu; Ctrl+Return/space → open-and-stay |

## URI bar — `src/Entry.js` → `uri_entry.rb`

`Gtk.Entry` `.uri`, `input-purpose: url`, `xalign 0.5`, `hexpand`. Editable for
URLs, read-only for files; caret at position 0 for a URL and -1 for a filename.
`http` gets a non-sensitive, non-activatable `channel-insecure-symbolic`
primary icon with GNOME's own wording as the tooltip. A
`Gtk.EventControllerFocus` deselects and scrolls to the end on `enter`,
deferred one main-loop turn. Port matches on all five facets.

## Theme switcher — `troll/src/widgets/ThemeSelector.js` → `theme_switcher.rb`

`Gtk.Box.themeswitcher` (homogeneous, 18px) holding three
`Gtk.Overlay` → `Gtk.CheckButton` (`.light`, `.system`, `.dark`, one group) each
overlaid with a `Gtk.Image.check` (`object-select-symbolic`, 13px). The 46 CSS
lines are reconstructed at the tail of `data/style.css`. `system` is hidden
when `Adw.StyleManager` reports no system preference.
**Divergence:** upstream's three check buttons target the stateful
`app.color-scheme` action; the port connects `notify::active` and writes
GSettings directly, so the action exists with nothing targeting it.

## Welcome window — `src/welcome.blp` + `src/welcome.js` → `welcome_window.rb`

| Widget | × | CSS | Signals |
|---|---:|---|---|
| `Adw.ApplicationWindow` | 1 | `welcome`, `devel` | title `Junction`, `hide-on-close` |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 | — | — |
| `Gtk.Button` (about) | 1 | — | `action-name: app.about`, `help-about-symbolic`, tooltip |
| `Gtk.Box` `#content` | 1 | — | 68px padding from the stylesheet, spacing 14 |
| `Gtk.Image` | 1 | — | app icon, 128px |
| `Gtk.LinkButton` | 1 | — | `Test Junction` → `<site>/demo` |
| `Gtk.Button` (install) | 1 | — | `clicked` → claim http/https, then open `/success` or `/error` |

## Shortcuts — `src/ShortcutsWindow.blp` → `shortcuts_dialog.rb`

Upstream: `Gtk.ShortcutsWindow` (`modal: false`, transient for the active
window) → 1 `ShortcutsSection` → 2 `ShortcutsGroup` → 8 `ShortcutsShortcut`.
Port: `Adwaita::ShortcutsDialog` → 2 `ShortcutsSection` → 8 `ShortcutsItem`
(GTK deprecated `ShortcutsWindow` in 4.18). All eight accelerators and titles
are present. **Divergence:** the port titles the second section `Application`;
upstream's groups are untitled, so this is a new user-visible string.

## About — `src/about.js` → `about_dialog.rb`

`Adw.AboutDialog` with the full credit list, the `Contributors` credit section,
and the debug report. Port's report drops `datadir` and the libadwaita version
line, and names Ruby / ruby-gnome in place of GJS.

## Application — `src/application.js` + `src/main.js` → `application.rb`

Actions `app.quit`, `app.about`, `app.shortcuts`, `app.color-scheme`,
`app.restart` (dev only). Accelerators `<Primary>Q`, `<Primary>question`,
`<Primary><Shift>Q`, `window.close` on `<Primary>W` and `Escape`, `win.copy` on
`<Primary>C`. `HANDLES_OPEN`, `hold()`, `--terminate_after_init`,
option-context parameter string and description, colour scheme from GSettings,
http/https claimed under Flatpak, background portal request on activate.
All present.

## Under-reports the scan cannot see, resolved by reading

- **Repeaters.** One `AppButton` per recommended application, plus a
  conditional `ShowInFolderButton`. One scan row, N components.
- **Shared factory.** `Window#menu_button` is one method called from two
  memoized accessors — two `Gtk.MenuButton`s, one textual occurrence (the scan
  shows `Gtk.MenuButton 1` for the port against `2` upstream; the port is
  correct).
- **Dynamic CSS.** `devel` is added at runtime on both windows; the theme
  switcher's `.light`/`.system`/`.dark` come from `add_css_class(name.to_s)`.
- **Submodule.** `troll`'s `ThemeSelector` produces no upstream rows at all, so
  the port's faithful copy reads as an unexplained extra. It is not.
- **Action names from a table.** `Application::ACCELERATORS` and the GSettings
  `create_action` calls put no literal in the `action` stream.
