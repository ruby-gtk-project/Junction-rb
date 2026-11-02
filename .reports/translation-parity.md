# Translation parity — Junction-rb against `origin/main`

Verdict: **not clean.** The catalogue survived — 32 languages, byte-identical
msgids, upstream's gettext domain kept so the `.mo` files are still found — but
a third of the strings the port actually displays have no msgid in any
catalogue, and the data-file translations are never merged into the files that
would carry them.

## Setup, and what the spec is

`origin/main` has **no `po/` directory**: `git ls-tree -r --name-only
origin/main | grep po/` is empty, and `meson.build` has no `subdir('po')`.
Upstream keeps its catalogue on a separate l10n branch; `data/meson.build`
reads it with `po_dir: '../po'`. So the spec for this report is in two parts:

1. the msgids upstream *marks* — `_()` in `src/*.js`, `_("…")` in `src/*.blp`,
   the translatable fields of `data/re.sonny.Junction.desktop` and
   `data/re.sonny.Junction.metainfo.xml`, and the `gettext-domain` of
   `data/re.sonny.Junction.gschema.xml`;
2. the 32 catalogues the port ships in `po/`, which came across from upstream's
   l10n branch and are the asset most easily destroyed by a port.

The domain is kept correctly: `JunctionRb::TEXT_DOMAIN = 're.sonny.Junction'`
(`lib/junction_rb.rb`), the gschema's `gettext-domain`, the metainfo's
`<translation type="gettext">` and `Rakefile:222` all say
`re.sonny.Junction`, not `.Rb`. A `.mo` is looked up by domain name, so this is
the single decision that keeps all 32 languages alive, and it was made right.
`po/LINGUAS` lists 32 locales, `po/` holds 32 `.po` files, and
`locale/*/LC_MESSAGES/re.sonny.Junction.mo` holds 32 compiled catalogues.

## Gap 1 — the desktop file and the metainfo are never merged with the catalogue

Upstream builds both through `i18n.merge_file` (`data/meson.build:1-24`), which
runs `msgfmt --desktop` / `msgfmt --xml` against `po/` and installs a file
containing `Comment[fr]=…`, `<summary xml:lang="fr">…` and a translated
`<caption>` for every one of the 32 languages.

