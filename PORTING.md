# Porting Junction from GJS to Ruby

The original is JavaScript on GJS, with the interface in Blueprint files
compiled into a GResource. This port is Ruby with the interface built in code,
in the house declarative style: every widget is a memoized method, configuration
lives in `tap` blocks, and `build` reads as the widget tree.

Everything the original does, this does. What follows is only where the two
differ, and why.

## libportal is gone

The original depends on libportal (`Xdp`) for three things. None of them
survived, and nothing was lost but the dependency in two of the three cases:

| Original | Here |
|---|---|
| `Xdp.Portal.running_under_flatpak()` | `File.exist?('/.flatpak-info')` — which is what that function does |
| `portal.open_directory(...)` for "Open Location" | `Gtk::FileLauncher#open_containing_folder`, native since GTK 4.10 and portal-backed inside a sandbox |
| `portal.request_background(..., AUTOSTART)` | **not ported** |

The third one is a real gap. The original asks the background portal, on every
activation, for permission to keep running and to autostart — so that a
Flatpak-installed Junction is ready the first time a link is clicked rather than
paying start-up costs then. There is no `Xdp` GObject-Introspection typelib
available to the Ruby bindings here, so the request cannot be made. Outside
Flatpak the call is a no-op anyway, and the port still `hold`s the application
so it survives its windows closing; what is missing is the sandboxed autostart
registration. Restoring it needs libportal typelibs installed and a `require`
of them.

## Desktop actions are read from the key file, not from Gio

`Gio::AppInfo`'s action API — `list_actions`, `get_action_name`,
`launch_action` — is not bound in ruby-gnome. The actions are therefore parsed
out of the `.desktop` file directly, in `DesktopEntry`.

This is less of a change than it sounds. The original reads the key file too,
because GLib has no way to launch a desktop action *with a URI argument*
([glib#2568](https://gitlab.gnome.org/GNOME/glib/-/issues/2568)) and so has to
rewrite the `Exec` line by hand. Reading everything from one place just makes
that explicit. Where the original builds a `GioUnix.DesktopAppInfo` from a
mutated key file, this builds one with `Gio::AppInfo.create_from_commandline`,
which is the same trick with less ceremony.

The filter is unchanged: an action is offered only when its `Exec` contains one
of `%U %u %f %F`, since an action that cannot take the resource would ignore
what you asked it to open. (On a typical desktop this rejects most of them —
Chrome's "New Window" and "New Incognito Window" both take no argument.)

## The `run-action` target is `as`, not `a{ss}`

The original passes `{desktop_id, action, location}` as an `a{ss}` dictionary in
the action target. ruby-gnome cannot convert a `{ss}` variant back to Ruby, so
the target here is a plain string array, `[desktop_id, action]`.

The location is not carried in it at all. It does not need to be: the entry is
in the same window and holds the current text, which is the value the user
expects to be acted on — including any edit made after the menu was opened.

## URI scheme detection is a regex

The original uses `GLib.Uri.parse` to read the scheme, specifically to work
around `Gio::File#uri_scheme` reporting `http` for an `https` URI — which would
send Junction looking up handlers for the wrong scheme. `GLib::Uri` is not bound
in ruby-gnome, so the scheme is read off the URI text instead. Same reason, same
result; `Resource` has tests pinning the https case.

Turning the entry text back into a URI is likewise plain Ruby: `~` and absolute
paths go through `Gio::File`, which does the percent-escaping, and anything else
is passed through untouched, matching the original's `UriFlags.ENCODED`.

## The breakpoint switches layout from a signal

`Adwaita::Breakpoint#add_setter` cannot take a boolean through ruby-gnome — the
value reaches `adw_breakpoint_add_setter` without a `GValue` and the call is
dropped with a critical. Two of the five portrait setters are booleans, so the
whole switch is done from the breakpoint's `apply`/`unapply` signals instead.
The condition, and all five changes, are the same.

## The welcome window no longer registers handlers on import

In the original, `welcome.js` runs a loop over five MIME types calling
`gio mime <type> re.sonny.Junction.desktop` **at module load** — that is, merely
launching Junction with no arguments silently makes it the default handler for
`http`, `https`, `text/html`, `text/xml` and `application/xhtml+xml`.

Here that loop is behind the "Set Junction as default for Web" button, which is
what the window is offering to do and what the user pressed. Opening a window
should not reassign the default browser. This is the one deliberate behavioural
difference in the port.

## Not ported

- **The `__DEV__` branches** — the restart action bound to Ctrl+Shift+Q, and the
  `devel` CSS class. They exist for the original's `gjspack` dev loop, which has
  no counterpart here.
- **Translation.** The original's `main` branch carries no `po/` directory, so
  there is no catalogue to reuse; every string is a plain Ruby literal. Adding
  gettext later is a matter of wrapping them.

## Application id

`re.sonny.Junction.Rb`, so the port installs alongside the original rather than
fighting it for the handler registration. The GSettings path, the desktop file,
the icon and the self-exclusion from the application grid all follow from that
one constant in `version.rb`. Both Junctions are in the exclusion list, so
neither offers to open a link in the other.

## Two bugs the tests caught

Worth recording, because both are shapes that recur in ruby-gnome ports:

- **`GApplication#run` needs argv[0].** It reads argv the C way, so passing a
  bare `ARGV` makes it take the first URI for the program name. `junction-rb
  https://example.com` became a plain `activate` and showed the welcome window
   — the app silently failing at the only thing it does. `test/cli_test.rb`
  pins it.
- **Action parameters arrive unpacked.** A `GLib::Variant` target reaches a
  signal handler as a plain Ruby object, so `target.value` raises. The
  `run-action` handler destructures the array directly.

## Testing

`test/gtk_driver.rb` runs the app headlessly, one step per turn of the main
loop, and writes PNGs. Two things are worth knowing before adding to it:

- **`XDG_CONFIG_HOME` does not isolate GSettings.** With a session bus present
  the dconf backend writes over D-Bus to the user's real settings — so a test
  run both scribbles on them and loses writes to the round trip, which shows up
  as a toggle that will not toggle back. Every test sets
  `GSETTINGS_BACKEND=memory`.
- **`Gtk::Widget#has_focus?` also requires the window to be active**, which is
  not reliably true headlessly. Compare against `window.focus` instead.

Fixture `.desktop` files cannot be planted for Gio to discover, because GLib
always includes the system data directories and `XDG_DATA_DIRS` cannot be
narrowed. So discovery is checked against the real installed applications, and
the key-file parsing against fixtures handed to `DesktopEntry` directly.
