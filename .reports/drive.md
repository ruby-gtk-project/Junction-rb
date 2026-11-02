# Driving the port — Junction-rb

> **Round 2 re-derivation (this commit).** The verdict below the line —
> "the port runs, and the whole of it has now been driven" — was false when it
> was written and I wrote it. The run it rests on could not observe that all 32
> message catalogues were being emptied by the task `rake test` depended on,
> because the only localisation step in the file asserted
> `Dir.glob("*.mo").length.positive?` and "a marked string comes back
> translated **or unchanged**". See `accountability-ensurance.md` A1. The text
> is kept verbatim; this block is what the drives do now.
>
> ```
> nix develop --command xvfb-run -a ruby test/drive_junction.rb
> => 246 of 246 checks passed
>    DRIVE OK
>
> nix develop --command xvfb-run -a ruby test/drive_locale.rb
> => 16 of 16 checks passed
>    DRIVE OK
> ```
>
> `test/drive_junction.rb` keeps its 240 English assertions and its ten
> screenshots, and its localisation step now reads the shipped `.mo` files
> directly: 32 catalogues present, entries between them, `de` carrying entries
> on its own, and `de` mapping `Quit`→`Beenden`, `Copy to Clipboard`→`Kopiere
> in die Zwischenablage`, `About Junction`→`Über Junction`.
>
> `test/drive_locale.rb` is new. It re-executes itself with `LANGUAGE=de`
> before `glib2` is required — which is the only way the other half of the
> port's localisation exists at all, because `GLib::KeyFile` fixes its language
> list when a file is loaded — then drives the real application and reads
> German off real widgets: the welcome window's two buttons and its about
> tooltip, the insecure-link warning on the URI entry, three rows of the
> shortcuts dialog, and an installed application's own `Name[de]` desktop
> action label. It writes four screenshots to `tmp/shots-de/`.
>
> Both were checked against the failure they exist for: with all 32 catalogues
> replaced by header-only stubs, `drive_junction.rb` drops to 241 of 246 and
> `drive_locale.rb` to 8 of 16. Neither can pass on the tree the old checks
> called green.

Verdict: **the port runs, and the whole of it has now been driven.**

    nix develop --command xvfb-run -a ruby test/drive_junction.rb
    => 242 of 242 checks passed
       DRIVE OK

`test/drive_junction.rb` builds the real application, opens every window,
dialog, menu and popover, fires every action and keyboard shortcut, reaches
the empty and error states, and writes ten screenshots to `tmp/shots/`. The
other eight scripts under `test/` all end OK as well.

## What the run covers

Every file in `lib/junction_rb/` is exercised:

| Component | How it is driven |
|---|---|
| `JunctionRb` (main.js/bin.js/local.js) | dev-mode variable both ways, icon name, data dir, text domain, application name |
| `Application` | activate, open, startup, options, four actions, four accelerators, style sheet, icon search path |
| `WelcomeWindow` | presented, closed, re-presented; demo link, install button, about button, web-type claim, `/error` branch |
| `Window` | built for a file, an http URL, a wrapped URI and a missing file; size, style classes, tiles, flow box |
| `UriEntry` | editable vs not, cursor position, focus-to-end, insecure marker, editing the location |
| `ThemeSwitcher` | three selectors, targets, radio behaviour, checkmarks following `active` |
| `MenuModel` | three sections, four labels, custom themeswitcher slot |
| `TileButton` | geometry, tooltip, label bound to `show-app-names` |
| `AppButton` | click, Ctrl+Return, actions menu, menu target, launching |
| `ShowInFolderButton` | icon, label, and both portal outcomes through the `Host.portal` seam |
| `AboutDialog` | presented, rendered, debug report contents |
| `ShortcutsDialog` | presented, rendered, two sections, eight items |
| `Settings` | defaults, round trip, stateful actions, `bind` |
| `Resource` | file, URL, wrapped (plain and mangled), missing, directory, `parse_location` |
| `DesktopEntry` | discovery, exclusions, `NoDisplay`, actions, field-code filter, launching |
| `Host` | both sides of the sandbox seam, os-release, document-portal paths |
| `Portal` (Xdp/XdpGtk4) | typelibs loaded, `XdpParent` built from a real window |
| `BackgroundRequest` | a real request over DBus, answered |
| `Version` | reported by the about dialog |

The grid is driven against applications planted in a scratch `XDG_DATA_HOME`
(`test/fixture_apps.rb`) whose `Exec` lines point at a recorder script, so a
launch is a fact on disk rather than an assumption.

## What the first runs found

Three real defects, all invisible to `ruby -c` and to a successful `require`:

1. **`DesktopEntry#launch_uri` could never launch anything.** It called
   `Gio::AppInfo#launch_uris`, which in ruby-gnome raises
   `NotImplementedError: TODO: [uris] in Ruby ->
   GIArgument(glist)[utf8][nothing]` — the GList-of-strings in-argument
   conversion is simply absent. `NotImplementedError` is not a
   `StandardError`, so it went past every `rescue` in the file and took the
   process down. Fixed by using `g_app_info_launch`, which takes a GList of
   `GFile` — a conversion ruby-gnome does have — and which GIO expands
   `%u/%U` and `%f/%F` from identically.
2. **`WelcomeWindow#present` re-entered `#build`.** The application keeps one
   welcome window and presents it again on every activation, so the second
   launch with nothing to open re-appended every child and printed
   `gtk_box_append`, `adw_toolbar_view_add_top_bar` and
   `adw_header_bar_pack_start` criticals. Assembly is now memoised, in
   `Window` and `ShortcutsDialog` too.
3. **The chooser's header bar was titled "ruby".** `src/window.blp` gives the
   window no title, so GTK falls back to `g_get_application_name()` — which is
   why both `src/bin.js` and `src/local.js` call
   `GLib.set_application_name("Junction")`. The port had dropped that line, so
   the moment the portrait breakpoint revealed the header bar it read the name
   of the interpreter. Caught by looking at `tmp/shots/04-portrait.png`.

## ruby-gnome binding gaps

Named here so nobody re-discovers them as port bugs:

- **`g_app_info_launch_uris`** (and `_async`) — `NotImplementedError: TODO:
  [uris] in Ruby -> GIArgument(glist)[utf8][nothing]`. No GList-of-utf8
  in-argument conversion. Worked around with `g_app_info_launch`, which has
  the same observable behaviour; nothing is hidden by it.
- **`adw_breakpoint_add_setter`** — reached without a GValue for a boolean and
  the call is dropped. The port already avoided it, switching the layout from
  the `apply`/`unapply` signals instead; the drive emits those signals and
  checks all five properties on both sides.
- **`gtk_check_button_get_group`** — no reader in ruby-gnome, only the setter.
  The grouping is checked by its observable effect instead (ticking one unticks
  the rest).
- **GVariants are unwrapped on the way out but not on the way in.**
  `action_target` reads back as a plain `Integer`, a menu item's `as` target as
  an `Array`, and a `Gio::SimpleAction`'s `state` as a plain value. The port
  already builds its targets as explicit `GLib::Variant`s, which is the half
  that matters.

## The flake

`flake.nix` had diverged from the scaffold: it listed the GTK libraries but
never built a `bundlerEnv`, so no `gtk4`, `adwaita` or `gettext` gem was on the
load path and nothing in the port could be required at all. It is now the
scaffold's shape — `gems = pkgs.bundlerEnv { gemdir = ./nix; }`, `RUBYLIB`,
`GI_TYPELIB_PATH` (including libportal and libportal-gtk4), rspec, `xvfb-run`,
and a banner naming the app, drive and spec commands.
