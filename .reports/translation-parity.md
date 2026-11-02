# Translation parity — Junction-rb against `origin/main`

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
