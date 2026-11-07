# Translation parity — Junction-rb against `origin/main`

> **Round 4 re-derivation (this commit, `86c1f6c`).** Spot-checked rather
> than re-censused in full, because nothing in the four commits since round 3
> touches a marked string, `po/`, `locale/`, `POTFILES` or the Rakefile's
> gettext tasks — read each of the four commits' diffs to confirm that before
> trusting the shortcut.
>
> Re-verified by hand, against the live tree, the two claims round 3 left
> open:
>
> - **T2, the 8 untranslated strings.** Grepped all eight msgids
>   (`Main Menu`, `Show App Names`, `Open Location`,
>   `View File in File Manager`, `Run Junction in the background.`,
>   `Light Style`, `Follow System Style`, `Dark Style`) against `po/de.po`.
>   Seven have `msgstr ""`. `Show App Names` carries `#, fuzzy` over
>   `#| msgid "Show names"` with `msgstr "Namen anzeigen"` — a fuzzy entry,
>   which both GNU `msgfmt` and the `rmsgfmt` gem exclude from the compiled
>   `.mo`, so it still renders English at runtime exactly as round 3 claimed.
>   Still 8 strings with no human translation, in all 32 languages, not
>   invented here.
> - **T3, the restored screenshot caption.** `Choose the application to open
>   the image with` has a non-empty `msgstr` in `po/de.po`
>   ("Programm wählen, mit dem das Bild geöffnet werden soll"); `Junction
>   supports Linux mobile` has `msgstr ""`, matching round 3's claim that one
>   of the two restored captions came back translated and the other, being
>   new to the catalogue, did not.
>
> Also re-verified: `nix/Gemfile`'s regeneration in `c81d6b5` touches
> `gobject-introspection`, not `gettext` or `rmsgfmt`, so it changes nothing
> this ledger tracks — confirmed by reading the diff rather than assuming a
> packaging commit is out of scope by name alone.
>
> One stale claim found and worth recording even though it belongs to a
> different document: `PORTING.md`'s "Open gaps" item 4 still says
> "`nix/Gemfile` is out of step with the gemspec's runtime dependencies," and
> that stopped being true at `c81d6b5` — `nix/Gemfile` now lists all four of
> `adwaita`, `gettext`, `gobject-introspection` and `gtk4`, matching the
> gemspec exactly, and `nix/Gemfile.lock`/`nix/gemset.nix` agree. This is not
> a translation-parity gap; it is logged here because this document is where
> the check that disproves it was run, and in full in
> `.reports/accountability-ensurance.md` round 4, which is where a stale
> ledger claim belongs.
>
> Verdict for this round: unchanged from round 3. T2 (8 strings) remains open
> and is not closable by the port; everything else round 3 called closed is
> still closed.

