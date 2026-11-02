# Accountability ensurance — Junction-rb

Verdict: **not clean** — but for the opposite reason to the usual one. There
are no excuse markers in the code at all. The accountability problem here is
not a `TODO` standing in for work; it is upstream functionality that is absent
with nothing anywhere acknowledging that it is absent.

## Excuse-marker census

```
grep -rniE 'todo|fixme|hack|not implemented|unimplemented|for now|in a future|
            placeholder|stub|later|xxx|workaround|good enough|skip' lib exe
```

Every hit, classified:

| Hit | Verdict |
|---|---|
| `lib/junction_rb/background_request.rb:11` — `it raises "TODO: in Ruby -> GIArgument(array/GPtrArray)"` | **not an excuse.** A quotation of ruby-gnome's own error message, in the comment explaining why that one call goes through Fiddle. The work was done, not deferred. |
| `lib/junction_rb/resource.rb:116` — "…the percent-escaping the concatenation would **skip**" | **not an excuse.** The word "skip" describing upstream's behaviour, in a comment about code that does not skip it. |
| `lib/junction_rb/menu_model.rb:18` — "the theme switcher widget is **later** dropped into" | **not an excuse.** "Later" means later in the same build, in `Window#menu_button`. |

`exe/` has no hits. `PORTING.md`, `README.md`, `CHANGELOG.md` have one hit
between them, the same quoted ruby-gnome error.

So: **zero deferrals, zero disabled features, zero "not implemented",
zero commented-out behaviour.** No `rescue` swallows a feature — every
`rescue StandardError` in `lib/` either `warn`s and falls back the way upstream
`logError`s and falls back (`Resource#query_content_type`,
`DesktopEntry#load_key_file`, `Host.flatpak_info`, `Host.real_path`,
`WelcomeWindow#install`) or hands the failure to a caller that acts on it
(`Host.open_directory` calls the block with `false`).

## What is being skipped silently instead

The gaps in `.reports/component-parity.md` and
`.reports/translation-parity.md` are not marked anywhere, and two documents
read as though they were not gaps at all:

1. **There is no "Installing" section in `README.md`.** The document goes
   straight from "Running" (from a checkout) to "Using it". Nothing says that
   there is no way to install the desktop file, the metainfo, the schema or the
   icons — and therefore no way for Junction-rb to actually become the
   application the desktop hands a link to, which is the entire premise stated
   in the README's own second paragraph. An absent section is not an excuse,
   but it is the gap going unrecorded.

2. **`README.md:21` and `Rakefile:201-208` both document `bin/junction-rb`,
   which does not exist** (`bin/` holds `setup` and `turbo_tests2`; the
   executable is `exe/junction-rb`). The one instruction a reader is given for
   launching the port is wrong, and nothing flags it. Documented-but-broken is
   worse than `TODO`, because it reads as finished.

3. **`po/POTFILES` lists three data files that the extraction task does not
   read** (`Rakefile:230-232` globs `lib/**/*.rb` and `exe/*`). The file
   asserts coverage that does not exist. Again not an excuse marker — a stale
   manifest — but it is the same failure mode: a claim standing in for the
   work.

4. **`junction-rb.gemspec` declares no runtime dependencies**, so the gem it
   builds cannot run, and nothing in the gemspec, the README or `PORTING.md`
   says that the gem is not meant to be installed.

5. **`.gitlab-ci.yml` is the unmodified kettle template.** It runs the RSpec
   defaults against a tree with no `spec/` and never invokes `rake test`. A
   pipeline that passes while running none of the suite is an accountability
   problem in its own right: it reports a state it has not checked.

## `PORTING.md` audited for excuses dressed as rationale

Each of the nine divergences `PORTING.md` records was checked against the code
and against `origin/main`. All nine are genuine binding constraints with the
behaviour preserved, not reduced:

| Claim | Holds? |
|---|---|
| `GPtrArray` in-argument unmarshalable → Fiddle | yes — and the call is made, with the strings, array and closure deliberately retained past the call |
| `a{ss}` variant unconvertible → `as` target | yes — and the location is read off the entry, so the user-visible behaviour is identical |
| `Breakpoint#add_setter` drops booleans → `apply`/`unapply` | yes — all five setters reproduced |
| `Gio::AppInfo` action API unbound → key file | yes — and upstream parses the key file anyway, for glib#2568 |
| `GLib::Uri` unbound → regex scheme | yes — and it fixes upstream's `https`-reported-as-`http` problem |
| `Adwaita::Application` broken → `Gtk::Application` | yes — matches the pilot port |
| `Gtk.ShortcutsWindow` deprecated → `Adwaita::ShortcutsDialog` | yes — same two untitled groups, same eight shortcuts |
| `.Rb` ids to install alongside | yes — and both desktop ids are in `DesktopEntry::EXCLUDED` |
| fixture `.desktop` files cannot be planted → tests use real apps | yes — `XDG_DATA_DIRS` cannot be narrowed below the system dirs |

None of these is a reduced feature justified by a binding. That is the right
answer, and it is worth saying plainly: the code side of this port is honest.

## What to do

Nothing to remove. The actions are to build the five things nothing currently
admits are missing — the install path (component-parity P0), the gemspec
runtime dependencies (P1), the `bin/`→`exe/` fix in the README and Rakefile
(P3), the data-file translation merge (translation-parity Gap 1), and the
catalogue merge for the eight untranslated strings (Gap 2) — and then to say in
`README.md` what is and is not installable, so the next audit can check a claim
instead of inferring an absence.
