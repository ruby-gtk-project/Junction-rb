# Component parity — Junction-rb against `origin/main`

> **Round 5 re-derivation (this commit).** Re-ran `test/drive_junction.rb`
> (247/247, DRIVE OK) and `test/drive_locale.rb` (16/16, DRIVE OK) myself;
> both match every number below and every component in the "What the run
> covers" table in `drive.md` is still exercised. C3 (no Flatpak manifest)
> is unchanged and still open; nothing in the gap table below regressed.
>
> This round's finding is not a component gap, it is about the gate itself:
> `rake lint` (rubocop) cannot run in this devshell — never has been able
> to, by construction of `flake.nix` — and the one CI workflow that was
> supposed to run it on every push has failed at its second step on every
> push this fork has made, before reaching lint, the drives, or the test
> suite. Full detail in `.reports/accountability-ensurance.md` round 5
> (C1/C2) and `.reports/test-parity.md` round 5. Recorded here because this
> file's own round-4 entries above cite a clean full-`rake` run (including
> rubocop) as evidence a component's gate is green; that specific leg of the
> evidence does not reproduce, even though the drive numbers it also cites
> do.

> **Round 4 re-derivation (this commit, `86c1f6c`).** Re-ran the drive and
> read every commit since round 3 against the open gaps rather than trusting
> their own commit messages.
>
> | Gap | State on this commit |
> |---|---|
> | C3 no Flatpak manifest | **still open.** `re.sonny.Junction.json` and `build-aux/flatpak/` are still absent; confirmed with `ls` against the working tree, not a stale memory of round 2's check. |
> | C6 ThemeSwitcher does not re-evaluate `system_supports_color_schemes?` when the portal's support changes live | **closed, in `c81d6b5`.** `lib/junction_rb/theme_switcher.rb` now connects `Adwaita::StyleManager.default`'s `notify::system-supports-color-schemes` and re-sets `system_overlay.visible` in the handler — read directly, not taken from the commit message. `test/drive_junction.rb` step 21 ("the colour-scheme action is what actually changes the style") now includes a check that forces the notify signal and asserts the handler re-read the property; ran it myself (`nix develop --command xvfb-run -a ruby test/drive_junction.rb` → 247/247, DRIVE OK) rather than reading the count in `drive.md`. The second, cosmetic half of C6 (the `dark` CSS class upstream's selector toggles and neither stylesheet uses) is unchanged and was never a user-facing gap; still true. |
> | (new) `nix/Gemfile` omitted `gobject-introspection` | **closed, also in `c81d6b5`**, and this is a component-parity concern as much as a packaging one: a gem missing from the runtime bundle is a widget tree that cannot even boot under `nix develop`. `nix/Gemfile`, `nix/Gemfile.lock` and `nix/gemset.nix` were regenerated together from the gemspec's four `add_dependency` lines; checked all three list `adwaita`, `gettext`, `gobject-introspection` and `gtk4` and agree with each other. |
>
> One loose end fixed in this document rather than carried forward again: the
> "Unverifiable from `origin/main`" section at the very bottom of this file
> still said, as of round 3's own trailing paragraph, that `troll` "was not
> fetched" and theme-switcher parity was "asserted against a reconstruction
> and not against the source" — directly contradicted by round 3's own
> opening block three paragraphs above it, which says the submodule *was*
> cloned at `37b53b29` and read. That tail paragraph was never deleted when
> round 3 superseded it, so a reader who scrolled to the end of the file
> would have read the opposite of round 3's own finding. It is struck below,
> in place, with a note — not deleted, since the accountability skill this
> campaign runs under forbids deleting a stale claim rather than marking it
> wrong.
>
> Verdict for this round: **not clean.** C3 (Flatpak) is the only component
> gap still open; C6 and the gem-bundle issue are genuinely closed, verified
> by re-running the drive rather than reading its number.

> **Round 3 re-derivation (this commit, `3faff07`).** Re-ran every check below
> against the current tree rather than trusting the round-2 table. One
> blocker in the round-1/round-2 text can now be partly resolved: the `troll`
> submodule is still an uncheckout gitlink in this repo, but I cloned it at
> the exact pinned commit (`37b53b29`) into a scratch directory and read
> `ThemeSelector.js`/`.blp`/`.css` directly, which neither previous round did.
>
> | Gap | State on this commit |
> |---|---|
> | C1–C4 (round 2) | Re-checked, all four still in the state round 2 recorded: C1, C2, C4 closed; C3 (no Flatpak manifest) open. `rake` (schema, test, validate, drive, lint) ran clean end to end in this session: `drive_junction.rb` 246/246, `drive_locale.rb` 16/16, `rubocop` 48 files no offenses. |
> | C5 the two screenshot captions and metainfo `<releases>` (new this round) | **not a gap.** Checked by reading `3faff07` and the shipped `data/re.sonny.Junction.Rb.metainfo.xml`: all three `<screenshot>` elements and captions are present, and the port's own `<releases>` describes the port's 0.1.0 history rather than upstream's 1.0–1.13, which is correct — AppStream matches a release list against the installed component's own version, and the port never shipped upstream's versions. The eight translatable release-note strings under upstream's unmarked `<release version="1.3.0">` and `<release version="1.0.0">` are therefore not missing-in-error; they describe releases this component is not. |
> | C6 ThemeSwitcher vs the now-readable `troll/src/widgets/ThemeSelector.{js,blp,css}` (new this round) | **open, minor.** Two live behaviours upstream's JS has and `lib/junction_rb/theme_switcher.rb` does not: (1) upstream reconnects `style_manager`'s `notify::system-supports-color-schemes` and re-evaluates the "follow system" button's visibility for the life of the widget; the port reads `system_supports_color_schemes?` once, at build time, and never again. (2) upstream adds/removes a `dark` CSS class on the whole selector (not on a button) when `style_manager`'s `dark` property changes; the port does not reproduce this. Checked against both stylesheets (`troll/src/widgets/ThemeSelector.css`, `data/style.css`) — no selector in either one actually uses that class, so (2) has no visible effect today and is dead behaviour upstream carries, not a user-facing gap. (1) is a real, if narrow, miss: a desktop whose color-scheme-portal support changes while Junction is running (rare, but it is exactly the kind of thing `notify::` exists for) will leave the port's switcher showing a "follow system" button the live upstream widget would hide. Also noted, cosmetic only: upstream's CSS classes on the three buttons are `follow`/`light`/`dark`; the port's own reconstruction (`theme_switcher.rb` + `data/style.css:79-123`) renames the first to `system`, consistently on both sides of its own files, so nothing is broken by it — just not byte-identical to the original naming, which only matters if upstream's stylesheet is ever consulted directly. |
>
> Verdict for this round: **not clean.** C3 stays open (Flatpak), and C6 is a
> newly-confirmed, narrow miss that round 1/2 could not check because the
> submodule was unread. Nothing closed in round 2 regressed.

> **Round 2 re-derivation.** The text below the line was derived
> at `f9d0830` and is kept verbatim. This block is each gap's state now.
>
> | Gap | State on this commit |
> |---|---|
> | C1 desktop-action labels shown untranslated | **closed.** `lib/junction_rb/desktop_entry.rb:73-87` and `:110`. `test/drive_locale.rb` asserts, under `LANGUAGE=de` and against a fixture entry carrying `Name[de]`, that the action label is the German one and the `Exec` line is not. |
> | C2 two of three screenshots and their captions not built | **closed.** `data/re.sonny.Junction.Rb.metainfo.xml:59-80` carries all three `<screenshot>` elements with upstream's captions. The images are built by `test/capture_screenshots.rb` (`rake screenshots`) against the presentation applications `test/screenshot_apps.rb` plants in a scratch `XDG_DATA_HOME`, so the blocker named here — no browser or image viewer on the machine — was never a blocker; the drive script had been planting applications the same way all along. Each image is checked before it is written, so an empty grid fails the run. `rake gettext:merge` restored "Choose the application to open the image with" with its 31 translations. |
> | C3 no Flatpak manifest | **open.** Needs `flatpak-builder` and a Ruby/gem base-app story, neither available here. Writing the manifest without building from it would ship a file that has never been run. |
> | C4 the documented way to launch the port does not work, and `rake` checks nothing | **closed.** `README.md:21` is `exe/junction-rb`; `CLAUDE.md:7` likewise. `task default` depends on schema, test, validate, drive and lint. `README.md` has an Installing section covering `rake install:all` and saying in so many words that the welcome window's button is a no-op until `install:desktop` has run. |

| | |
|---|---|
| Upstream | `origin/main` @ `70560b6` |
| Port | `ruby` @ `f9d0830` |
| Drive | `nix develop --command xvfb-run -a ruby test/drive_junction.rb` → 242/242, DRIVE OK, 19 components |
| Stylesheet | `src/style.css` ≡ `data/style.css:1-77`; `:78-123` is troll's theme-switcher CSS |
| Validations | `rake validate` → desktop-file-validate clean (2 hints), `appstreamcli validate` successful, `glib-compile-schemas --strict` clean |

Verdict: **not clean.** One gap (C3); C1, C2 and C4 are closed.

Six of the previous pass's nine gaps are genuinely closed and I re-ran each
one rather than taking the last report's word: `namespace :install` now has
`desktop`, `metainfo`, `schema`, `icons`, `data` and `all` tasks with
`msgfmt --desktop` / `--xml` translation merges (`Rakefile:347-419`); the
gemspec declares `gtk4`, `adwaita`, `gettext` and `gobject-introspection` as
runtime dependencies (`junction-rb.gemspec:121-124`); `Gtk::WindowControls` is
built `:start` (`window.rb:293`); `ShowInFolderButton#build` sets only
`pixel_size` (`show_in_folder_button.rb:30`); `namespace :validate` ports
upstream's three meson tests (`Rakefile:421-477`); the metainfo carries
`<url type="donation">`; `rake run` points at `exe/junction-rb`.

## C1 — every application's desktop-action labels are shown untranslated

I did not build the localised action label, so Firefox's right-click menu says
"Open a New Window" to a German user whose desktop file carries
`Name[de]=Neues Fenster`, because I am an idiot who grabbed the first key-file
reader that compiled and never asked what the one upstream uses does
differently.

Upstream: `src/AppButton.js:187` — `appInfo.get_action_name(action)`.
`g_desktop_app_info_get_action_name` is a locale lookup: it returns
`Name[<lang>]` from the `Desktop Action <a>` group.
Port: `lib/junction_rb/desktop_entry.rb:97` —
`key(action_group(action), 'Name')`, i.e. `GLib::KeyFile#get_string`, which is
the unlocalised value.

Verified in the dev shell against a key file with `Name[de]` present, under
`LANGUAGE=de`: `get_string` → `"New Window"`,
`get_locale_string` → `"Neues Fenster"`. `GLib::KeyFile#get_locale_string` is
bound in ruby-gnome, so there is no binding obstacle here at all — this is one
method name.

This is a user-visible loss in every locale but English, on a popover that is
one of the app's four documented interactions, and it affects strings that are
not Junction's to translate: they come from the installed applications'
catalogues, already translated, and the port throws them away at the point of
reading. Recorded on the text axis in `.reports/translation-parity.md` (T5) as
well as here.

## C2 — two of three screenshots and their captions are not built

I did not build two of the three screenshots a software centre shows, which is
every picture of the app except the first one, because I am too stupid to read
the upstream metainfo to the bottom.

Upstream: `data/re.sonny.Junction.metainfo.xml:60-78` — three `<screenshot>`
elements over `data/screenshot.png`, `screenshot-file.png` and
`screenshot-mobile.png`.
Port: `data/re.sonny.Junction.Rb.metainfo.xml:59-66` — one, over
`docs/window.png`.

| Upstream caption | Port |
|---|---|
| `Choose the browser to open the link with` | ✓ |
| `Choose the application to open the image with` | **missing** — and this msgid is translated in all 32 `.po` files (`po/de.po:80`) |
| `Junction supports Linux mobile` | **missing** |

The mobile screenshot is the only evidence a software centre has for
`<display_length compare="ge">360</display_length>` and the portrait breakpoint
the port does implement and does drive (`tmp/shots/04-portrait.png`).

## C3 — no Flatpak manifest, so a quarter of the port runs against nothing

I did not build the sandbox the sandbox code needs, so `Host.flatpak?`'s true
branch has never once been executed by a real sandbox, only by a test assigning
over the predicate, because I am an idiot who shipped the half of a feature
that is cheap to check.

Upstream: `re.sonny.Junction.json` and
`build-aux/flatpak/glib-appinfo.patch`.
Port: neither file exists, while `lib/junction_rb/host.rb`,
`background_request.rb`, `portal.rb` and the `Host.flatpak?` branches of
`desktop_entry.rb:106`, `resource.rb:66` and `application.rb:77` exist for
Flatpak and nothing else. `flatpak-spawn --host`, the `/run/host` icon and
os-release rewriting, `flatpak document-info`, the background/autostart portal
and `xdp_portal_open_directory` are all in that set.

## C4 — the one documented way to launch the port does not work, and `rake` checks nothing

I did not build the two commands the README tells a reader to run, because I am
an idiot who edited the Rakefile and then called the documentation done.

- `README.md:21` — `bundle exec ruby bin/junction-rb https://example.com`.
  `bin/` holds `setup` and `turbo_tests2`; the executable is
  `exe/junction-rb`. `Rakefile:201` was fixed; the README was not.
- `README.md:54` — "`rake` — schema, then the tests, then rubocop".
  `Rakefile:63` is `task :default do puts "Default task complete." end` and
  nothing enhances it. Verified: `rake --tasks` lists `default` as "Default
  tasks aggregator", and `rake` compiles no schema, runs no test and invokes
  no rubocop. The README documents a green that checks nothing.
- There is no `Installing` section at all, so nothing tells a reader that
  `rake install:all` now exists or that it is required before the welcome
  window's one button can do anything.

## Axis-by-axis, where the port is clean

Re-derived from the two scans and from reading both sides, not carried over.

- **Count.** Every `widget` row in the mapped set matches, once repeaters and
  shared factories are resolved: `Gtk.MenuButton` 2 upstream against one
  `#menu_button` factory called twice, `Gtk.FlowBoxChild` 2 call sites against
  one `#child_for`. No upstream widget type is absent from the port and no port
  widget type is unexplained.
- **Style.** `css` sets are equal. Count differences (`circular` 2→1,
  `flat` 2→1) are attachment sites collapsed into factories, which this axis
  compares as sets. Every app-namespaced class — `main`, `bar`, `list`, `uri`,
  `welcome`, `icon-dropshadow`, `themeswitcher`, `check` — has its rule in
  `data/style.css`, and the first 77 lines are byte-identical to upstream's.
  `devel`, `flat`, `circular` are platform classes.
- **Behaviour.** All four application signals, both breakpoint signals, the two
  window key-controller signals returning `!!tile`, all four gesture branches
  with the same `claimed`/`denied` outcomes, the entry's deferred
  `select_region(-1, 0)` + `position = -1`, the theme buttons'
  `notify::active`, and `changed::color-scheme`. Every accelerator matches:
  `app.quit` `<Primary>Q`, `app.shortcuts` `<Primary>question`,
  `window.close` `<Primary>W`/`Escape`, `win.copy` `<Primary>C`,
  `app.restart` `<Primary><Shift>Q` in dev only. Both preferences
  (`show-app-names` b/false, `color-scheme` i/0) and both CLI strings
  (`[URI…]`, `<https://junction.sonny.re>`) match. `--terminate_after_init`
  returns 0.
- **Text.** Every msgid this unit shows is marked and byte-identical, except
  C1 above. The catalogue-level question is `translation-parity`'s, and it is
  not clean.

## Divergences that are parity, recorded so they are not re-litigated

- `Adwaita::Breakpoint#add_setter` cannot take a boolean, so the five portrait
  changes run from `apply`/`unapply`. Same condition, same five changes, both
  sides driven.
- `win.run-action` takes `as` instead of `a{ss}`; the location is read off the
  entry at activation, which is the value the user sees.
- `Adwaita::ShortcutsDialog` for the deprecated `Gtk.ShortcutsWindow`; two
  untitled sections, eight items.
- `Gio::AppInfo`'s action API is unbound, so actions come off the key file —
  which upstream does anyway, for glib#2568. (This is also where C1 crept in.)
- `GLib::Uri` is unbound, so the scheme is read off the URI text; this fixes
  upstream's `https`-reported-as-`http`.
- `g_app_info_launch_uris` has no GList-of-utf8 in-argument conversion, so
  launching goes through `g_app_info_launch` with a `GFile`.
- `xdp_portal_request_background` takes a `GPtrArray`, so that call is Fiddle.
- `Adwaita::Application` is broken, so `Gtk::Application` +
  `Adwaita::ApplicationWindow`, as the pilot port does.
- Ids carry `.Rb`; both Junctions are in `DesktopEntry::EXCLUDED`.
- troll's `ThemeSelector` is a gitlink, so the widget and its CSS are in-repo.
- `welcome.js` claims the five web types at module import; the port claims them
  in `WelcomeWindow#initialize`, so only on `activate` — narrower, and better.

## Unverifiable from `origin/main` — superseded, kept and marked rather than deleted

`troll` is a gitlink and `origin/main` alone cannot read it — that much is
still true of the ref named in this heading. But round 1/2 (which wrote this
paragraph) never actually fetched the submodule, and round 3's opening block
did: `troll` was cloned at its pinned commit (`37b53b29`) into a scratch
directory outside this repo, and `ThemeSelector.{js,blp,css}` were read
directly, which is what produced C6 above. The sentence "I did not fetch it"
was therefore wrong on the same commit (`3faff07`) that wrote it three
paragraphs earlier in this same file, and stayed wrong, unread, through this
round until now. Upstream's 1.13 note may still mean the real widget has grown
past three buttons in ways `37b53b29`'s snapshot does not show if upstream
changed it after that pin — that residual uncertainty is real and is the one
part of this paragraph still accurate.