> **Round 3 re-derivation (this commit, `3faff07`).** Re-censused rather than
> re-read. Pulled `origin/l10n` (`po/`, 32 languages, `re.sonny.Junction.pot`
> dated 2022-10-15) and censused `origin/main`'s current `src/`/`data/` with
> `translation-parity/scripts/msgid-census.sh` to get the message set as it
> is *today*, not as the 2022 `.pot` snapshot has it — the two disagree on
> purpose, because upstream has shipped UI copy changes since the l10n branch
> was last synced (`"Choose the application to open with"` → `"Choose the app
> to open with"`, `"Show a hint for insecure link"` → `"…insecure links"`,
> `"Middle click to open in multiple applications"` → `"Middle Click or Ctrl +
> Click to open in multiple applications"`, among others). Diffing the port's
> `po/re.sonny.Junction.pot` against the *stale* l10n `.pot` instead of
> against current `main` source would have reported all three as rewordings;
> checked against current `main`, the port's wording is byte-identical to
> each. Every one of the 39 marked strings in `src/*.js`/`*.blp` plus
> `data/*.desktop`/`data/*.metainfo.xml` that the census can see on current
> `main` was checked against `po/re.sonny.Junction.pot` by hand, not by a
> count: `About Junction`, `Application chooser`, `Choose the application to
> open the image with`, `Choose the app to open with`, `Choose the browser to
> open the link with`, the `Choosy;…` keywords, `Copy to Clipboard`,
> `Discard and close`, `Edit the URL before opening`, `Features:`, `Junction`,
> `Junction supports Linux mobile`, `Keyboard navigation`, `Keyboard
> Shortcuts`, `Linux Mobile support`, `Main Menu`, `Middle Click or Ctrl +
> Click to open in multiple applications`, `Open Location`, `Open with
> application at position`, `Open with selected application[ and stay
> active]`, `Quit`, `Run Junction in the background.`, `Select next/previous
> application`, `Set Junction as default for Web`, `Show a hint for insecure
> links`, `Show App Names`, `Show the location before opening`, `Supports
> desktop actions on right click`, `Test Junction`, `This site has no
> security…`, `translator-credits`, `View File in File Manager` — every one
> is in `po/re.sonny.Junction.pot`, byte-identical. `Main Menu` and `This
> site has no security…`, the two longest to grep for, were checked twice
> after an early pass's `grep` truncation made it look like they were
> missing; they are present (`po/re.sonny.Junction.pot:92,105`).
>
> `po/LINGUAS` matches `origin/l10n`'s exactly, 32 entries; 32 `.po` files
> present; 32 compiled `.mo` under `locale/`.
>
> `data/re.sonny.Junction.metainfo.xml`'s current, un-ported-from text is
> not a gap — see `.reports/component-parity.md` C5: upstream now marks its
> own feature-list `<description>` `translatable="no"`, and its `<releases>`
> history describes upstream's own 1.0–1.13, not this component's 0.1.0. T3
> below, from round 1, is resolved by that reading: it is closed, not merely
> re-scheduled.
>
> Nothing new is open this round. T2 (8 untranslated msgids pending human
> translators) is unchanged and is not a gap this port can close by itself —
> re-confirmed: still 8 strings showing in English in all 32 languages,
> still because no translator has reached them yet, still not invented here.
>
> | Gap | State on this commit |
> |---|---|
> | T1 `rake gettext:mo:update` empties all 32 catalogues | **closed.** `GetText::Tools::Task` is gone. `gettext:mo:compile` (`Rakefile:399-416`) runs GNU `msgfmt --check --check-format` on each donated `po/<lang>.po` into `locale/<lang>/LC_MESSAGES/`, and `rake test` no longer depends on it. |
> | T2 eight displayed strings have no msgid | **half closed.** All eight are now in `po/re.sonny.Junction.pot` and in all 32 `po/<lang>.po` (`rake gettext:pot`, `rake gettext:merge`). `Show App Names` carried over from the retired `Show names` as fuzzy; the other seven are untranslated. msgfmt excludes fuzzy, so all eight still display in English. I have not invented the words. |
> | T3 a msgid with 32 translations deleted by dropping a screenshot | **open.** Tied to P4: the two `<screenshot>` elements still need images taken on a machine with real applications installed. `PORTING.md` says why at length. |
> | T4 desktop-action labels bypass localisation | **closed.** `lib/junction_rb/desktop_entry.rb:73-87` adds `#locale_key` and `#action_name` uses it; `#action_exec` still uses `#key`, because an `Exec` line must not be localised. Driven under `LANGUAGE=de` in `test/drive_locale.rb`. |
> | T5 `po/POTFILES` asserts coverage the extraction does not have | **closed.** `gettext:pot` reads POTFILES and nothing else, extracting the Ruby files with `rxgettext` and the desktop entry, gschema and metainfo with `xgettext --language=Desktop` / the ITS rules. `gettext:potfiles` fails when a source grows a `_()` without being listed, and `gettext:check` (which `rake test` depends on) depends on it. |
> | T6 no committed `.pot` | **closed.** `po/re.sonny.Junction.pot`, 39 messages, regenerated by `rake gettext:pot`. |
>
> New this round: the message set shrank from 61 msgids to 39 because
> `msgmerge` retired the spellings the port stopped using (`Show names`,
> `Reveal in Folder`, `View All`, `Middle click to open in multiple
> applications`). No msgid the port emits lost a translation — `de` was 21
> translated before the merge and is 21 after, and the 40 entries that
> vanished from `locale/de/LC_MESSAGES/re.sonny.Junction.mo` were msgids
> nothing looked up.

| | |
|---|---|
| Upstream | `origin/main` @ `70560b6` (no `po/` on this ref; the catalogue lives on `origin/l10n`) |
| Port | `ruby` @ `f9d0830` |
| Domain | `re.sonny.Junction` — upstream's, kept, verified in `lib/junction_rb.rb:51`, the gschema's `gettext-domain`, the metainfo's `<translation>` and `Rakefile:222` |
| Upstream marked messages | 34 keys from `src/*.js`, `src/*.blp` and the three data files (census, `po/` excluded) |
| Port marked messages | 29 keys + 4 `!unresolved` markers, all four resolved by hand to `N_()` constants already in the set |
| Languages | 32 `.po`, 32 `LINGUAS` entries, 32 compiled `.mo` — the sets agree |
| Gaps | 6 |
| Build command | `rake gettext:mo:update` — **and it is the first gap** |

Verdict: **not clean**, and worse than the last pass rather than better. The
previous Gap 1 (no translation merge for the data files) is closed. In its
place, the task that compiles the catalogues now destroys them.

## T1 — `rake gettext:mo:update` replaces all 32 donated catalogues with empty stubs

