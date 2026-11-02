# Junction (Ruby)

A Ruby GTK4 / Libadwaita port of [Junction](https://junction.sonny.re) by Sonny
Piers.

Junction asks which application should open a link or a file. Set it as the
handler for `http` and `https` and every link you click puts up a row of the
browsers and apps that can take it, with the URL editable underneath, instead of
silently going to whichever one you set as default a year ago.

![Junction opening a local HTML file](docs/window.png)

## Running

The dev shell brings Ruby, GTK4, Libadwaita and the introspection typelibs:

```sh
direnv allow            # or: nix develop
bundle install
rake schema             # compile the GSettings schema into data/schemas
GSETTINGS_SCHEMA_DIR=$PWD/data/schemas bundle exec ruby exe/junction-rb https://example.com
```

With no arguments it shows the welcome window, which offers to register itself
as the handler for the web types. That button is a no-op until the desktop
entry is installed — see Installing below, and `rake install:all`.

## Installing

A gem has no `$datadir` to install into, so the five files upstream's
`data/meson.build` installs go under `XDG_DATA_HOME` instead, one rake task
each:

```sh
rake install:desktop    # the .desktop entry, translated, into applications/
rake install:metainfo   # the AppStream metainfo, translated, into metainfo/
rake install:schema     # the GSettings schema, compiled, into glib-2.0/schemas/
rake install:icons      # the scalable and symbolic icons into icons/hicolor/
rake install:service    # the D-Bus activation service (BINDIR= to override)

rake install:data       # the first four
rake install:all        # all five
```

`rake install:all` is what makes the port reachable. The welcome window's "Set
Junction as default for Web" button runs `gio mime x-scheme-handler/https
re.sonny.Junction.Rb.desktop`, and `gio` can only name a desktop id that exists
in an `applications/` directory — so until `install:desktop` has run, pressing
the button registers nothing. `install:service` is what lets D-Bus activate the
port by name rather than only launching it from a shell.

The desktop entry and the metainfo are run through `msgfmt --desktop` and
`msgfmt --xml` on the way in, which is meson's `i18n.merge_file`: the installed
copies carry all 32 languages, not just English.

## Using it

Click a tile to open the resource with that application and close Junction.

| | |
|---|---|
| Click | open, and close Junction |
| Ctrl+click, or middle click | open, and leave Junction up for another |
| Right click, long press, or the Menu key | that application's desktop actions |
| `1`…`9` | open with the application at that position |
| ←, → | move between applications |
| Return, space | open with the selected application |
| Ctrl+Return, Ctrl+space | open with it and stay |
| Ctrl+C | copy the location |
| Escape, Ctrl+W | close |
| Ctrl+? | keyboard shortcuts |
| Ctrl+Q | quit |

The URL is editable before you hand it on, so a tracking parameter can be
trimmed on the way past. File paths are shown but not editable.

The main menu carries a light/system/dark switcher, "Show App Names" for labels
under the icons, and "Copy to Clipboard".

## Development

```sh
rake            # schema, tests, data validations, both drives, rubocop
rake test       # the suite; UI tests run headlessly and write tmp/shots/*.png
rake drive      # the two drive scripts on their own
rake validate   # the three data-file validations upstream runs as meson tests
rake lint
```

`rake test` reads `po/` and `locale/` and writes neither: it depends on
`gettext:check`, which compiles every `po/<lang>.po` into a temporary directory
and compares the result against the tracked catalogue. Compiling the tracked
catalogues is `rake gettext:mo:compile`, which is deliberately not a dependency
of anything — it is the one task that writes `locale/`, and it is run on
purpose after `po/` has changed.

When a user-visible string is added, removed or reworded:

```sh
rake gettext:pot        # re-extract po/re.sonny.Junction.pot from po/POTFILES
rake gettext:merge      # msgmerge it into all 32 donated po/<lang>.po
rake gettext:mo:compile # compile them into locale/
```

`po/POTFILES` is the single list of files that carry strings — the Ruby
sources, the desktop entry, the GSettings schema and the metainfo — and
`rake gettext:potfiles` fails if a source grows a `_()` without being added to
it.

`JUNCTION_RB_DEV=1` adds the restart accelerator (Ctrl+Shift+Q) and the `devel`
window styling.

The tests drive the real app with no display server. GTK4 renders offscreen, so
the screenshots under `tmp/shots` are worth looking at — they show what the
assertions do not think to ask about.

`PORTING.md` records what changed on the way over from GJS.

## Licence

GPL-3.0-only, as the original.
