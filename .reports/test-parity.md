# Test parity — Junction-rb against `origin/main`

> **Round 3 re-derivation (this commit, `3faff07`).** Re-ran, did not re-read.
> In this session, in the dev shell:
>
> ```
> nix develop --command xvfb-run -a bundle exec rake test   # exit 0, all 8 files OK
> nix develop --command xvfb-run -a ruby test/drive_junction.rb   # 246 of 246, DRIVE OK
> nix develop --command xvfb-run -a ruby test/drive_locale.rb     # 16 of 16, DRIVE OK
> nix develop --command xvfb-run -a bundle exec rake              # schema, test, validate, drive, lint — all green, rubocop 48 files no offenses
> ```
>
> Both drive scripts and the full default `rake` task were executed, not
> read about — this is the "a suite that has never been executed is a gap"
> check this skill asks for, discharged for this commit rather than carried
> forward from round 2's numbers. All four of round 2's gaps (1–4) are
> re-confirmed closed; nothing regressed. No new test file and no new upstream
> test exist since round 2 — `3faff07` added `rake screenshots`
> (`test/capture_screenshots.rb`, `test/screenshot_apps.rb`), which is
> deliberately outside `rake test`/`rake` because it rewrites tracked PNGs,
> and that exclusion is itself exercised: the commit message for `3faff07`
> says so and the Rakefile does not list it under `task default`, both read
> directly rather than taken on trust.
>
> One miss this round found that the test suite does not cover: the new
> component-parity gap C6 (`.reports/component-parity.md`) — the theme
> switcher's missing `notify::system-supports-color-schemes` re-evaluation —
> has no test anywhere, upstream or port, because upstream's own
> `troll/tst/` test harness never covered `ThemeSelector` either (checked:
> no `*.test.js` under `troll/` references it). So this is not a "port
> dropped a test", it is a behaviour neither side pins down with a test, which
> is a gap in upstream's coverage inherited rather than introduced.

> **Round 2 re-derivation.** The text below the line was derived
> at `f9d0830` and is kept verbatim. This block is each gap's state now.
>
> | Gap | State on this commit |
> |---|---|
> | 1 `rake test` empties all 32 catalogues | **closed.** `task test` depends on `gettext:check` (`Rakefile:471-511`), which compiles each `po/<lang>.po` into a temporary directory and compares its entry count with the tracked `.mo`. It reads `po/` and `locale/` and writes neither. Verified: a full `rake test` leaves `git diff -- locale po` empty, and CI asserts that too. |
> | 2 `gettext:mo:update` stubbed to a warning | **closed.** There is no warn-only stub left. `require_program` (`Rakefile:601-607`) raises when `msgfmt`, `rxgettext`, `msgmerge`, `appstreamcli`, `desktop-file-validate` or `glib-compile-schemas` is missing, naming where it comes from. `with_program`, which warned and returned, is gone; the two genuinely optional cache-refreshers (`update-desktop-database`, `gtk4-update-icon-cache`) use `if_program`, which says out loud that it skipped. |
> | 3 nothing but a human runs any of it | **closed.** `.github/workflows/ci.yml` runs `rake gettext:check`, `xvfb-run -a rake test`, `rake validate`, `xvfb-run -a rake drive` and `rake lint` on every push and pull request to `ruby`, uploads the screenshots, and fails if the run dirtied `locale/`, `po/` or `data/`. `task default` (`Rakefile:781`) depends on the same five, so `rake` with no arguments does what `README.md` says it does. |
> | 4 one file's failure hides the seven after it | **closed.** `task test` (`Rakefile:183-217`) runs all eight with `system`, collects the failures and raises at the end with the full list. |
>
> Observed this round, in the dev shell: 8 of 8 test files OK;
> `test/drive_junction.rb` 246 of 246 checks, DRIVE OK;
> `test/drive_locale.rb` 16 of 16 checks, DRIVE OK; `rake validate` all three
> validators run and pass; `rubocop` 46 files, no offenses.