I did not build the step that compiles the port's own catalogues, I built one
that deletes them, and then I made the test suite depend on it, because I am a
fucking idiot who wired a generator at the thing it was supposed to read.

Reproduced from a clean tree, deterministically:

```
$ git checkout -- locale/ && ls -l locale/de/LC_MESSAGES/re.sonny.Junction.mo
6295 bytes          # committed: the real German catalogue
$ nix develop --command rake gettext:mo:update
$ ls -l locale/de/LC_MESSAGES/re.sonny.Junction.mo
 361 bytes          # header only; msgunfmt prints zero entries
$ nix develop --command msgfmt -o /tmp/de.mo po/de.po && msgunfmt /tmp/de.mo | grep -c msgid
61                  # GNU msgfmt on the same source: 61 entries, 6295 bytes
$ git status --short locale/ | wc -l
32                  # all 32 languages, every one emptied
```

**Cause.** `GetText::Tools::Task` with `task.po_base_directory = PO_DIR`
(`Rakefile:236`) looks for `po/<locale>/<domain>.po`, not for the donated
`po/<locale>.po`. Those files do not exist, so the task *creates* them from the
freshly-extracted `.pot` with every `msgstr` empty — `po/de/re.sonny.Junction.po`,
plus an `.edit.po` and a `.time_stamp` — and compiles those. The 32 donated
files in `po/*.po` are never opened. They are still on disk, untouched and
correct; nothing reads them.

**Consequences, in order of how much they cost.**

1. `rake test` depends on `gettext:mo:update` (`Rakefile:184`), so running the
   suite leaves 32 emptied catalogues in the working tree. A developer who runs
   the suite and commits ships an English-only app in 32 languages. The commit
   looks like 32 binary-file changes and reviews as noise.
2. `junction-rb.gemspec:85` ships `locale/**/*.mo`, so `rake build` after
   `rake test` packages the empty ones.
3. `rake gettext:po:update` — the task the previous report recommended running
   — would write the port's incomplete message set over nothing, because it too
   works on `po/<locale>/`; the donated files are not merged, just bypassed.
   The recommendation was safe only by accident.
4. The untracked `po/<locale>/` directories and `po/re.sonny.Junction.pot` are
   matched by `spec.files`' `po/**/*` glob, so a release built from a dirty
   tree ships 32 empty `.po` files and three stray artefacts per language.

**What is verified good.** With the committed `.mo` in place, delivery works.
Under `LANGUAGE=de`, through the port's own `bindtextdomain`:

```
"Quit"              => "Beenden"
"Copy to Clipboard" => "Kopiere in die Zwischenablage"
"About Junction"    => "Über Junction"
"Test Junction"     => "Junction testen"
"Main Menu"         => "Main Menu"        # T2
"Show App Names"    => "Show App Names"   # T2
"Open Location"     => "Open Location"    # T2
```

So the domain, the `bindtextdomain` path, the `.mo` layout and the lookup are
all correct. The only thing wrong is the step that writes the files — which is
exactly the shape translation-parity's Step 5 warns about: a catalogue that is
100% correct on paper and absent on screen.

## T2 — eight strings the port displays have no msgid in any of the 32 catalogues

Every marker in `lib/` and `exe/`, checked against all 32 `.po` files, and the
three in the middle confirmed on screen above.

| msgid | catalogues | |
|---|---:|---|
| `About Junction`, `Copy to Clipboard`, `Discard and close`, `Keyboard Shortcuts`, `Open with application at position`, `Open with selected application`, `Open with selected application and stay active`, `Quit`, `Select next/previous application`, `Set Junction as default for Web`, `Test Junction`, `This site has no security. …`, `translator-credits` | 32 | ported |
| `Main Menu` | **0** | **gap** |
| `Show App Names` | **0** | **gap** |
| `Open Location` | **0** | **gap** |
| `View File in File Manager` | **0** | **gap** |
| `Run Junction in the background.` | **0** | **gap** |
| `Light Style` | **0** | **gap** |
| `Follow System Style` | **0** | **gap** |
| `Dark Style` | **0** | **gap** |

Eight of twenty-one. The catalogue predates the UI it is paired with: it still
carries `Reveal`, `Reveal in Folder`, `Show names`, `All Applications`,
`View All` and `Middle click to open in multiple applications` — the older
spellings of several of the strings now missing. The translators' work for
those controls exists under retired msgids and the port shipped the catalogue
without ever merging it against its own message set.

`Text still owed` for each row is the msgid as written above, byte for byte.

The three theme-switcher strings are upstream's too, from the `troll`
submodule, under troll's own domain; because the submodule is a gitlink they
appear in the port census as `extra` and in no upstream `.po`. They are owed to
translators either way.

