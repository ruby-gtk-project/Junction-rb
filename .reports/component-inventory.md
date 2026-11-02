# Junction — upstream component inventory

Upstream: `origin/main`, GJS (JavaScript) + blueprint (`.blp`), with the
`troll/` submodule (gitlink, not checked out) supplying the builder helper and
the `ThemeSelector` widget.

Port: the `ruby` branch, 21 files under `lib/`. This is not a skeleton — the
whole app is ported. What follows is the full component list with the state of
each, then the divergences and the gaps that are left.

Junction is a dispatcher: the desktop hands it a URI or a file, it puts up a
window of the applications that can handle it, launches the one picked, and
closes. Launched with nothing to open it shows a welcome window offering to
make itself the default handler for web links.

## Component map

Upstream splits each component across a `.blp` (tree, CSS classes, signals) and
a `.js` (callbacks, actions). Both halves join on one `lib/*.rb`.

| Upstream | Port file | Kind | Present |
|---|---|---|---|
| `src/application.js`, `src/main.js` | `lib/junction_rb/application.rb` | backend / actions / accelerators | yes |
| `src/window.blp` + `src/window.js` | `lib/junction_rb/window.rb` | window (the chooser) | yes |
| `src/window.blp` (`menu menu_model`) | `lib/junction_rb/menu_model.rb` | menu model | yes |
| `src/AppButton.blp` + `TileButton()` in `src/AppButton.js` | `lib/junction_rb/tile_button.rb` | widget (grid tile base) | yes |
| `src/AppButton.js` (`AppButton()`) | `lib/junction_rb/app_button.rb` | widget (application tile) | yes |
| `src/AppButton.js` (`ShowInFolderButton()`) | `lib/junction_rb/show_in_folder_button.rb` | widget (Open Location tile) | yes |
| `src/Entry.js` + `Entry entry` in `src/window.blp` | `lib/junction_rb/uri_entry.rb` | widget (URI bar) | yes |
| `troll/src/widgets/ThemeSelector.js` (+ its CSS) | `lib/junction_rb/theme_switcher.rb` | widget (menu custom slot) | yes |
| `src/welcome.blp` + `src/welcome.js` | `lib/junction_rb/welcome_window.rb` | window (welcome / empty state) | yes |
| `src/ShortcutsWindow.blp` + `src/ShortcutsWindow.js` | `lib/junction_rb/shortcuts_dialog.rb` | dialog (shortcuts) | yes |
| `src/about.js` | `lib/junction_rb/about_dialog.rb` | dialog (about + debug info) | yes |
| `src/common.js`, `data/re.sonny.Junction.gschema.xml` | `lib/junction_rb/settings.rb` | backend (GSettings) | yes |
| `src/util.js` (`readResource`, `parse`, x-junction) | `lib/junction_rb/resource.rb` | model (the thing being opened) | yes |
| `src/window.js` (`getApplications`), `src/util.js` (`openWith*`, `getKeyFile`) | `lib/junction_rb/desktop_entry.rb` | model (candidate application) | yes |
| `src/util.js` (`spawn*`, `getOSRelease`, `getFlatpakInfo`, flatpak paths) | `lib/junction_rb/host.rb` | backend (host / sandbox) | yes |
| `src/application.js` (`Xdp.Portal` background), `AppButton.js` (`open_directory`) | `lib/junction_rb/portal.rb`, `lib/junction_rb/background_request.rb` | backend (XDG portals) | yes |
| `src/bin.js`, `src/local.js` | `exe/`, `bin/` | entry point | yes |
| `src/style.css` | `data/style.css` | stylesheet | yes (plus the troll theme-switcher rules) |
| `data/re.sonny.Junction.gschema.xml` | `data/schemas/re.sonny.Junction.Rb.gschema.xml` | GSettings schema | yes |
| `data/re.sonny.Junction.desktop` | `data/re.sonny.Junction.Rb.desktop` | desktop entry | yes |
| `data/icons/*` | `data/icons/hicolor/**` | icons | yes (app + symbolic; no `.Devel`/`.Source` variants) |
| `data/re.sonny.Junction.metainfo.xml` | — | AppStream metadata | no |
| `data/re.sonny.Junction.service` | — | DBus activation service file | no |
| `po/` (on `origin/l10n`, not on `main`) | — | translation catalogue | no |
| `src/main.js` (`app.restart`, dev only) | `lib/junction_rb/application.rb` | action | yes |
| — (stale) | `lib/junction.rb`, `lib/junction/application.rb` | leftover skeleton | extra |