| | |
|---|---|
| Upstream | `origin/main` @ `70560b6` |
| Port | `ruby` @ `f9d0830` |
| Upstream tests | 4 unit (`test/util.test.js`, run by `troll/tst`) + 3 build-time (`data/meson.build`) = 7 |
| Ported | 7 |
| Gaps | 0 in the census — **4 gaps in whether any of it is run** |
| Test command | `nix develop --command xvfb-run -a rake test` |

Verdict: **not clean.** The census is a bijection and, unlike the last pass, I
executed the suite: every file passes. What is not clean is everything around
the suite — nothing runs it but a human, the ported validations are wired into
no target, and the suite has a destructive side effect that empties all 32
message catalogues every time it runs.

## Execution, observed rather than inferred

The last report said "the suite cannot be executed… no assertion in the port's
suite has been observed to pass". That is now false, and I am recording the
numbers rather than an adjective.

```
nix develop --command xvfb-run -a ruby test/drive_junction.rb
  => 242 of 242 checks passed · DRIVE OK · 19 components · 10 screenshots

nix develop --command xvfb-run -a rake test
  test/resource_test.rb      RESOURCE OK
  test/settings_test.rb      OK
  test/cli_test.rb           OK
  test/desktop_entry_test.rb OK
  test/portal_test.rb        OK
  test/window_test.rb        31 of 31 checks passed · DRIVE OK
  test/url_test.rb           17 of 17 checks passed · DRIVE OK
  test/welcome_test.rb       17 of 17 checks passed · DRIVE OK
  => exit 0
```

Census: `test-census.sh` gives 4 rows upstream and 525 in the port. The
assertion unit on the port side is `check` (`test/gtk_driver.rb`); `step` is
the grouping call, and censusing on both double-counts, so the 525 is read as
leads, not as a count to compare.

## Upstream's four unit tests

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test/util.test.js:19` `parse` | 10 inputs: `~`, `~/`, `/`, `/foo/`, bare and encoded URLs, `mailto:`, a query string — which get a `file://` prefix, which are passed through, which keep a trailing slash | `test/resource_test.rb:150-205`, 12 checks on `Resource.parse_location` | ported |
| 2 | `test/util.test.js:35` `readResource` | 11 inputs: the `x-junction` unwrap including `file:0//` and `:0//` demangling, `~`/`~/…` through `parse_name`, scheme detection, content-type sniffing, the `query_info` failure falling back to `application/octet-stream` | `test/resource_test.rb:32-148` | ported |
| 3 | `test/util.test.js:103` `prefixCommandLineForHost` | upstream's exact command line in both sandbox states, plus no-double-prefix in both | `test/desktop_entry_test.rb:224-241` | ported |
| 4 | `test/util.test.js:128` `getIconFilename` | `/usr`, `/etc`, `/home`, `/opt` × both sandbox states — only `/usr/` and `/etc/` are rewritten | `test/desktop_entry_test.rb:245-283` | ported |

The seam for 3 and 4 is `Host.flatpak = true/false` (`host.rb:28-39`), which is
the direct analogue of upstream assigning over
`Xdp.Portal.running_under_flatpak`, and it is reset to `nil` afterwards with a
check that the question goes back to libportal
(`test/desktop_entry_test.rb:303`).

## Upstream's three build-time tests

| Upstream test | Command | Port |
|---|---|---|
| "Validate desktop file" | `desktop-file-validate` | `Rakefile:422-438`, `rake validate:desktop` |
| "Validate appstream file" | `appstreamcli validate --no-net --explain` | `Rakefile:440-460`, `rake validate:metainfo` |
| "Validate schema file" | `glib-compile-schemas --strict --dry-run` | `Rakefile:465-473`, `rake validate:schema` |

All three run and all three pass here — and the first two validate the
*translation-merged* file, which is stricter than validating the template.
Ported.

## Gap 1 — `rake test` empties all 32 message catalogues

`Rakefile:184` — `task test: ['schema', 'gettext:mo:update']`. That dependency
destroys the inherited catalogue, deterministically, on every run:

