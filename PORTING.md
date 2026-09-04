# Porting Junction from GJS to Ruby

The original is JavaScript on GJS, with the interface in Blueprint files
compiled into a GResource. This port is Ruby with the interface built in code,
in the house declarative style: every widget is a memoized method, configuration
lives in `tap` blocks, and `build` reads as the widget tree.

Every feature the original has, this has. Nothing was dropped as unnecessary.
What follows is where the *mechanism* differs, and why — in every case because
ruby-gnome cannot express what GJS did, not because the behaviour changed.

## libportal, through two different doors

libportal has no ruby-gnome binding gem, so `Xdp` and `XdpGtk4` are loaded
straight from their typelibs through GObject Introspection (`portal.rb`). That
covers the sandbox test and `open_directory` — the same calls the original
makes, with `XdpGtk4.parent_new_gtk` giving the portal our window as the parent
so its dialogs attach to it.

The background request could not go that way. `xdp_portal_request_background`
takes the autostart command as a `GPtrArray` of strings, and ruby-gnome cannot
marshal a `GPtrArray` in-argument — it raises `TODO: in Ruby ->
GIArgument(array/GPtrArray)`. So that one call is made through Fiddle
(`background_request.rb`), building the array by hand. The symbols resolve out
of the process image, because requiring the Xdp typelib has already dlopened
libportal.

`test/portal_test.rb` makes the request against the real portal and asserts a
real answer comes back, because a hand-rolled FFI call is exactly the kind of
thing that can degrade into a silent no-op.

The flag is read off the enum rather than written as a literal:
`XDP_BACKGROUND_FLAG_AUTOSTART` is 1 and `ACTIVATABLE` is 2, and transposing
them gives a request that succeeds while asking for the wrong thing. (It did,
until the test caught it.)

## Desktop actions are read from the key file

`Gio::AppInfo`'s action API — `list_actions`, `get_action_name`,
`launch_action` — is not bound in ruby-gnome, so the actions are parsed out of
the `.desktop` file directly, in `DesktopEntry`.

Less of a change than it sounds. The original reads the key file too, because
GLib cannot launch a desktop action *with a URI argument*
([glib#2568](https://gitlab.gnome.org/GNOME/glib/-/issues/2568)) and so rewrites
the `Exec` line by hand. Where the original then builds a
`GioUnix.DesktopAppInfo` from the mutated key file, this uses
`Gio::AppInfo.create_from_commandline` — the same trick, less ceremony.

The filter is unchanged: an action is offered only when its `Exec` carries one
of `%U %u %f %F`, since an action that cannot take the resource would ignore
what you asked it to open. On a typical desktop this rejects most of them —
Chrome's "New Window" and "New Incognito Window" both take no argument.

## The `run-action` target is `as`, not `a{ss}`

The original passes `{desktop_id, action, location}` as an `a{ss}` dictionary.
ruby-gnome cannot convert a `{ss}` variant back to Ruby, so the target here is a
string array, `[desktop_id, action]`.

The location is not carried in it. It does not need to be: the entry is in the
same window and holds the current text, which is the value the user expects to
be acted on — including an edit made after the menu was opened.

## URI scheme detection is a regex

The original uses `GLib.Uri.parse` to read the scheme, specifically to work
around `Gio::File#uri_scheme` reporting `http` for an `https` URI, which would
send Junction looking up handlers for the wrong scheme. `GLib::Uri` is not bound
in ruby-gnome, so the scheme is read off the URI text instead. Same reason, same
result; `test/resource_test.rb` pins the https case.

Turning the entry text back into a URI is likewise plain Ruby: `~` and absolute
paths go through `Gio::File`, which does the percent-escaping, and anything else
passes through untouched, matching the original's `UriFlags.ENCODED`.

## The breakpoint switches layout from a signal

`Adwaita::Breakpoint#add_setter` cannot take a boolean through ruby-gnome — the
value reaches `adw_breakpoint_add_setter` without a `GValue` and the call is
dropped with a critical. Two of the five portrait setters are booleans, so the
whole switch runs from the breakpoint's `apply`/`unapply` signals instead. The
condition and all five changes are the same.

## Development mode is an environment variable

The original's `__DEV__` is compiled in by its `gjspack` bundler. There is no
bundler here, so `JUNCTION_RB_DEV=1` turns on the same two things: the restart
action on Ctrl+Shift+Q, and the `devel` style class that marks a window as not
the installed copy.

## Translation

The original's `main` branch carries no `po/` directory, so there is no
catalogue to reuse and every string is a plain Ruby literal. Adding gettext
later is a matter of wrapping them.

## Application id

`re.sonny.Junction.Rb`, so the port installs alongside the original rather than
fighting it for the handler registration. The GSettings path, desktop file,
icon, and self-exclusion from the application grid all follow from that one
constant in `version.rb`. Both Junctions are in the exclusion list, so neither
offers to open a link in the other.

## Three bugs the tests caught

Worth recording, because all three are shapes that recur in ruby-gnome ports:

- **`GApplication#run` needs argv[0].** It reads argv the C way, so a bare
  `ARGV` makes it take the first URI for the program name. `junction-rb
  https://example.com` became a plain `activate` and showed the welcome window —
  the app silently failing at the only thing it does. `test/cli_test.rb` pins
  it.
- **Action parameters arrive unpacked.** A `GLib::Variant` target reaches a
  signal handler as a plain Ruby object, so `target.value` raises. The
  `run-action` handler destructures the array directly.
- **The wrong background flag.** See above.

## Testing

`test/gtk_driver.rb` runs the app headlessly, one step per turn of the main
loop, and writes PNGs to `tmp/shots`. Four things are worth knowing before
adding to it:

- **`XDG_CONFIG_HOME` does not isolate GSettings.** With a session bus present
  the dconf backend writes over D-Bus to the user's real settings — so a run
  both scribbles on them and loses writes to the round trip, which surfaces as a
  toggle that will not toggle back. Every test sets `GSETTINGS_BACKEND=memory`.
- **`Gtk::Widget#has_focus?` also requires the window to be active**, which is
  not reliably true headlessly. Compare against `window.focus` instead.
- **The welcome window registers MIME handlers when it is constructed**, as the
  original does on import. `XDG_CONFIG_HOME` *does* redirect that, so tests
  point it at a scratch directory.
- **`open_directory` is never exercised**, since it would put a file manager
  window on the desktop. Building the `XdpParent` handle — the part that could
  plausibly break in a Ruby port — is checked on its own.

Fixture `.desktop` files cannot be planted for Gio to discover, because GLib
always includes the system data directories and `XDG_DATA_DIRS` cannot be
narrowed. So discovery is checked against the real installed applications, and
key-file parsing against fixtures handed to `DesktopEntry` directly.