The port has no equivalent step anywhere: `Rakefile`'s only translation tasks
are `gettext:*` (which compile `.mo` files for the Ruby gem's own lookups) and
`po:check` (which validates format specifiers). `namespace :install` installs
the D-Bus service and nothing else.

Consequence: `Comment=Application chooser` ships in English only, and so do
`<summary>` and the screenshot caption. These are the strings a user sees in
the application grid and in the software centre — the most visible translated
text the project has — and all 32 translations of them are present in `po/`
and reach nothing.

Fix: an install task that runs `msgfmt --desktop --template=<desktop> -d po -o
<out>` and `msgfmt --xml --template=<metainfo> -d po -o <out>` before copying,
as part of closing component-parity P0.

## Gap 2 — eight strings the port displays have no msgid in any catalogue

Every `_()` / `N_()` marker in `lib/` and `exe/`, checked against all 32 `.po`
files:

| msgid | catalogues containing it |
|---|---|
| `About Junction` | 32 |
| `Copy to Clipboard` | 32 |
| `Discard and close` | 32 |
| `Keyboard Shortcuts` | 32 |
| `Open with application at position` | 32 |
| `Open with selected application` | 32 |
| `Open with selected application and stay active` | 32 |
| `Quit` | 32 |
| `Select next/previous application` | 32 |
| `Set Junction as default for Web` | 32 |
| `Test Junction` | 32 |
| `This site has no security. An attacker could see any information you send, or control the content that you see.` | 32 |
| `translator-credits` | 32 |
| **`Main Menu`** | **0** |
| **`Show App Names`** | **0** |
| **`Open Location`** | **0** |
| **`View File in File Manager`** | **0** |
| **`Run Junction in the background.`** | **0** |
| **`Light Style`** | **0** |
| **`Dark Style`** | **0** |
| **`Follow System Style`** | **0** |

Eight of twenty-one marked strings — the main menu button's tooltip, one of the
two preferences in that menu, both strings on the "Open Location" tile, the
portal's background-permission reason, and all three theme-switcher tooltips —
render in English in every locale.

The catalogue predates the UI it is paired with. It still carries msgids for
controls that no longer exist (`Reveal`, `Reveal in Folder`, `Show names`,
`All Applications`, `View All`, `Middle click to open in multiple
applications`) — the older spellings of exactly the strings now missing. So the
translators' work for these controls exists, under previous msgids, and the
port shipped the catalogue without ever merging it against its own message set.

Evidence that the merge has never been run: there is **no `.pot` file** in the
repository (`ls po/` → 32 `.po`, `LINGUAS`, `POTFILES`), and `po/*.po` carry no
`#:` source references for any `lib/*.rb` file. `GetText::Tools::Task` would
generate `po/re.sonny.Junction.pot` on `rake gettext:po:update`; nothing in the
tree shows it ever has.

Fix: run `rake gettext:po:update`, then `msgmerge` the retired msgids onto
their successors (or let translators re-fill eight strings) and commit the
`.pot` so the next pass can diff instead of grep.

## Gap 3 — one msgid with 32 translations was deleted by dropping a screenshot

`Choose the application to open the image with` is the caption of upstream's
`screenshot-file.png`. It is present in all 32 catalogues and absent from the
port, because the port ships one `<screenshot>` instead of three
(component-parity P4). The third caption, `Junction supports Linux mobile`, is
also absent from the port, and is not in the catalogue either.

That is a msgid that did not survive, which is precisely what this report is
for.

## Gap 4 — `po/POTFILES` is not what extracts anything

`po/POTFILES` lists the three data files first:

```
data/re.sonny.Junction.Rb.desktop
data/schemas/re.sonny.Junction.Rb.gschema.xml
data/re.sonny.Junction.Rb.metainfo.xml
```

`Rakefile:230-232` sets

```ruby
task.files = Dir.glob("lib/**/*.rb") + Dir.glob("exe/*")
```

so `POTFILES` is never read and the three data files are never scanned. Run
`rake gettext:po:update` as it stands and every data-file msgid —
`Application chooser`, the keyword list, the screenshot caption — is marked
obsolete in all 32 catalogues and eventually dropped. `POTFILES` is currently
documentation of an intent the build does not honour, and the one place it
matters is also the place where running the task is dangerous.

Fix: either feed `POTFILES` to `task.files`, or extract the data files
separately (`xgettext --language=Desktop`, `--its`) and keep one message set.

## Things done right, recorded so they are not re-litigated

- Domain kept as `re.sonny.Junction` everywhere, so no `.mo` is orphaned.
- msgids byte-identical to upstream's, including the translator comment on the
  insecure-site string, which `--add-comments=TRANSLATORS` preserves.
- `N_()` for strings in frozen constants (`UriEntry::INSECURE_TOOLTIP`,
  `ShortcutsDialog::SECTIONS`, `ThemeSwitcher::TOOLTIPS`,
  `Host::BACKGROUND_REASON`), translated at display — the locale is not settled
  at load time, and this is the only correct shape.
- `bindtextdomain` on the namespace module, so every `JunctionRb::*` class
  resolves the domain through `GetText::ClassInfo#related_classes`, plus
  `GLib::GetText.bindtextdomain` for GLib's own lookups.
- `Name=Junction`, `Keywords=` and `X-Purism-FormFactor=` keep upstream's
  `# TRANSLATORS: Do NOT translate` comments; `X-GNOME-FullName` is an `X-` key
  and is not extracted, so naming the port adds no untranslated msgid.
- `rake po:check` runs GNU `msgfmt -c --check-format` over all 32 files, which
  `rmsgfmt` cannot do. This is strictly better than upstream, which has no
  format check at all.
- `<name translatable="no">`, `<description translatable="no">` and the
  release notes `translatable="no"` match upstream's own markers.
