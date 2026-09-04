# Junction — Ruby port

The Ruby GTK4 / Libadwaita port of Junction lives on this branch. The original
GJS implementation is on `main`; `PORTING.md` records where the two differ and
why.

The app is in `lib/junction_rb/`, the entry point is `bin/junction-rb`, and the
data files (GSettings schema, stylesheet, icons, desktop file) are in `data/`.
`rake` runs the schema build, the tests and rubocop.

## Skills — use them

Two skills are installed in `.claude/skills/`. They are not optional reading.

- **ruby-gtk** — the house style for Ruby GTK4/Libadwaita: the declarative
  memoized-widget pattern, Adwaita binding quirks, worked examples. Load it
  before writing or reviewing ANY Ruby GTK code, including single widgets, and
  before planning a port. The bindings are quirky enough that code written from
  memory is unreliable.
- **ruby-gtk-testing** — run the app headlessly and drive its UI: click through
  dialogs, assert widget state, capture screenshots. Use it before claiming any
  GTK change works. `ruby -c` and a successful `require` prove nothing about a
  UI.

## Setup

`direnv allow` (or `nix develop`) gets Ruby, GTK4, Libadwaita and the
introspection typelibs. Then `bundle install`.

The system `ruby` on PATH may be a wrapper pinned to a gemset without
`adwaita` — run everything through `nix develop --command bundle exec …`.

## Style

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies, and fixed
multi-line argument/hash layout. Run `bundle exec rubocop` before committing.
