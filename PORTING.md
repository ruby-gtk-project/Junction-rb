# Porting Junction from GJS to Ruby

The original is JavaScript on GJS, with the interface in Blueprint files
compiled into a GResource. This port is Ruby with the interface built in code,
in the house declarative style: every widget is a memoized method, configuration
lives in `tap` blocks, and `build` reads as the widget tree.

What follows is where the *mechanism* differs, and why — in every case because
ruby-gnome cannot express what GJS did, not because the behaviour changed.

## What is still missing

The list the parity reports in `.reports/` produce, kept current as each entry
closes. It is here rather than in a claim of completeness, because a claim of
completeness in the port's own documentation is worth nothing.

- I did not take the port's file-chooser and mobile screenshots, because I am
  an idiot.
  Upstream: three `<screenshot>` blocks —
  `data/screenshot.png`, `data/screenshot-file.png`, `data/screenshot-mobile.png`
  (`data/re.sonny.Junction.metainfo.xml:37-56`), with the captions *Choose the
  application to open the image with* and *Junction supports Linux mobile*,
  both of which have 32 translations in `po/`.
  Port: one `<screenshot>` block
  (`data/re.sonny.Junction.Rb.metainfo.xml:51-58`), so a software centre shows
  a third of what upstream shows and two translated captions reach nobody.
  `test/gtk_driver.rb` can drive the two states and photograph them.
- I did not commit the message template, because I am an idiot.
  Upstream: `po/re.sonny.Junction.pot`, regenerated as part of the build
  (`po/meson.build`), on the `l10n` branch.
  Port: no committed template and no check that a regenerated one matches, so
  the key set has no reviewable record — which is how three missing msgids
  went unnoticed until a parity report counted them.

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

## The theme switcher is three buttons on one action

Upstream embeds troll's `ThemeSelector` in the menu's custom `themeswitcher`
slot. There is no troll here, so the widget is `theme_switcher.rb` — but the
wiring is upstream's: the three check buttons carry `action-name
app.color-scheme` with their Adwaita colour-scheme value as the target, and
that action is `Gio::Settings#create_action`, bound straight to the key. GTK
activates the button whose target equals the action's state and writes the
target back when one is clicked, so nothing in the widget reads or writes
GSettings and the stored value cannot disagree with the buttons.

The target is built with an explicit `'i'` variant type. The key is an
integer, and an int64 target would never compare equal to the action's state —
the buttons would all sit inactive and clicking them would do nothing.

Blueprint binds each checkmark's `visible` to its button's `active` property;
here that one binding is a `notify::active` handler, which is all the handler
does.

## Translation

The original's `main` branch carries no `po/` directory — the catalogue lives
on its `l10n` branch, and that is where `po/` came from: 32 languages, copied
across untouched. `po/*.po` is donated work and is never edited here; only
`rmsgmerge` touches it, and only when the message set genuinely changes.

Two consequences worth knowing:

- **The gettext domain stays `re.sonny.Junction`,** not the port's app id. A
  compiled catalogue is found at `<path>/<lang>/LC_MESSAGES/<domain>.mo`, so the
  domain *is* the filename; renaming it would orphan all 32 translations. It is
  `JunctionRb::TEXT_DOMAIN`.
- **The msgids are byte-identical to the original's,** mnemonics and wording
  included, because a msgid is a hash key and not a description of a sentence.
  Where the original's current string differs from the 2022 catalogue snapshot
  — `Show App Names` for the old `Show names`, and the four strings added since
  — the port follows the original and the translation arrives when Weblate
  catches up.

The markers come from the pure-Ruby `gettext` gem, bound once on the
`JunctionRb` module and mixed into each class as `include Translations`:
`_()` translates now, `N_()` marks a literal in a frozen constant for
translation at display. `glib2` only offers `bindtextdomain`, which the port
also calls, because the desktop file, the metainfo and the GSettings schema are
translated by GLib and AppStream from the same `.mo`.

`rake gettext:mo:update` compiles `po/` into
`locale/<lang>/LC_MESSAGES/re.sonny.Junction.mo`, and `rake po:check` runs GNU
`msgfmt -c --check-format` over every catalogue — the format-specifier check
that the gem's own `rmsgfmt` does not do at all.

The compiled catalogues are **tracked and packaged**, unlike most build
output. Upstream compiles its `.mo` files in `po/meson.build` as part of the
install; a gem has no build step, so a `locale/` that existed only on the
machine that ran the rake task would mean a published gem in which every `_()`
returns its msgid in all 32 languages. `junction-rb.gemspec` lists
`locale/**/*.mo`, `.gitignore` admits exactly those files and nothing else
under `locale/`, and `rake test` depends on `gettext:mo:update` so the
compilation is exercised on every run rather than at release time.

`Name=` in the desktop file stays upstream's `Junction`, because that msgid
has 32 translations; the port distinguishes itself with
`X-GNOME-FullName=Junction (Ruby)` — an `X-` key, so it adds no untranslated
msgid — and with the `.Rb` application id, which is what actually keeps the
two installs apart.

## Application id

`re.sonny.Junction.Rb`, so the port installs alongside the original rather than
fighting it for the handler registration. The GSettings path, desktop file,
icon, D-Bus service name and self-exclusion from the application grid all
follow from that one constant in `lib/junction_rb.rb`. Both Junctions are in
the exclusion list, so neither offers to open a link in the other.

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
- **`open_directory` owes a behaviour, and it is tested.** "Open Location"
  closes Junction only once the file manager has actually come up, so a
  refusal has to leave the window standing — which means the failure path is
  as load-bearing as the success one. Driving the real portal would put a file
  manager window on the desktop, so `Host.portal` is assignable and
  `test/portal_test.rb` drives both outcomes through it, at the `Host` level
  and again through `ShowInFolderButton`'s `on_opened`. Building the
  `XdpParent` handle out of a real `Gtk::Window` is still checked against the
  real libportal.
- **The Flatpak sandbox is reachable from the suite.** Every sandbox-only
  branch — the `flatpak-spawn --host` wrapper, the `/run/host` prefix for
  icons and `os-release`, the document-portal lookup, the imperative
  web-handler claim — hangs off `Host.flatpak?`, and a test run on the host
  would otherwise never enter any of them. The predicate memoises and
  `Host.flatpak =` overrides it, which is the same seam upstream uses when it
  assigns over `Xdp.Portal.running_under_flatpak`
  (`test/util.test.js:103-156`); `test/desktop_entry_test.rb` ports upstream's
  `prefixCommandLineForHost` and `getIconFilename` assertions across both
  branches and puts the predicate back afterwards.

Fixture `.desktop` files cannot be planted for Gio to discover, because GLib
always includes the system data directories and `XDG_DATA_DIRS` cannot be
narrowed. So discovery is checked against the real installed applications, and
key-file parsing against fixtures handed to `DesktopEntry` directly.