## Window — `src/window.blp` + `src/window.js` → `lib/junction_rb/window.rb`

The chooser: a grid of application tiles over an editable URI bar.

| Widget | × | CSS | Signals / actions | Present |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `main`, `devel` (dev only) | — | yes |
| `Adw.Breakpoint` | 1 | — | portrait `max-aspect-ratio: 1` | yes |
| `Adw.ToolbarView` | 1 | — | `reveal-top-bars` toggled by the breakpoint | yes |
| `Adw.HeaderBar` | 1 | — | — | yes |
| `Gtk.MenuButton` | 2 (top, bottom) | `circular`, `flat` | `menu_model`, `themeswitcher` custom child | yes |
| `Gtk.WindowHandle` | 1 | — | — | yes |
| `Gtk.ScrolledWindow` | 1 | — | — | yes |
| `Gtk.FlowBox` | 1 | `list` | 2–5 per line, homogeneous, single click | yes |
| `Gtk.FlowBoxChild` | repeater, one per candidate app | — | `focusable: false` | yes |
| `Gtk.Box` (bottom bar) | 1 | `bar` | — | yes |
| `Gtk.Entry` | 1 | `uri` | see UriEntry | yes |
| `Gtk.WindowControls` | 1 | — | `decoration-layout: "close"`, hidden in portrait | yes |
| `Gtk.EventControllerKey` | 1 | — | `key-pressed` / `key-released` → focus / activate tile 1…9 | yes |

Actions installed: `win.copy` (clipboard), `win.show-app-names` (from
GSettings), `win.run_action` (desktop action, `a{ss}` target).
Repeaters: one tile per recommended application, then one `Open Location` tile
when the resource is a local file that is neither a directory nor
`application/octet-stream`.

## Menu — `menu menu_model` in `src/window.blp` → `lib/junction_rb/menu_model.rb`

Three sections: the `themeswitcher` custom slot; `Show App Names` +
`Copy to Clipboard` (`win.`); `Keyboard Shortcuts` + `About Junction` (`app.`).
Six entries, one custom slot. Present.

## Tiles — `src/AppButton.blp` + `src/AppButton.js`

| Widget | × | CSS | Signals | Present |
|---|---:|---|---|---|
| `Gtk.Button` | 1 | `flat`, 134×134 | `clicked` → open and close | yes |
| `Gtk.Box` | 1 | — | — | yes |
| `Gtk.Image` | 1 | `icon-dropshadow` | 92px (48px on Open Location) | yes |
| `Gtk.Label` | 1 | — | `visible` bound to `show-app-names` | yes |
| `Gtk.PopoverMenu` | 1 | — | desktop actions, rebuilt per popup | yes |
| `Gtk.GestureClick` (`button: 0`) | 1 | — | right → actions menu, middle → open and stay, Ctrl+left → open and stay | yes |
| `Gtk.GestureLongPress` | 1 | — | actions menu | yes |
| `Gtk.EventControllerKey` | 1 | — | `Menu` → actions menu; Ctrl+Return/space → open and stay | yes |

## URI bar — `src/Entry.js` → `lib/junction_rb/uri_entry.rb`

Editable for URLs, read-only for files; caret at the start for a URL and the
end for a filename. `http` gets the `channel-insecure-symbolic` primary icon,
insensitive and non-activatable, with GNOME's own wording as the tooltip. An
`Gtk.EventControllerFocus` deselects and scrolls to the end on focus, deferred
one main-loop turn. Present.

## Welcome window — `src/welcome.blp` + `src/welcome.js`