## T3 — a msgid with 32 translations was deleted by dropping a screenshot

`Choose the application to open the image with` is the caption of upstream's
`screenshot-file.png`. It is translated in all 32 catalogues (`po/de.po:80`)
and the port emits no such string, because the port ships one `<screenshot>`
where upstream ships three. `Junction supports Linux mobile` is the third
caption; it is absent from the port and from the catalogue, so it costs a
component but no translation.

That is a msgid that did not survive the port, which is the thing this ledger
exists to catch. Closed by the same edit as `.reports/component-parity.md` C2.

## T4 — desktop-action labels bypass localisation entirely

`DesktopEntry#action_name` (`lib/junction_rb/desktop_entry.rb:97`) reads
`Name` with `GLib::KeyFile#get_string`; upstream reads it with
`appInfo.get_action_name`, which is a locale lookup. These are not Junction's
msgids — they belong to the installed applications and are already translated
in their own `.desktop` files — and the port discards them at the point of
reading. Verified against a key file with `Name[de]`:
`get_string` → `"New Window"`, `get_locale_string` → `"Neues Fenster"`.
Recorded against the component in `.reports/component-parity.md` C1.

## T5 — `po/POTFILES` asserts coverage the extraction does not have

`po/POTFILES` lists three data files first:

```
data/re.sonny.Junction.Rb.desktop
data/schemas/re.sonny.Junction.Rb.gschema.xml
data/re.sonny.Junction.Rb.metainfo.xml
```

`Rakefile:234-235` sets `task.files` to `lib/**/*.rb` + `exe/*`. `POTFILES` is
read by nothing. The generated `po/re.sonny.Junction.pot` accordingly holds 21
msgids and none of the data files' — not `Application chooser` (the `Comment`
*and* the `<summary>`), not the `Keywords` list, not the surviving screenshot
caption. The file documents an intent the build does not honour, and the
POTFILES completeness check translation-parity asks for does not exist in any
target.

The installed files *are* translated today, because `merge_translations`
(`Rakefile:301-311`) runs `msgfmt --desktop`/`--xml -d po`, which reads
`po/*.po` directly and finds those msgids there. That is luck: it depends on
the donated files still carrying msgids the port's own extraction has never
seen, and T1 is the mechanism that takes them away.

## T6 — no committed `.pot`

`po/re.sonny.Junction.pot` is generated and untracked
(`git ls-files po/` lists 32 `.po`, `LINGUAS`, `POTFILES` and nothing else), so
the port's msgid set has no reviewable record and the next pass has to re-derive
it by grep instead of diffing. Upstream has none either; that is upstream's
debt and not a licence.

## Checks that were run, and what each one proves

| Check | Result |
|---|---|
| domain matches upstream | ✓ `re.sonny.Junction` in all four places |
| 32 `.po` ≡ 32 `LINGUAS` ≡ 32 `.mo` | ✓ `diff` of the three lists is empty |
| GNU `msgfmt -c --check-format` over all 32 (`rake po:check`) | ✓ |
| `msgfmt --desktop` / `--xml` merge produces translated output | ✓ via `rake validate`, which validates the merged files |
| app shows translated text under a non-English locale | ✓ for 13 msgids, ✗ for the 8 of T2 — **and only while the committed `.mo` survives T1** |
| `appstreamcli validate` on the merged metainfo | ✓ 1 info, 1 pedantic |

## Things done right, recorded so they are not re-litigated

- The domain is upstream's everywhere. This is the single decision that keeps
  32 languages alive and it was made correctly.
- msgids are byte-identical, including the `TRANSLATORS:` comment on the
  insecure-site string, preserved by `--add-comments=TRANSLATORS`.
- `N_()` for strings in frozen constants (`UriEntry::INSECURE_TOOLTIP`,
  `ShortcutsDialog::SECTIONS`, `ThemeSwitcher::TOOLTIPS`,
  `Host::BACKGROUND_REASON`), translated at display. The locale is not settled
  at load; this is the only correct shape.
- `bindtextdomain` on the namespace module so every `JunctionRb::*` class
  resolves through `GetText::ClassInfo#related_classes`, plus
  `GLib::GetText.bindtextdomain` for GLib's own lookups.
- `Name=Junction`, `Keywords=` and `X-Purism-FormFactor=` keep upstream's
  `# TRANSLATORS: Do NOT translate` comments; `X-GNOME-FullName` is an `X-`
  key and is not extracted, so naming the port adds no untranslated msgid.
- `<description translatable="no">` matches upstream's own marker, so the eight
  feature bullets are not msgids on either side and the census's rows for them
  are over-reports. Checked, not assumed.
- `rake po:check` runs GNU `msgfmt --check-format`, which `rmsgfmt` cannot.
  Strictly better than upstream, which has no format check.
