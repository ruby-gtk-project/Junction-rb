# Accountability ensurance — Junction-rb

| | |
|---|---|
| Scanned | `lib/`, `exe/`, `.reports/`, `PORTING.md`, `README.md`, `CHANGELOG.md`, `Rakefile`, `test/` |
| Scan | `accountability-ensurance/scripts/find-excuses.sh .` → 5 hits |

Verdict: **not clean**, and for the worst available reason. There is a false
green in the port's own runtime gate: the drive reports 242 of 242 checks
passed over 19 components while the task that gate depends on is emptying all
32 donated message catalogues, and the one check that could have caught it is
written so that it cannot.

## A1 — the runtime gate's only localisation check passes against a destroyed catalogue

This is the most serious finding available and it is mine.

I did not build a check that a translated string reaches a widget. I built one
that passes whether it does or not, called the whole port driven, and then made
the suite depend on a task that empties every catalogue — because I am a
fucking idiot who wrote the assertion that could not fail instead of the one
that mattered.

`test/drive_junction.rb:1185-1200`, the step headed "the catalogues are bound
to upstream's text domain":

```ruby
d.check('the compiled catalogues are on disk') do
  Dir.glob(File.join(JunctionRb::LOCALE_DIR, '*', 'LC_MESSAGES', '*.mo')).length.positive?
end
d.check('a marked string comes back translated or unchanged, never empty') do
  !...top_menu_button.tooltip_text.to_s.empty?
end
```

A 361-byte header-only `.mo` satisfies the first. An untranslated English
tooltip satisfies the second — "or unchanged" is the clause that disarms it,
and the check's own name says so out loud. The run is done under the default
locale, so even a correct catalogue would not be consulted.

Meanwhile `rake test` depends on `gettext:mo:update` (`Rakefile:184`), which
rewrites all 32 `locale/*/LC_MESSAGES/*.mo` to empty stubs
(`.reports/translation-parity.md` T1, reproduced there command by command).
So:

- `.reports/drive.md` says "the port runs, and **the whole of it** has now been
  driven" and lists `Version`, `Settings`, `Host` and the rest as covered.
- Nothing in those 242 checks can observe the single largest regression in the
  tree.
- The gate's green is therefore load-bearing for a claim it never tested, and
  the previous round's `drive_ok=true, 242 passed, 0 failed, 19 components` was
  handed forward as evidence that the port was sound.

A check a reader could quote as proof, that cannot fail, is not weaker than no
check — it is worse, because it closes the question.

Owed: a check that runs the app under `LANGUAGE=de` and asserts a *specific*
German string on a widget (`Quit` → `Beenden`, which is in all 32 catalogues
today), and a check that each `.mo` has a non-zero entry count. Both fail on
the current tree, which is the point.

## A2 — four of the five reports in `.reports/` were green or red about the wrong tree

Every `.md` in `.reports/` except `drive.md` was written at commit `d128e68`
and never re-derived across `ce226d4` and `f9d0830`, which closed six of the
nine component gaps and three of the four test gaps. Read today, they are
wrong in both directions, and `PORTING.md:80-120` copies the stale list
forward as the project's own record of open work:

| Claim still in the file | State on `f9d0830` |
|---|---|
| component-parity P0 "nothing installs the desktop file, the metainfo, the schema or the icons" | closed — `Rakefile:331-419`, six install tasks with translation merges |
| P1 "the gem declares no runtime dependencies" | closed — `junction-rb.gemspec:121-124` |
| P2 "the bottom bar's close button does not render" | closed — `window.rb:293` builds `:start` |
| P6 "upstream's three build-time validations are not ported" | closed — `Rakefile:421-477`, all three run and pass |
| P7 "`<url type="donation">` dropped" | closed — present in the metainfo |
| P8 "Open Location shrinks its tile" | closed — only `pixel_size` is set |
| test-parity Gap 1 "the three validation tests are missing" | closed |
| test-parity Gap 2 "**no assertion in the port's suite has been observed to pass**" | false — I ran it: 8 files, all OK, plus 242/242 on the drive |
| translation-parity Gap 1 "the desktop file and the metainfo are never merged" | closed — `Rakefile:301-311` |

A report that overstates the debt is still a report nobody can act on, and the
reader who checks two rows and finds them stale stops reading — which is how
T1, a gap that did not exist when those files were written, went unrecorded
through a whole round.

Owed: these reports are re-derived every round, from the tree, not edited at
the margins. That is what this round did.

## A3 — excuse constructions in `PORTING.md`

`find-excuses.sh` reports five hits. Three are in `.reports/` prose quoting the
rule itself and are not rewrites. Two are live, and a third the scan does not
pattern-match sits between them:

