# Test parity — Junction-rb against `origin/main`

Upstream suite: `test/util.test.js`, run by `troll/tst`. Four tests,
~40 assertions, covering `parse`, `readResource`, `prefixCommandLineForHost`
and `getIconFilename`. Upstream additionally registers three validation tests
in `data/meson.build`.

Port suite: eight files listed in `Rakefile:184-198`, run one process each by
`rake test`.

Verdict: **not clean** — but the body of upstream's own suite is now fully
ported. The remaining gaps are upstream's *build-time* tests and the fact that
the port's suite cannot be executed.

## Upstream's four unit tests: ported in full

| # | Upstream test | Port | State |
|---|---|---|---|
| 1 | `util.test.js:19` `parse` (10 assertions) | `test/resource_test.rb:150-205` (12 checks on `Resource.parse_location`) | **ported** |
| 2 | `util.test.js:35` `readResource` (11 inputs) | `test/resource_test.rb:32-148` | **ported** |
| 3 | `util.test.js:103` `prefixCommandLineForHost` (4 assertions, both sandbox states) | `test/desktop_entry_test.rb:224-241` | **ported** |
| 4 | `util.test.js:128` `getIconFilename` (8 assertions) | `test/desktop_entry_test.rb:245-283` | **ported** |

Bijection holds four for four, and each pair now tests the same thing:

- **`parse`** — every one of upstream's ten inputs is asserted on the same
  expected value, including the five the previous pass flagged: `~/` collapsing
  to `$HOME`, `/` → `file:///`, `/foo/` keeping its trailing slash,
  `mailto:foo@bar.com` passing through untouched, and `http://example.com`
  passing through untouched.
- **`readResource`** — all eleven inputs, including `/`, `x-junction:///`,
  `file:///etc/os-release`, `x-junction:///etc/os-release`, `x-junction://~`,
  `x-junction://~/.config` (both hitting the `Gio::File.parse_name` branch the
  previous pass found dead), and a non-existent path falling back to
  `application/octet-stream` through the `query_info` rescue.
- **`prefixCommandLineForHost`** — upstream's exact command line
  `foo --bar hello='world' something="wow"` in both sandbox states, plus the
  no-double-prefix case in both. The seam is `Host.flatpak = true/false`
  (`host.rb:33-39`), which is the direct analogue of upstream assigning over
  `Xdp.Portal.running_under_flatpak`, and it is reset to `nil` afterwards with
  a check that the question goes back to libportal.
- **`getIconFilename`** — all four paths (`/usr/share`, `/etc/foo`,
  `/home/foo`, `/opt/foo`) × both sandbox states, pinning that only `/usr/` and
  `/etc/` are rewritten.

## Gap 1 — upstream's three build-time tests are not ported

`data/meson.build` registers these as `test()`s, so upstream's CI fails on a
malformed data file:

| Upstream test | Command | Port |
|---|---|---|
| "Validate desktop file" | `desktop-file-validate` | **missing** |
| "Validate appstream file" | `appstreamcli validate --no-net --explain` | **missing** |
| "Validate schema file" | `glib-compile-schemas --strict --dry-run` | **missing** — `rake schema` compiles without `--strict` |

These are the tests that would catch the data-file problems in
`.reports/component-parity.md` (P4, P7) and anything else wrong with a metainfo
that has been substantially rewritten for the port.

## Gap 2 — the suite cannot be executed, here or in CI

- **In this checkout.** `rake` is not in the bundle and `gtk4` / `adwaita` are
  not installed, so every file dies at `lib/junction_rb.rb:3` with
  `LoadError: cannot load such file -- gtk4`; `nix develop -c bundle exec`
  fails the same way. `nix/Gemfile.lock` pins `gtk4 (4.3.9)` and
  `adwaita (4.3.9)`, so the intent is there, but the environment this audit
  runs in cannot provision it. **This census is therefore static: no assertion
  in the port's suite has been observed to pass.**
- **In CI.** `.gitlab-ci.yml` is the stock kettle template: it sets
  `K_SOUP_COV_*` and runs the RSpec-based `rake` defaults. There is no `spec/`
  directory, and nothing in the file invokes `rake test` or any of the eight
  files under `test/`. There is no `.github/workflows/` at all. Upstream runs
  its suite from `.husky/pre-push` and `Makefile`; the port's suite runs only
  when a human types `rake test`.

Fix: a CI job (or a `rake default` entry) that runs `rake test` in the nix dev
shell, plus the three validations above.

## Gap 3 — `rake test` depends on `gettext:mo:update`, which can silently stub out

`Rakefile:184` makes `test` depend on `gettext:mo:update`, and
`Rakefile:248-253` replaces that task with a `warn`-only stub when the gettext
gem is missing. So on a machine without the gem the suite still reports success
while the catalogues it claims to validate were never compiled. Upstream's
`i18n` dependency is hard; this one is not.

## Port tests with no upstream counterpart

Additions, not parity failures, recorded so the census is complete in both
directions. Most pin the ruby-gnome divergences `PORTING.md` records, which is
exactly where a port needs tests upstream does not have:

| File | Covers |
|---|---|
| `test/cli_test.rb` | `--terminate_after_init`, option context strings, argv[0] handling |
| `test/portal_test.rb` | `BackgroundRequest` through Fiddle; `Host.open_directory` both outcomes via the `Host.portal=` seam |
| `test/window_test.rb` | the widget tree, the breakpoint, the actions, the 1…9 shortcuts, driven through `GtkDriver` |
| `test/url_test.rb` | scheme detection, `https` vs `http`, entry round-tripping |
| `test/welcome_test.rb` | the welcome window, the install button, the success/error routing |
| `test/settings_test.rb` | the schema, both keys, the stateful actions |
| `test/desktop_entry_test.rb` (first half) | discovery, exclusions, key-file and desktop-action parsing |

## Mechanical notes

- `spec/` is gone and `.rspec`/`spec_helper.rb` with it — the
  configured-but-empty suite the previous pass flagged no longer exists.
- `test/gtk_driver.rb` renders offscreen, so no display server is needed; the
  harness itself is sound and `exit`s non-zero on any failed check.
- Each test file is its own process with its own `FAILURES` array and its own
  `exit`, so one crashing file does not mask the others — but `rake test` uses
  `sh`, which aborts the task on the first non-zero exit, so a failure in
  `resource_test.rb` hides the seven files after it.