```
$ git checkout -- locale/ && ls -l locale/de/LC_MESSAGES/*.mo
-rw-r--r-- 6295 locale/de/LC_MESSAGES/re.sonny.Junction.mo
$ nix develop --command rake gettext:mo:update
$ ls -l locale/de/LC_MESSAGES/*.mo
-rw-r--r--  361 locale/de/LC_MESSAGES/re.sonny.Junction.mo
$ git status --short locale/ | wc -l
32
```

361 bytes is the `.mo` header and nothing else — `msgunfmt` prints no entries.
GNU `msgfmt po/de.po` produces 6295 bytes and 61 entries from the same source.
The mechanism and the full consequences are in
`.reports/translation-parity.md` T1. Here the point is narrower and worse: the
suite that is supposed to protect the port is the thing that breaks it, and it
does so silently, with exit 0, while reporting 242/242.

A test target may not have side effects outside `tmp/`. This one rewrites 32
tracked files.

## Gap 2 — `gettext:mo:update` is stubbed to a warning, so the suite can pass having compiled nothing

`Rakefile:245-249` replaces the whole gettext namespace with

```ruby
task("gettext:mo:update") { warn("NOTE: the gettext gem isn't installed, …") }
```

when `require "gettext/tools/task"` raises. The Rakefile's own comment at
`:180-183` says the dependency exists so that "a `po/` change that does not
compile, or a gettext task that has stopped working, fails here rather than in
a user's locale". On a machine without the gem it does the opposite: the suite
reports success and the catalogues the comment claims were validated were never
looked at.

## Gap 3 — nothing but a human runs any of it

- `.gitlab-ci.yml` is the unmodified kettle template. Its two script blocks
  (`:43-55`, `:70-85`) end in `bundle exec appraisal … bin/rake --tasks`, which
  *lists* tasks. Nothing in the file invokes `rake test`, `rake validate` or
  any file under `test/`.
- There is no `.github/workflows/` directory.
- `rake default` (`Rakefile:63`) prints "Default task complete." and does
  nothing, so even the conventional entry point runs no test.
- `rake validate` is depended on by no other task, so upstream's three tests
  run only if someone types them.

Upstream runs its suite from `.husky/pre-push` and its validations from
`meson test`. The port's equivalent is a person remembering.

## Gap 4 — one file's failure hides the seven after it

`Rakefile:187-197` iterates the eight files with `sh`, which aborts the rake
task on the first non-zero exit. Each file is its own process with its own
`exit`, which is right, but a failure in `resource_test.rb` means
`settings_test.rb` through `welcome_test.rb` are never run and the report says
one failure where there may be eight.

## Port tests with no upstream counterpart

Additions, outside the count. Most pin the ruby-gnome divergences `PORTING.md`
records, which is where a port needs tests upstream does not have.

- `test/drive_junction.rb` — 242 checks over all 19 components; opens every
  window, dialog, menu and popover, fires every action and accelerator,
  reaches the empty and error states, writes ten screenshots.
- `test/window_test.rb` — 31 checks: the widget tree, the breakpoint, the
  actions, the 1…9 shortcuts.
- `test/welcome_test.rb` — 17 checks: the window, the install button, the
  success/error routing.
- `test/url_test.rb` — 17 checks: scheme detection, `https` vs `http`, entry
  round-tripping.
- `test/cli_test.rb` — `--terminate_after_init`, the option-context strings,
  `argv[0]` handling.
- `test/portal_test.rb` — `BackgroundRequest` over real D-Bus;
  `Host.open_directory` both outcomes through the `Host.portal=` seam.
- `test/desktop_entry_test.rb` (first half) — discovery, exclusions, key-file
  and desktop-action parsing.
- `test/settings_test.rb` — the schema, both keys, the stateful actions.
- `test/resource_test.rb` (beyond rows 1-2) — directories, missing paths,
  `show_in_folder?`.

**No test anywhere asserts that a translated string reaches a widget**, which
is why Gap 1 has been live and green. The drive's only localisation check
(`test/drive_junction.rb:1193`) asserts a tooltip is "translated or unchanged,
never empty" and its companion asserts `Dir.glob('*.mo').length.positive?` — a
361-byte empty stub satisfies both. See `.reports/accountability-ensurance.md`
A1; that is a false green and it is the most serious thing in this round.
