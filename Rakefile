# frozen_string_literal: true

# kettle-jem:freeze
# To retain chunks of comments & code during kettle-jem templating:
# Wrap custom sections with freeze markers (e.g., as above and below this comment chunk).
# kettle-jem will then preserve content between those markers across template runs.
# kettle-jem:unfreeze

# junction-rb Rakefile v7.1.29 - 2026-10-12
# Ruby 2.3 (Safe Navigation) or higher required
#
# See LICENSE.md for license information.
#
# Copyright (c) 2026 ruby-gtk-project (github.com)
#
# Expected to work in any project that uses Bundler.
#
# Sets up tasks for appraisal2, floss_funding, kettle-jem, kettle-dev, rspec, minitest, rubocop_gradual, reek, yard, and stone_checksums.
#
# rake appraisal:install                      # Install Appraisal gemfiles (initial setup...
# rake appraisal:reset                        # Delete Appraisal lockfiles (gemfiles/*.gemfile.lock)
# rake appraisal:generate                     # Generate Appraisal gemfiles without resolving...
# rake appraisal:update                       # Generate and update Appraisal gemfiles
# rake bench                                  # Run all benchmarks (alias for bench:run)
# rake bench:list                             # List available benchmark scripts
# rake bench:run                              # Run all benchmark scripts (skips on CI)
# rake build:generate_checksums               # Generate both SHA256 & SHA512 checksums i...
# rake bundle:audit:check                     # Checks the Gemfile.lock for insecure depe...
# rake bundle:audit:update                    # Updates the bundler-audit vulnerability d...
# rake ci:act[opt]                            # Run 'act' with a selected workflow
# rake coverage                               # Run specs w/ coverage and open results in...
# rake default                                # Default tasks aggregator
# rake install                                # Build and install junction-rb-1.0.0.gem in...
# rake install:local                          # Build and install junction-rb-1.0.0.gem in...
# rake kettle:jem:install                     # Internal target used by `kettle-jem install`
# rake kettle:jem:selftest                    # Self-test: template junction-rb against itse...
# rake kettle:jem:template                    # Internal target used by scoped `kettle-jem template --only`
# rake reek                                   # Check for code smells
# rake reek:update                            # Run reek and store the output into the RE...
# rake release[remote]                        # Create tag v1.0.0 and build and push kett...
# rake rubocop_gradual                        # Run RuboCop Gradual
# rake rubocop_gradual:autocorrect            # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual:autocorrect_all        # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual:check                  # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual:force_update           # Run RuboCop Gradual to force update the l...
# rake rubocop_gradual_debug                  # Run RuboCop Gradual
# rake rubocop_gradual_debug:autocorrect      # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual_debug:autocorrect_all  # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual_debug:check            # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual_debug:force_update     # Run RuboCop Gradual to force update the l...
# rake spec                                   # Run RSpec code examples
# rake test                                   # Run tests
# rake yard                                   # Generate YARD Documentation
# rake yard:lint                              # Lint YARD Documentation
#

# simplecov:disable
if !Dir[File.join(__dir__, "*.gemspec")].empty?
  require "bundler/gem_tasks"
end
# simplecov:enable

# Define a base default task early so other files can enhance it.
#
# README.md said `rake` ran "schema, then the tests, then rubocop" while this
# was `puts "Default task complete."` and nothing enhanced it, so the one
# command a contributor is most likely to type checked nothing and said it was
# fine. The real dependencies are declared at the bottom of this file, once the
# tasks they name exist.
desc "Default tasks aggregator"
task :default do
  puts "Default task complete."
end

# Without this, a generated docs/ directory makes Rake resolve the bare
# name `docs` as an up-to-date file task, so `rake docs` exits 0 having
# regenerated nothing.
desc "Generate YARD documentation"
task docs: "yard"

