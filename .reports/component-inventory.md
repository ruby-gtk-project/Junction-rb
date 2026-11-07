# Component inventory — Junction (GJS) → Junction-rb (Ruby GTK4/Libadwaita)

Surveyed against `origin/main` (upstream GJS/Blueprint app, commit tree as
fetched) and the `ruby` branch's `lib/`. Junction is a small dispatcher app —
one application object, one main window, one welcome window, two dialogs, a
handful of composite widgets. Scope here is the whole app (it is small enough
that a per-unit split would be artificial), ordered the way a user meets the
pieces: application → welcome window → main window → its widgets → menu →
dialogs → settings/plumbing.

Legend for **kind**: `app` (application class), `window`, `dialog`, `widget`
(composite widget used in a tree), `menu`, `settings/plumbing` (non-widget
support code), `data` (schema/desktop/metainfo/resources), `shortcuts`.

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/application.js` | `lib/junction_rb/application.rb` | app | ✅ |
| `src/bin.js`, `src/local.js`, `src/main.js` | `lib/junction_rb.rb` (module-level constants, `dev?`, gettext bootstrap) | app bootstrap | ✅ |
| `src/welcome.js` + `src/welcome.blp` | `lib/junction_rb/welcome_window.rb` | window | ✅ |
| `src/window.js` + `src/window.blp` | `lib/junction_rb/window.rb` | window | ✅ |
| `src/Entry.js` (entry widget behaviour in `window.blp`) | `lib/junction_rb/uri_entry.rb` | widget | ✅ |
| `src/AppButton.js` (`TileButton`) + `src/AppButton.blp` | `lib/junction_rb/tile_button.rb` | widget | ✅ |
| `src/AppButton.js` (`AppButton` / default export) | `lib/junction_rb/app_button.rb` (subclasses `TileButton`) | widget | ✅ |
| `src/AppButton.js` (`ShowInFolderButton`) | `lib/junction_rb/show_in_folder_button.rb` (subclasses `TileButton`) | widget | ✅ |
| `window.blp`'s `menu menu_model` + the `ThemeSelector` custom slot (`troll/src/widgets/ThemeSelector.js`) | `lib/junction_rb/menu_model.rb` + `lib/junction_rb/theme_switcher.rb` | menu / widget | ✅ |
| `src/about.js` | `lib/junction_rb/about_dialog.rb` | dialog | ✅ |
| `src/ShortcutsWindow.js` + `src/ShortcutsWindow.blp` | `lib/junction_rb/shortcuts_dialog.rb` (ported onto `Adw::ShortcutsDialog`, replacing the deprecated `Gtk::ShortcutsWindow`) | dialog / shortcuts | ✅ |
| `src/common.js` (`settings` singleton) + `data/re.sonny.Junction.gschema.xml` | `lib/junction_rb/settings.rb` + `data/schemas/re.sonny.Junction.Rb.gschema.xml` | settings/plumbing + data | ✅ |
| `src/util.js` (`parse`, resource helpers) | `lib/junction_rb/resource.rb` | settings/plumbing | ✅ |
| `src/util.js` (`getIconFilename`, `getKeyFile`, desktop-action handling) | `lib/junction_rb/desktop_entry.rb` | settings/plumbing | ✅ |
| `src/util.js` (`spawn`, `spawn_sync`, `prefixCommandLineForHost`, `getOSRelease`, `getFlatpakInfo`) | `lib/junction_rb/host.rb` | settings/plumbing | ✅ |
| `Xdp.Portal` usage in `application.js`/`AppButton.js`/`util.js` (request_background, open_directory, running_under_flatpak) + libportal/XdpGtk4 bindings | `lib/junction_rb/portal.rb` + `lib/junction_rb/background_request.rb` | settings/plumbing | ✅ |
| `data/re.sonny.Junction.desktop` | `data/re.sonny.Junction.Rb.desktop` | data | ✅ present (content not diffed this pass) |
| `data/re.sonny.Junction.metainfo.xml` | `data/re.sonny.Junction.Rb.metainfo.xml` | data | ✅ present (content not diffed this pass) |
| `data/re.sonny.Junction.service` | `data/re.sonny.Junction.Rb.service` | data | ✅ present (content not diffed this pass) |
| `data/icons/*` | `data/icons/re.sonny.Junction.Rb.png`, `.Source.svg` | data | ✅ present (icon set reduced to the two files actually used, not diffed this pass) |
| `src/style.css` | `data/style.css` | data | ✅ present (content not diffed this pass) |
| `po/` catalogue (32 languages) | `po/*.po` + `locale/*/LC_MESSAGES/re.sonny.Junction.mo` | data | ✅ (compiled `.mo` present under `locale/`, confirmed bound via `JunctionRb::TEXT_DOMAIN`/`LOCALE_DIR`) |
| `troll/src/main.js` (`build()` blueprint-loader helper) | n/a — no Ruby equivalent needed; the house style builds widgets as memoized accessors instead of loading `.blp` at runtime | infra | ✅ (by design, not a gap) |
| `troll/src/widgets/ThemeSelector.js` | `lib/junction_rb/theme_switcher.rb` | widget | ✅ (listed above) |
| `troll/src/util.js` (version helpers used by `about.js`'s debug info) | inlined into `lib/junction_rb/about_dialog.rb#debug_info` | settings/plumbing | ✅ |

## Summary

Every upstream user-facing component (application, welcome window, main
window, URI entry, app tile / show-in-folder tile, main menu + theme switcher,
about dialog, shortcuts dialog) and every piece of upstream plumbing (settings,
resource parsing, desktop-entry/actions, host/sandbox helpers, background and
open-directory portal calls) already has a corresponding file under `lib/` on
`ruby`, each carrying a comment naming the upstream file(s) it was ported from,
matching the house pattern from `gnome-contacts-rb`.

All packaging/metadata files under `data/` (desktop entry, metainfo, D-Bus
service, icons, stylesheet, GSettings schema) exist on `ruby` under their
`.Rb`-suffixed names. Their byte-for-byte content against upstream was not
diffed this pass (out of scope for "do not write app code in this step") — a
follow-up `component-parity`/`translation-parity` pass should confirm field
parity (metainfo release notes, desktop actions, schema defaults) rather than
presence alone.

**No missing components found.** This inventory did not surface a `lib/*.rb`
file that needs to be created; the port appears to already be at full
component parity for the widget tree. A next step should be a
`component-parity` pass (widget-by-widget: types, CSS classes, signals,
actions) on the existing files rather than scaffolding new ones, plus a
`translation-parity` check on the 32 `po/` catalogues and a `test-parity`
check against upstream's `test/util.test.js`.