| Widget | × | CSS | Signals | Present |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `welcome`, `devel` | `hide-on-close` | yes |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 | — | — | yes |
| `Gtk.Button` (about) | 1 | — | `action-name: app.about`, `help-about-symbolic` | yes |
| `Gtk.Box` `#content` | 1 | — | 68px padding from the stylesheet | yes |
| `Gtk.Image` | 1 | — | app icon, 128px | yes |
| `Gtk.LinkButton` | 1 | — | `Test Junction` → `/demo` | yes |
| `Gtk.Button` (install) | 1 | — | `clicked` → claim http/https, open `/success` or `/error` | yes |

## Shortcuts — `src/ShortcutsWindow.blp` → `lib/junction_rb/shortcuts_dialog.rb`

Two groups, eight shortcuts: discard and close, copy, select
next/previous, open, open and stay, position 1…9; then Keyboard Shortcuts and
Quit. Present, all eight.

## About — `src/about.js` → `lib/junction_rb/about_dialog.rb`

`Adw.AboutDialog` with the full credit list and the `Contributors` credit
section, plus the debug report (versions, flatpak, OS release, XDG variables).
Present; the version lines name Ruby and ruby-gnome instead of GJS.

## Application — `src/application.js` + `src/main.js`

Actions: `app.quit`, `app.about`, `app.shortcuts`, `app.color-scheme`
(GSettings), `app.restart` (dev only). Accelerators: `<Primary>Q`,
`<Primary>question`, `<Primary><Shift>Q`, `window.close` on `<Primary>W` and
`Escape`, `win.copy` on `<Primary>C`. `--terminate_after_init` main option,
option-context parameter string and description. `HANDLES_OPEN`, `hold()` so
the service survives with no windows, colour scheme applied from GSettings,
http/https claimed under Flatpak, background portal request on activate.
All present.

## Divergences the port makes on purpose

- `Adw.Breakpoint` setters cannot take a boolean through ruby-gnome, so the
  five portrait changes are made from `apply`/`unapply` handlers instead.
- `win.run_action` takes `as` (`[desktop id, action]`) rather than upstream's
  `a{ss}`: ruby-gnome cannot build the dictionary variant. The location is
  read off the entry at activation time instead of being carried in the target.
- `Gtk.ShortcutsWindow` is deprecated in GTK 4.18, so the shortcuts reference
  is an `Adwaita::ShortcutsDialog`; upstream's modal/transient handling goes
  away with it.
- `troll`'s `ThemeSelector` is reconstructed as `theme_switcher.rb` and its
  52 lines of CSS appended to `data/style.css`, since the submodule is a
  gitlink the port does not carry.
- Ids are suffixed `.Rb` (`re.sonny.Junction.Rb`) so the port can be installed
  beside upstream; the GSettings path is `/re/sonny/Junction/Rb/`.

## Gaps and blockers

- **`lib/junction.rb` and `lib/junction/application.rb` are dead.** They are the
  original skeleton — a blank Adwaita window with an `Adw.StatusPage` saying the
  port is unwritten — under a stale `Junction` module that nothing requires.
  Delete them; the live code is all under `JunctionRb`.
- **No translations.** Every upstream string goes through `_()` against the
  `re.sonny.Junction` gettext domain, and the catalogue (`po/`, 30-odd
  languages) lives on `origin/l10n`, not on `main`. The port has plain English
  literals and no gettext wiring, so nothing is translatable yet.
- **`data/re.sonny.Junction.metainfo.xml` is not ported.** AppStream metadata,
  needed by software centres and by the screenshots upstream ships.
- **`data/re.sonny.Junction.service` is not ported.** Without the DBus service
  file, DBus activation (`DBusActivatable=true` in the desktop entry) cannot
  start the app, which is how the desktop is meant to reach Junction.
- **Devel and Source icon variants** (`re.sonny.Junction.Devel.svg`,
  `re.sonny.Junction.Source.svg`) have no port counterpart, so the `devel` CSS
  class has no matching icon.
- **Flatpak manifest and `build-aux/flatpak/glib-appinfo.patch`** are out of
  scope for a gem-packaged port; the sandbox code paths in `host.rb` are
  therefore exercised only against a real Flatpak install.