# simplecov:disable
### MONOREPO FAMILY TASKS
if Dir.exist?(File.join(__dir__, "gems"))
  def family_gem_dirs
    Dir.glob(
      File.join(
        __dir__,
        "gems",
        "*",
        "*.gemspec",
      ),
    )
      .map { |path| File.dirname(path) }
      .uniq
      .sort_by { |path| File.basename(path) }
  end

  def run_kettle_family(*args)
    sh(
      "bundle",
      "exec",
      "kettle-family",
      *args,
    )
  end

  namespace :family do
    desc "List released Ruby subgems"
    task :list do
      family_gem_dirs.each { |path| puts File.basename(path) }
    end

    desc "Run release readiness checks for the Ruby gem family"
    task :readiness do
      run_kettle_family("check")
    end

    desc "Run tests for the Ruby gem family"
    task :test do
      run_kettle_family("test", "--execute")
    end

    desc "Run lint for the Ruby gem family"
    task :lint do
      run_kettle_family("lint", "--execute")
    end

    desc "Generate YARD docs for the Ruby gem family"
    task :docs do
      run_kettle_family("docs", "--execute")
    end

    desc "Report release state for the Ruby gem family"
    task :release_state do
      run_kettle_family("release-state")
    end

    desc "Run the Ruby gem family release planner"
    task :release do
      run_kettle_family("release")
    end

    desc "Execute the Ruby gem family release"
    task :release_execute do
      run_kettle_family("release", "--execute")
    end
  end
end
# simplecov:enable

# External gems that define tasks - add here!
begin
  require "kettle/dev"
  unless Kettle::Dev::RUNNING_AS == "rake"
    Kettle::Dev.install_tasks
  end
