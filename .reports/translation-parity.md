# Translation parity — Junction-rb against `origin/main` (+ `origin/l10n` for `po/`)

Upstream's `main` carries no `po/`; the catalogue lives on `origin/l10n`
(32 languages, `po/re.sonny.Junction.pot`, `po/meson.build`). The msgid *set*
is therefore taken from the `_()` markers in `origin/main`'s sources plus its
`data/` files, which is what a fresh `xgettext` run would produce.

Verdict: **not clean.** The 32 catalogues survived byte for byte, 21 of 24
source msgids match byte for byte — and none of it reaches a user, because no
compiled catalogue is committed or packaged.

## Claim 3 first, because it voids the other two

**`locale/` is gitignored and absent from `spec.files`.**

- `lib/junction_rb.rb:48` — `LOCALE_DIR = File.expand_path('../locale', __dir__)`
- `.gitignore:11` — `/locale/`
- `junction-rb.gemspec:72-82` — `spec.files` enumerates `lib`, `exe`,
  `data/**/*` and `po/**/*`. Not `locale/**/*`.
- `locale/` does not exist in the working tree.

So `bindtextdomain('re.sonny.Junction', path: <gem>/locale)` resolves to a
directory that is not in the repository and not in the built gem. Every
`_()` call returns its msgid, in all 32 languages. The `.po` files ship as
data nothing reads.

Upstream compiles its catalogue in `po/meson.build` as part of the build, so an
installed Junction has 32 `.mo` files under `$prefix/share/locale`. The port's
equivalent is `rake gettext:mo:update`, which is a developer task nobody runs
at install time.

Fix, in order: add `locale/**/*.mo` to `spec.files`, un-ignore the compiled
output (or generate it from a gemspec/extension hook), and make `rake test`
depend on the compile so the wiring is exercised. Until then the port is
"translated into English".

## Claim 1 and 2 — the key sets

Census: `.claude/skills/translation-parity/scripts/msgid-census.sh`, run over a
clean `git archive origin/main` export and over the working tree, with `po/`
rows excluded from the port side.

### Byte-identical, present on both sides (21)

`About Junction` · `Application chooser` ·
`Choosy;BrowserChooser;Braus;Browserosaurus;Finicky;Buffet;OpenIn;BrowserSelect;` ·
`Copy to Clipboard` · `Discard and close` · `Keyboard Shortcuts` ·
`Main Menu` · `Open Location` · `Open with application at position` ·
`Open with selected application` ·
`Open with selected application and stay active` · `Quit` ·
`Run Junction in the background.` · `Select next/previous application` ·
`Set Junction as default for Web` · `Show App Names` · `Test Junction` ·
`This site has no security. An attacker could see any information you send, or control the content that you see.` ·
`translator-credits` · `View File in File Manager` ·
`Choose the browser to open the link with`

Produced differently in several cases — `N_()` in a frozen table with `_()` at
display (`shortcuts_dialog.rb`, `uri_entry.rb`, `host.rb`) rather than a
`.blp` label — which is fine: the key that reaches the catalogue is the same.

### Gaps — upstream keys the port does not emit (3)

| msgid | Upstream | Port | Why it is a gap |
|---|---|---|---|
| `Junction` | `data/re.sonny.Junction.desktop:3` (`Name=`) | `Name=Junction (Ruby)` | The upstream key is gone and a new, untranslated key takes its place. Both halves count. Upstream's own comment says "Do NOT translate", but `xgettext` extracts `Name=` regardless and the l10n `.pot` carries it. |
| `Choose the application to open the image with` | metainfo `<caption>` | — | The `screenshot-file.png` screenshot was not ported, so the caption went with it. 32 translations stranded. |
| `Junction supports Linux mobile` | metainfo `<caption>` | — | Same, for `screenshot-mobile.png`. |

### Extra port keys nobody has translated (1)

| msgid | Where |
|---|---|
| `Junction (Ruby)` | `data/re.sonny.Junction.Rb.desktop:3` |

If the port genuinely needs a distinguishable name — and installing beside the
original is the whole reason for the `.Rb` suffix — the honest shape is
`Name=Junction` with `X-GNOME-FullName` or a `NoDisplay` sibling, or
`translatable="no"` handling that keeps the msgid intact. The current form
deletes 32 translations of one word.

### Unmarked user-visible strings in the port (5)

These never reach the catalogue at all, so they are English for everyone:

| String | Where | Upstream |
|---|---|---|
| `Light Style` | `theme_switcher.rb:12` | `troll`'s `ThemeSelector`; also unmarked upstream, but it is a port string now |
| `Follow System Style` | `theme_switcher.rb:13` | as above |
| `Dark Style` | `theme_switcher.rb:14` | as above |
| `Application` | `shortcuts_dialog.rb:24` | **no upstream counterpart** — the port invented this section title |
| `Contributors` | `about_dialog.rb:32` | unmarked upstream too (`about.js:68`) |

`Application` is the one that matters: it is a string the port added, visible in
a dialog, in no catalogue.

### `po/POTFILES` is incomplete

`po/POTFILES` lists eight `lib/` files. It omits
`lib/junction_rb/theme_switcher.rb` and `lib/junction_rb/application.rb`, so
even once the strings above are marked, `rxgettext` will not see them.

### The catalogues themselves

- `po/*.po` are **byte-identical** to `origin/l10n:po/*.po` for every language
  checked (`fr`, `de`, `ja` diffed clean), and `po/LINGUAS` matches exactly:
  32 languages. Claim 3's "the languages come with it" half is satisfied as
  source; it is the compile and the packaging that are missing.
- `po/re.sonny.Junction.pot` was **not** ported. Upstream ships it on `l10n`.
  Without a committed template there is no reviewable record of the current key
  set, which is how three msgids went missing unnoticed.
- The l10n snapshot predates upstream's current wording: `Show names`,
  `Reveal`, `Reveal in Folder`, `All Applications`, `View All`. The port
  correctly follows current upstream (`Show App Names`, `Open Location`,
  `View File in File Manager`) and so inherits the same five-string translation
  debt upstream has. Not a port gap.

## Summary

| Claim | State |
|---|---|
| 1. Key sets equal | **fail** — 3 upstream keys missing, 1 extra |
| 2. Each key byte-identical | **fail** on `Junction` → `Junction (Ruby)`; pass on the other 21 |
| 3. Languages come with it | **fail** — 32 `.po` present, 0 `.mo` committed or packaged |