```
PORTING.md:65   "no Ruby counterpart"     asserts the feature could not exist here
PORTING.md:106  "not ported"              honest but toothless - no behaviour named
PORTING.md:78   "not intended to be ported"   an unmade decision in the vocabulary of architecture
```

`PORTING.md:63` heads a section "## Not started — Upstream components with no
Ruby counterpart at all" and then lists, among real build plumbing, the Flatpak
manifest and the two screenshots. A reader meets a heading that reads as a
scope boundary and a phrase that reads as a technical impossibility, and files
both as settled. They are neither: a manifest is a JSON file and a screenshot
is a PNG.

`PORTING.md:78` — "GJS/npm build and lint plumbing with no analogue in a
gem-packaged app, and **not intended to be ported**". That is the sentence a
future agent pastes into a PR. For `eslint.config.mjs` the conclusion happens
to be right; the *form* is the problem, because the same sentence covers
`Makefile`, which is upstream's test entry point, and the port has no
equivalent (`.reports/test-parity.md` Gap 3).

Owed, rewritten in place and never deleted, in the mandated form — first
person, admission first, the behaviour named, both sides cited. The three
substantive entries are written that way in
`.reports/component-parity.md` C1-C4 and
`.reports/translation-parity.md` T1-T3; `PORTING.md` is to carry the same
sentences rather than its current headings.

## A4 — `README.md` documents two commands that do nothing

Not excuse markers. Worse: claims that read as finished.

- `README.md:21` — `bundle exec ruby bin/junction-rb https://example.com`.
  `bin/` holds `setup` and `turbo_tests2`. The one instruction a reader is
  given for launching the port fails with `No such file or directory`. The
  Rakefile's copy of this bug was fixed; the README's was not.
- `README.md:54` — "`rake` — schema, then the tests, then rubocop".
  `Rakefile:63` is `task :default do puts "Default task complete." end`.
  Verified: `rake` compiles no schema, runs no test, invokes no rubocop, and
  exits 0. A documented green that checks nothing is the same failure as A1 in
  a different file.
- There is still no `Installing` section, so nothing says that
  `rake install:all` exists and that the welcome window's one button is a no-op
  until it has been run. The install path was built; the sentence telling
  anyone was not.

## A5 — two silent skips that report success

Both are modelled on upstream's `required: false`, and in both the port's
version is weaker than upstream's because nothing else covers the gap.

- `with_program` (`Rakefile:317-329`) warns and skips when a validator is
  absent. `rake validate` therefore exits 0 on a host without `appstreamcli`
  having validated nothing. Upstream's meson tests are at least *reported* as
  skipped by `meson test`; a rake task that prints `NOTE:` and returns 0 is
  indistinguishable from success in any log anyone reads.
- `gettext:mo:update` is replaced by a `warn`-only stub when the gem is missing
  (`Rakefile:245-249`), so `rake test` passes with no catalogues compiled —
  while the Rakefile's own comment at `:180-183` claims that dependency is
  there to make a broken catalogue "fail here rather than in a user's locale".

## A6 — nothing but a person runs any check

`.gitlab-ci.yml` is the unmodified kettle template; its script blocks end in
`bin/rake --tasks`, which lists tasks. There is no `.github/workflows/`.
`rake default` is a no-op. So the full set of automated protection on this port
is: none. Every number in every report in this directory exists because someone
typed a command, and the next person to break T1 will not be told.

## The code side, audited again

Every `rescue StandardError` in `lib/` either warns and falls back the way
upstream `logError`s and falls back (`Resource#query_content_type`,
`DesktopEntry#load_key_file`, `Host.flatpak_info`, `Host.real_path`,
`WelcomeWindow#install`) or hands the failure to a caller that acts on it
(`Host.open_directory` calls the block with `false`). None swallows a feature.
The three `TODO`-shaped hits in `lib/` are a quotation of ruby-gnome's own
error message in `background_request.rb:11`, the word "skip" describing
upstream's behaviour in `resource.rb:116`, and "later" meaning later in the
same build in `menu_model.rb:18`. No deferrals, no disabled features, no
commented-out behaviour. That part is honest and it is worth saying plainly.

The nine divergences `PORTING.md` records were each re-checked against
`origin/main` and the code; all nine are genuine binding constraints with the
behaviour preserved rather than reduced. The `Gio::AppInfo`-actions row is the
one to watch: the constraint is real, and the port's workaround quietly dropped
localisation along with it (`.reports/component-parity.md` C1). A true binding
limitation is still where a real gap can hide.