rescue LoadError
  warn("NOTE: kettle-dev isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
end

### TEMPLATING TASKS
# These tasks are installed for the `kettle-jem` executable. Run full templating
# through `kettle-jem install`; use `kettle-jem template --only PATH` only for
# scoped file updates. The executable prepares the environment and then
# delegates here when rake orchestration is needed.
kettle_jem_selftest_unavailable_note = nil
begin
  require "kettle/jem"
  if Kettle::Jem.respond_to?(:install_tasks)
    Kettle::Jem.install_tasks
  else
    kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem #{Kettle::Jem::Version::VERSION} does not provide rake tasks in this environment"
  end
rescue LoadError
  kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem isn't installed, or is disabled for #{RUBY_VERSION} in the current environment"
end

if kettle_jem_selftest_unavailable_note
  desc("(stub) kettle:jem:selftest is unavailable")
  task("kettle:jem:selftest") do
    warn(kettle_jem_selftest_unavailable_note)
  end
end

### RELEASE TASKS
# Setup stone_checksums
begin
  require "stone_checksums"
rescue LoadError
  desc("(stub) build:generate_checksums is unavailable")
  task("build:generate_checksums") do
    warn("NOTE: stone_checksums isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
  end
end
SCHEMA_DIR = File.expand_path('data/schemas', __dir__)

desc 'Compile the GSettings schema'
task :schema do
  sh 'glib-compile-schemas', SCHEMA_DIR
end

# The compiled catalogues are a build product the app loads at run time, so the
# suite depends on a check of them: a po/ change that does not compile, a
# catalogue that compiled to nothing, or a POTFILES that has fallen behind the
# source fails here rather than in a user's locale.
#
# The dependency is deliberately the *read-only* check and not
# `gettext:mo:compile`. It used to be the compile step, and that made `rake
# test` rewrite all 32 tracked locale/*/LC_MESSAGES/*.mo on every run: a
# developer who ran the suite and committed shipped an English-only app in 32
# languages as 32 reviewer-opaque binary diffs. The suite now reads po/ and
# locale/ and writes neither.
TEST_SCRIPTS = %w[
  test/resource_test.rb
  test/settings_test.rb
  test/cli_test.rb
  test/desktop_entry_test.rb
  test/portal_test.rb
  test/window_test.rb
  test/url_test.rb
  test/welcome_test.rb
].freeze

desc 'Run the test suite'
task test: ['schema', 'gettext:check'] do
  # Each file gets run and its status collected, rather than `sh` aborting the
  # task on the first non-zero exit: a failure in the first file used to hide
  # the seven after it, so a run reported one broken thing when eight were.
  TEST_SCRIPTS.filter_map do |script|
    puts "\n== #{script}"
    unless system({ 'GSETTINGS_SCHEMA_DIR' => SCHEMA_DIR }, 'ruby', script)
      script
    end
  end.then do |failures|
    unless failures.empty?
      puts
      failures.each { |script| puts "FAILED #{script}" }
      raise "#{failures.length} of #{TEST_SCRIPTS.length} test files failed"
    end
  end
end

desc 'Drive the whole app and the localised build, taking screenshots'
task drive: ['schema', 'gettext:check'] do
  %w[test/drive_junction.rb test/drive_locale.rb].filter_map do |script|
    puts "\n== #{script}"
    unless system({ 'GSETTINGS_SCHEMA_DIR' => SCHEMA_DIR }, 'ruby', script)
      script
    end
  end.then do |failures|
    unless failures.empty?
      failures.each { |script| puts "FAILED #{script}" }
      raise "#{failures.length} drive scripts failed"
    end
  end
end

# Not a dependency of `default`: this one *writes* the three tracked PNGs in
# docs/, and a suite that rewrote committed binaries on every green run is the
# same mistake `gettext:mo:compile` is kept out of `test` for. Run it when the
# chooser changes, and look at what it produced.
desc 'Recapture the three AppStream screenshots into docs/'
task screenshots: :schema do
  sh({ 'GSETTINGS_SCHEMA_DIR' => SCHEMA_DIR }, 'ruby', 'test/capture_screenshots.rb')
end

desc 'Run the app'
task run: :schema do
  sh(
    { 'GSETTINGS_SCHEMA_DIR' => SCHEMA_DIR },
    'ruby',
    'exe/junction-rb',
    *ARGV.drop(1),
  )
end

desc 'Lint'
task :lint do
  # `rubocop` on PATH here is the fork's own wrapper, carrying its own gemset.
  # Invoked from inside this project's bundle it resolves the name against
  # *this* Gemfile instead and dies with "can't find executable rubocop for
  # gem rubocop" — so `rake`, which was made to depend on :lint precisely so
  # that a green run meant something, could never reach the end. Shedding the
  # bundler environment is what the wrapper needs and all it needs.
  if defined?(Bundler)
    Bundler.with_unbundled_env { sh 'rubocop' }
  else
    sh 'rubocop'
  end
end

### TRANSLATION TASKS
# The port reuses upstream's donated catalogue: po/ came across from Junction's
# l10n branch, and the domain stays upstream's app id, because a .mo is found
# by domain name (see JunctionRb::TEXT_DOMAIN).
#
# What used to be here was GetText::Tools::Task with po_base_directory=po. That
# layout expects po/<locale>/<domain>.po; this repo, like upstream, keeps
# po/<locale>.po. The gem therefore found none of the 32 donated files, created
# po/de/re.sonny.Junction.po and friends empty from the freshly extracted .pot,
# and compiled *those* — locale/de/LC_MESSAGES/re.sonny.Junction.mo went from
# 6295 bytes to 361, a header and no entries, in every language, while the task
# exited 0. The donated po/<lang>.po files were never opened. Since the gemspec
# ships locale/**/*.mo, `rake build` after that packaged the empty ones.
#
# So the catalogues are compiled here by naming each donated file directly.
require "fileutils"
require "tmpdir"

TEXT_DOMAIN = "re.sonny.Junction"
PO_DIR = File.expand_path("po", __dir__)
LOCALE_DIR = File.expand_path("locale", __dir__)
POT_FILE = File.join(PO_DIR, "#{TEXT_DOMAIN}.pot")
POTFILES = File.join(PO_DIR, "POTFILES")

# Read from LINGUAS rather than globbed from po/*.po, so a language that loses
# its file loses it loudly instead of silently.
def linguas = File.read(File.join(PO_DIR, "LINGUAS")).split

def po_for(lang) = File.join(PO_DIR, "#{lang}.po")

def mo_for(lang) = File.join(
  LOCALE_DIR,
  lang,
  "LC_MESSAGES",
  "#{TEXT_DOMAIN}.mo",
)

# The files po/POTFILES names, as absolute paths, split by how they have to be
# extracted. POTFILES is upstream's list and the only list: a file that is in
# the source and not in POTFILES is the bug this split is here to expose.
def potfiles_entries
  File
    .readlines(POTFILES)
    .map(&:strip)
    .reject { |line| line.empty? || line.start_with?("#") }
end

def potfiles_paths = potfiles_entries.map { |entry| File.expand_path(entry, __dir__) }

# The same list, repository-relative. The .pot is committed and diffed, so the
# `#:` source references in it have to be stable paths and not this machine's
# /nix/store-adjacent checkout location.
def potfiles_relative = potfiles_entries

# Every file under lib/ and exe/ that actually carries a marker. POTFILES has
# to list all of them, and `gettext:potfiles` is what says so.
MARKER = /(?<![A-Za-z0-9_])N?_\(/

def marked_sources
  (Dir.glob(File.expand_path("lib/**/*.rb", __dir__)) + Dir.glob(File.expand_path("exe/*", __dir__)))
    .select { |path| File.file?(path) && File.read(path).match?(MARKER) }
    .sort
end

# A compiled catalogue's entry count, read out of the .mo header rather than by
# shelling out to msgunfmt: bytes 0..3 are the magic 0x950412de, written in the
# producing machine's byte order so that reading it says which order the rest
# of the file is in, and bytes 8..11 are the number of strings.
#
# A header-only stub reads 1 here — the empty msgid that carries the Content-Type
# and Plural-Forms metadata — which is why the check wants strictly more than
# that. `Dir.glob("*.mo").length.positive?` was the old check, and a 361-byte
# stub satisfied it in every language.
MO_MAGIC = 0x950412de

def mo_entry_count(path)
  File.binread(path, 12).then do |head|
    if head.nil? || head.bytesize < 12
      0
    else
      # Read big-endian first. A little-endian file's magic comes back byte
      # reversed, and that is the signal to read the counts little-endian too.
      head.unpack("N3").then do |(magic, _revision, big_endian_count)|
        if magic == MO_MAGIC
          big_endian_count
        elsif magic == [MO_MAGIC].pack("V").unpack1("N")
          head.unpack("V3")[2]
        else
          0
        end
      end
    end
  end
end

namespace :gettext do
  desc "Extract po/#{TEXT_DOMAIN}.pot from every file po/POTFILES names"
  task :pot do
    require_program("rxgettext", "the gettext gem's extractor (gem install gettext)")
    require_program("xgettext", "GNU gettext")

    Dir.chdir(__dir__) do
      potfiles_relative.partition { |path| path.end_with?(".rb") || path.start_with?("exe/") }
                       .then do |ruby_files, data_files|
        FileUtils.mkdir_p(PO_DIR)
        FileUtils.rm_f(POT_FILE)
        # The gem's Ruby parser drops translator comments unless asked; every
        # one of them exists to prevent a specific mistranslation.
        sh(
          "rxgettext",
          "--output=po/#{TEXT_DOMAIN}.pot",
          "--package-name=Junction",
          "--add-comments=TRANSLATORS",
          *ruby_files,
        )
        # The data files are the half POTFILES listed and nothing read. msgfmt
        # --desktop/--xml reads po/*.po directly at install time, so the
        # installed .desktop and metainfo were translated only for as long as
        # the donated files happened to carry msgids the port's own extraction
        # had never seen. Now they are in the same message set as the Ruby
        # strings, which is what makes a missing one a diff rather than a grep.
        data_files.each do |path|
          sh(
            "xgettext",
            "--join-existing",
            "--from-code=UTF-8",
            *(path.end_with?(".desktop") ? ["--language=Desktop"] : []),
            "--output=po/#{TEXT_DOMAIN}.pot",
            path,
          )
        end
      end
    end
    puts("wrote #{POT_FILE} (#{File.read(POT_FILE).scan(/^msgid /).length - 1} messages)")
  end

  desc "Merge po/#{TEXT_DOMAIN}.pot into every donated po/<lang>.po"
  task merge: :pot do
    require_program("msgmerge", "GNU gettext")
    linguas.each do |lang|
      sh(
        "msgmerge",
        "--update",
        "--backup=none",
        "--previous",
        po_for(lang),
        POT_FILE,
      )
    end
  end

  namespace :mo do
    # Not a dependency of anything: this is the only task in the file that
    # writes the tracked catalogues, and it is run on purpose, by a person, when
    # po/ has changed.
    desc "Compile each donated po/<lang>.po to locale/<lang>/LC_MESSAGES/#{TEXT_DOMAIN}.mo"
    task :compile do
      require_program("msgfmt", "GNU gettext")
      linguas.each do |lang|
        po_for(lang).then do |po|
          unless File.exist?(po)
            raise "po/LINGUAS names #{lang} but #{po} does not exist"
          end

          FileUtils.mkdir_p(File.dirname(mo_for(lang)))
          sh(
            "msgfmt",
            "--check",
            "--check-format",
            "--output-file=#{mo_for(lang)}",
            po,
          )
        end
      end
      puts("compiled #{linguas.length} catalogues into #{LOCALE_DIR}")
    end
  end

  desc "Check po/POTFILES lists every source that carries a marker"
  task :potfiles do
    potfiles_paths.then do |listed|
      [
        ["po/POTFILES names a file that does not exist", listed.reject { |p| File.exist?(p) }],
        ["carries a translatable string and is not in po/POTFILES", marked_sources - listed],
      ].flat_map do |(what, offenders)|
        offenders.map { |path| "#{what}: #{path.sub("#{__dir__}/", "")}" }
      end.then do |problems|
        unless problems.empty?
          problems.each { |problem| warn(problem) }
          raise "po/POTFILES is incomplete (#{problems.length} problems)"
        end
      end
    end
    puts("po/POTFILES accounts for all #{marked_sources.length} marked sources")
  end

  # Read-only, and what `rake test` depends on. It never writes po/ or locale/:
  # every po/<lang>.po is compiled into a temporary directory that is thrown
  # away, and the tracked .mo files are only read.
  desc "Check the committed catalogues without writing anything"
  task check: :potfiles do
    require_program("msgfmt", "GNU gettext")
    Dir.mktmpdir do |dir|
      linguas.flat_map do |lang|
        {
          "po/#{lang}.po is missing"                                => po_for(lang),
          "locale/#{lang}/LC_MESSAGES/#{TEXT_DOMAIN}.mo is missing" => mo_for(lang),
        }.reject { |_message, path| File.exist?(path) }.keys.then do |missing|
          if missing.empty?
            # po/<lang>.po must still compile — a translator's stray %s is a
            # crash in one language only, and --check-format is what catches it.
            File.join(dir, "#{lang}.mo").then do |fresh|
              sh(
                "msgfmt",
                "--check",
                "--check-format",
                "--output-file=#{fresh}",
                po_for(lang),
              )
              # The tracked .mo has to hold exactly what the donated po
              # compiles to. This is the check the old suite did not have: the
              # gettext task was replacing every catalogue with a 361-byte
              # header-only stub, and `Dir.glob("*.mo").length.positive?` could
              # not tell the difference. Comparing counts also catches a
              # catalogue that is merely stale after a po/ change.
              [mo_entry_count(fresh), mo_entry_count(mo_for(lang))].then do |(expected, actual)|
                if expected == actual
                  []
                else
                  ["locale/#{lang}/LC_MESSAGES/#{TEXT_DOMAIN}.mo holds #{actual} entries where " \
                   "po/#{lang}.po compiles to #{expected}; run `rake gettext:mo:compile`"
]
                end
              end
            end
          else
            missing
          end
        end
      end.then do |problems|
        unless problems.empty?
          problems.each { |problem| warn(problem) }
          raise "the compiled catalogues do not match po/ (#{problems.length} problems)"
        end
      end
      # sk.po genuinely has nothing translated yet, so a per-language "must
      # carry entries" rule would be a lie about that language. A locale/ in
      # which *nothing* carries entries is the failure mode that actually
      # happened, and this is what names it.
      linguas.sum { |lang| mo_entry_count(mo_for(lang)) - 1 }.then do |entries|
        unless entries.positive?
          raise "locale/ holds #{linguas.length} catalogues and not one translated entry between them"
        end

        puts("#{linguas.length} catalogues match po/ and carry #{entries} translated entries")
      end
    end
  end
end

namespace :po do
  # rmsgfmt does not handle `#, c-format` flags at all — it neither writes nor
  # validates them — so without GNU msgfmt the port would ship 32 catalogues
  # whose format specifiers nobody ever checked against their msgids. This is
  # the check that stops a translator's stray %s crashing the app in one
  # language only.
  desc "Check every catalogue's format specifiers with GNU msgfmt"
  task :check do
    require_program("msgfmt", "GNU gettext, in flake.nix")
    Dir.glob(File.join(PO_DIR, "*.po")).sort.each do |po|
      sh(
        "msgfmt",
        "-c",
        "--check-format",
        "-o",
        File::NULL,
        po,
      )
    end
  end
end

### DESKTOP INTEGRATION TASKS
# dbus-daemon needs an absolute Exec, which is why the service file ships with
# an @bindir@ placeholder; upstream fills it from meson's bindir and the port
# fills it here.
XDG_DATA_HOME = ENV.fetch("XDG_DATA_HOME", File.join(Dir.home, ".local", "share"))
DBUS_SERVICES_DIR = File.join(XDG_DATA_HOME, "dbus-1", "services")

# Where upstream's data/meson.build puts its five installed files, resolved
# under XDG_DATA_HOME because the port installs per-user rather than into a
# prefix: a gem has no $datadir to install_data into.
APPLICATIONS_DIR = File.join(XDG_DATA_HOME, "applications")
METAINFO_DIR = File.join(XDG_DATA_HOME, "metainfo")
GLIB_SCHEMAS_DIR = File.join(XDG_DATA_HOME, "glib-2.0", "schemas")
HICOLOR_DIR = File.join(XDG_DATA_HOME, "icons", "hicolor")
SCALABLE_APPS_DIR = File.join(HICOLOR_DIR, "scalable", "apps")
SYMBOLIC_APPS_DIR = File.join(HICOLOR_DIR, "symbolic", "apps")

DESKTOP_FILE = "re.sonny.Junction.Rb.desktop"
METAINFO_FILE = "re.sonny.Junction.Rb.metainfo.xml"
GSCHEMA_FILE = "re.sonny.Junction.Rb.gschema.xml"
SCALABLE_ICON = "re.sonny.Junction.Rb.svg"
SYMBOLIC_ICON = "re.sonny.Junction.Rb-symbolic.svg"

# Upstream runs the .desktop and the metainfo through i18n.merge_file, which is
# meson's wrapper around `msgfmt --desktop` / `msgfmt --xml`. Both read po/
# directly — the compiled catalogues in locale/ are for the Ruby gettext gem
# and for libintl, and are not what these two files carry. Without this step
# the installed files would be English-only in 32 translated languages.
def merge_translations(mode, template, target)
  require_program("msgfmt", "GNU gettext, in flake.nix")
  sh(
    "msgfmt",
    mode,
    "--template=#{template}",
    "-d",
    PO_DIR,
    "-o",
    target,
  )
end

def program?(name)
  ENV
    .fetch("PATH", "")
    .split(File::PATH_SEPARATOR)
    .any? { |dir| File.executable?(File.join(dir, name)) }
end

# Upstream registers desktop-file-validate, appstreamcli and glib-compile-schemas
# as meson tests with `required: false`, because a distribution build host may
# not have them. This repo is not a distribution build host: the validators come
# from flake.nix and are on PATH inside `nix develop`, so a missing one is a
# broken dev shell and not a fact of life.
#
# This replaces a `with_program` that warned and returned, which made `rake
# validate` exit 0 on a host without appstreamcli having validated nothing at
# all — a green task that had checked none of the three things it is named for.
def require_program(name, provider)
  unless program?(name)
    raise "#{name} is not on PATH. It comes from #{provider}; run this inside `nix develop`."
  end
end

# For the genuinely optional cache-refreshers — update-desktop-database and
# gtk4-update-icon-cache change nothing that is checked, they only make an
# install visible sooner — skipping is still the right answer, and it is said
# out loud.
def if_program(name)
  if program?(name)
    yield
  else
    puts("#{name} is not on PATH; the install is complete but its cache was not refreshed")
  end
end

namespace :install do
  desc "Install the D-Bus activation service file for the current user (BINDIR= to override)"
  task :service do
    bindir = ENV.fetch("BINDIR") { File.expand_path("exe", __dir__) }
    target = File.join(DBUS_SERVICES_DIR, "re.sonny.Junction.Rb.service")
    template = File.read(File.expand_path("data/re.sonny.Junction.Rb.service", __dir__))

    FileUtils.mkdir_p(DBUS_SERVICES_DIR)
    File.write(target, template.gsub("@bindir@", bindir))
    puts("installed #{target} with Exec=#{bindir}/junction-rb")
  end

  # This is the file that makes the port reachable at all: `gio mime
  # x-scheme-handler/https re.sonny.Junction.Rb.desktop` — what the welcome
  # window's one button runs — can only name a desktop id that exists in an
  # applications/ directory.
  desc "Install the desktop entry, with its translations, for the current user"
  task :desktop do
    target = File.join(APPLICATIONS_DIR, DESKTOP_FILE)

    FileUtils.mkdir_p(APPLICATIONS_DIR)
    merge_translations(
      "--desktop",
      File.expand_path("data/#{DESKTOP_FILE}", __dir__),
      target,
    )
    if_program("update-desktop-database") do
      sh("update-desktop-database", APPLICATIONS_DIR)
    end
    puts("installed #{target}")
  end

  desc "Install the AppStream metainfo, with its translations, for the current user"
  task :metainfo do
    target = File.join(METAINFO_DIR, METAINFO_FILE)

    FileUtils.mkdir_p(METAINFO_DIR)
    merge_translations(
      "--xml",
      File.expand_path("data/#{METAINFO_FILE}", __dir__),
      target,
    )
    puts("installed #{target}")
  end

  # Gio::Settings looks a schema up in the compiled cache of an XDG data dir and
  # aborts the process when it is not there, so this is what lets junction-rb
  # start without GSETTINGS_SCHEMA_DIR pointing back into a checkout.
  desc "Install and compile the GSettings schema for the current user"
  task :schema do
    FileUtils.mkdir_p(GLIB_SCHEMAS_DIR)
    FileUtils.cp(
      File.expand_path("data/schemas/#{GSCHEMA_FILE}", __dir__),
      File.join(GLIB_SCHEMAS_DIR, GSCHEMA_FILE),
    )
    sh("glib-compile-schemas", GLIB_SCHEMAS_DIR)
    puts("installed #{File.join(GLIB_SCHEMAS_DIR, GSCHEMA_FILE)}")
  end

  desc "Install the application icons for the current user"
  task :icons do
    FileUtils.mkdir_p(SCALABLE_APPS_DIR)
    FileUtils.mkdir_p(SYMBOLIC_APPS_DIR)
    FileUtils.cp(
      File.expand_path("data/icons/hicolor/scalable/apps/#{SCALABLE_ICON}", __dir__),
      File.join(SCALABLE_APPS_DIR, SCALABLE_ICON),
    )
    FileUtils.cp(
      File.expand_path("data/icons/hicolor/symbolic/apps/#{SYMBOLIC_ICON}", __dir__),
      File.join(SYMBOLIC_APPS_DIR, SYMBOLIC_ICON),
    )
    if_program("gtk4-update-icon-cache") do
      sh(
        "gtk4-update-icon-cache",
        "-q",
        "-t",
        "-f",
        HICOLOR_DIR,
      )
    end
    puts("installed #{SCALABLE_ICON} and #{SYMBOLIC_ICON} under #{HICOLOR_DIR}")
  end

  desc "Install everything data/ ships: desktop entry, metainfo, schema, icons"
  task data: ["install:desktop", "install:metainfo", "install:schema", "install:icons"]

  desc "Install the data files and the D-Bus service (BINDIR= to override)"
  task all: ["install:data", "install:service"]
end

namespace :validate do
  desc "Validate the desktop entry with desktop-file-validate"
  task :desktop do
    require_program("desktop-file-validate", "desktop-file-utils, in flake.nix")
    # The merged file is what gets installed, so it is the one that has to
    # pass: a bad translated key would never show up in the template.
    Dir.mktmpdir do |dir|
      File.join(dir, DESKTOP_FILE).tap do |merged|
        merge_translations(
          "--desktop",
          File.expand_path("data/#{DESKTOP_FILE}", __dir__),
          merged,
        )
        sh("desktop-file-validate", merged)
      end
    end
  end

  desc "Validate the AppStream metainfo with appstreamcli"
  task :metainfo do
    require_program("appstreamcli", "appstream, in flake.nix")
    Dir.mktmpdir do |dir|
      File.join(dir, METAINFO_FILE).tap do |merged|
        merge_translations(
          "--xml",
          File.expand_path("data/#{METAINFO_FILE}", __dir__),
          merged,
        )
        sh(
          "appstreamcli",
          "validate",
          "--no-net",
          "--explain",
          merged,
        )
      end
    end
  end

  # --strict turns glib-compile-schemas' warnings into errors, which is how
  # upstream runs it as a test; `rake schema` deliberately does not, because
  # that one builds the cache the app reads.
  desc "Validate the GSettings schema with glib-compile-schemas --strict"
  task :schema do
    require_program("glib-compile-schemas", "glib, in flake.nix")
    sh(
      "glib-compile-schemas",
      "--strict",
      "--dry-run",
      SCHEMA_DIR,
    )
  end
end

desc "Run every data-file validation upstream registers as a meson test"
task validate: ["validate:desktop", "validate:metainfo", "validate:schema"]

# Declared last, so every task named here is defined. `rake` with no arguments
# now runs what README.md says it runs: the schema, the full suite, the data
# validations upstream registers as meson tests, the two drive scripts, and
# rubocop.
