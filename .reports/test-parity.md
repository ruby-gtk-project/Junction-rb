# Test parity — Junction-rb against `origin/main`

Upstream suite: `test/util.test.js`, run by `troll/tst`. Four tests.
Port suite: seven files run by `rake test`, 170 `check(...)` assertions.

Verdict: **not clean.** The port has far more assertions than upstream, but
two of upstream's four tests are only partially ported and the cases upstream
specifically pinned are the ones missing. Volume is not parity.

| # | Upstream test | Port test(s) | State |
|---|---|---|---|
| 1 | `test/util.test.js:19` `parse` | `test/resource_test.rb:102-125` (6 `check`s on `Resource.parse_location`) | **gap** — partial |
| 2 | `test/util.test.js:35` `readResource` | `test/resource_test.rb:32-98` (19 `check`s) | **gap** — partial |
| 3 | `test/util.test.js:103` `prefixCommandLineForHost` | `test/desktop_entry_test.rb:188-194` (2 `check`s) | **gap** — partial |
| 4 | `test/util.test.js:128` `getIconFilename` | `test/desktop_entry_test.rb:196` (1 `check`) | **gap** — partial |

Counts: upstream 4, port 4 mapped — but all four are partial, so the bijection
holds and claim 3 ("each pair tests the same thing") fails four times out of
four.

## 1 — `parse` → `Resource.parse_location`

Upstream asserts ten inputs. The port asserts six, and five of upstream's are
absent:

| Upstream assertion | Port |
|---|---|
| `parse("~")` → `file://$HOME` | `check('a tilde is expanded')` only asserts `start_with?('file:///')`, not the value |
| `parse("~/")` → `file://$HOME` | **missing** — the trailing-slash collapse is untested |
| `parse("~/foo")` → `file://$HOME/foo` | ported |
| `parse("/")` → `file:///` | **missing** |
| `parse("/foo/")` → `file:///foo/` | **missing** — the trailing slash must survive |
| `parse("/foo")` → `file:///foo` | ported (`/tmp/x`) |
| `parse("/foo/bar")` → `file:///foo/bar` | ported |
| `parse("mailto:foo@bar.com")` unchanged | **missing** — and `mailto:` is the scheme upstream's own FIXME is about |
| `parse("http://example.com")` unchanged | **missing** |
| `parse(".../query?q=random%2Fword")` unchanged | ported |

Behaviour still owed: a user who types `~/`, `/`, a directory path with a
trailing slash, or a `mailto:` address into the URI bar gets the right URI
handed to the application they pick.

## 2 — `readResource` → `Resource`

Upstream asserts the whole `{resource, scheme, content_type}` triple over
eleven inputs. The port's 19 checks cover scheme, content type, entry text and
`show_in_folder?` separately — broader in some directions, and missing four of
upstream's inputs entirely:

| Upstream input | Port |
|---|---|
| `/` | **missing** (the port uses a tmpdir, never the root) |
| `x-junction:///` | **missing** — the bare-path wrap is untested |
| `file:///etc/os-release` | **missing** |
| `x-junction:///etc/os-release` | **missing** |
| `x-junction://file:///etc/os-release` | ported in spirit (`x-junction://file:0//tmp/x`) |
| `x-junction://~` | **missing** — `Resource.parse_wrapped`'s `start_with?('~/')` branch, i.e. `Gio::File.parse_name`, is never executed by any test |
| `x-junction://~/.config` | **missing** — same branch |
| `https://example.com/` | ported |
| `http://example.com/foobar?hello=world` | ported |
| `x-junction://http://example.com/foobar?hello=world` | ported in spirit (https variant) |
| non-existent path → `application/octet-stream` | **missing** — `resource_test.rb:69-77` writes four real bytes to a real file, which exercises sniffing, not the `query_info` rescue in `Resource#query_content_type:84` |

Behaviour still owed: a `x-junction://~/…` link from a web page opens the file
in the user's home directory; a link to a path that does not exist still puts
up a chooser instead of an error.

## 3 — `prefixCommandLineForHost` → `Host.prefix_command_line`

Upstream monkey-patches `Xdp.Portal.running_under_flatpak` to `() => true` and
asserts the sandboxed branch produces
`flatpak-spawn --host foo --bar hello='world' something="wow"`, then asserts an
already-prefixed command is still not double-prefixed under the sandbox. The
port tests only the two host-side cases
(`desktop_entry_test.rb:188`, `:192`) and never sets `Host.flatpak?` true.

So the branch that matters — the one that exists *because* the sandbox needs it
— has no coverage on either `prefix_command_line` or anything downstream of it
(`DesktopEntry#launch`'s `host_app_info`, `Host.real_path`,
`Application#claim_web_handler`).

Behaviour still owed: inside a Flatpak, picking an application actually
launches it on the host rather than inside the sandbox.

## 4 — `getIconFilename` → `Host.host_path`

Upstream asserts eight cases: `/usr/share/…`, `/etc/foo/…`, `/home/foo/…` and
`/opt/foo/…`, each with `running_under_flatpak` false and true, pinning that
only `/usr/` and `/etc/` are rewritten to `/run/host/…`. The port has one
assertion, the `/usr/` case with flatpak off
(`desktop_entry_test.rb:196`, named "a host path is only rewritten inside a
sandbox" — which is precisely the claim it does not test).

Behaviour still owed: inside a Flatpak, an application whose icon is a
`Gio::FileIcon` under `/usr` or `/etc` shows its icon rather than a blank tile,
and one under `/home` or `/opt` is not broken by a spurious `/run/host` prefix.

## Port tests with no upstream counterpart

These are additions, not parity failures, and most of them are good — they pin
the three ruby-gnome bugs `PORTING.md` records. Recorded so the census is
complete in both directions:

`test/cli_test.rb` (7), `test/portal_test.rb` (14),
`test/window_test.rb` (46), `test/url_test.rb` (23),
`test/welcome_test.rb` (21), and the discovery/key-file half of
`test/desktop_entry_test.rb` (~28).

## Mechanical findings about the suite itself

- **Nothing stubs `Host.flatpak?`.** It is `Xdp::Portal.running_under_flatpak`,
  a module function on an introspected class, so every sandbox branch in
  `host.rb`, `desktop_entry.rb` and `application.rb` is dead to the suite.
  Upstream solved this by assigning over the function; the port needs the
  equivalent seam (a `Host.flatpak?` that reads a memoised ivar a test can set,
  or `define_singleton_method`).
- **`spec/` is empty.** `.rspec` and `spec/spec_helper.rb` exist, `rake test`
  does not run them, and there is not one spec file. Either wire it up or
  remove it; a configured-but-empty suite reads as coverage that is not there.
- **The suite cannot currently run.** Every test file requires
  `lib/junction_rb`, and five of the seven reach `Settings`, which raises
  `NameError: uninitialized constant JunctionRb::SETTINGS_PATH` (see
  `.reports/component-parity.md` P0). Parity cannot be measured by execution
  until that is fixed; this census is static.
