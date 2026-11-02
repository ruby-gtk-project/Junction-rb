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
require "bundler/gem_tasks" if !Dir[File.join(__dir__, "*.gemspec")].empty?
# simplecov:enable

# Define a base default task early so other files can enhance it.
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
    Dir.glob(File.join(__dir__, "gems", "*", "*.gemspec"))
      .map { |path| File.dirname(path) }
      .uniq
      .sort_by { |path| File.basename(path) }
  end

  def run_kettle_family(*args)
    sh("bundle", "exec", "kettle-family", *args)
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
  Kettle::Dev.install_tasks unless Kettle::Dev::RUNNING_AS == "rake"
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
# suite depends on them: a po/ change that does not compile, or a gettext task
# that has stopped working, fails here rather than in a user's locale.
desc 'Run the test suite'
task test: ['schema', 'gettext:mo:update'] do
  %w[
    test/resource_test.rb
    test/settings_test.rb
    test/cli_test.rb
    test/desktop_entry_test.rb
    test/portal_test.rb
    test/window_test.rb
    test/url_test.rb
    test/welcome_test.rb
  ].each do |script|
    puts "\n== #{script}"
    sh({ 'GSETTINGS_SCHEMA_DIR' => SCHEMA_DIR }, 'ruby', script)
  end
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
  sh 'rubocop'
end

### TRANSLATION TASKS
# The port reuses upstream's donated catalogue: po/ came across from Junction's
# l10n branch untouched, and the domain stays upstream's app id, because a .mo
# is found by domain name (see JunctionRb::TEXT_DOMAIN). po/*.po are the
# translators' work and are never edited here — only rmsgmerge touches them,
# and only when the message set genuinely changes.
require "fileutils"
require "tmpdir"

TEXT_DOMAIN = "re.sonny.Junction"
PO_DIR = File.expand_path("po", __dir__)
LOCALE_DIR = File.expand_path("locale", __dir__)

begin
  require "gettext/tools/task"

  GetText::Tools::Task.define do |task|
    task.domain = TEXT_DOMAIN
    task.package_name = "Junction"
    task.files = Dir.glob(File.expand_path("lib/**/*.rb", __dir__)) +
      Dir.glob(File.expand_path("exe/*", __dir__))
    task.po_base_directory = PO_DIR
    task.mo_base_directory = LOCALE_DIR
    # Read from LINGUAS rather than globbed from po/*.po, so a language that
    # loses its file loses it loudly instead of silently.
    task.locales = File.read(File.join(PO_DIR, "LINGUAS")).split
    # The gem's Ruby parser drops translator comments unless asked; every one
    # of them exists to prevent a specific mistranslation.
    task.xgettext_options = ["--add-comments=TRANSLATORS"]
  end
rescue LoadError
  desc("(stub) gettext tasks are unavailable")
  task("gettext:mo:update") do
    warn("NOTE: the gettext gem isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
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

# Upstream registers desktop-file-validate, appstreamcli and glib-compile-schemas
# as meson tests with `required: false`, so a build host without them still
# builds. Same contract here: a missing validator is reported and skipped, a
# failing one fails the task.
def with_program(name)
  ENV
    .fetch("PATH", "")
    .split(File::PATH_SEPARATOR)
    .any? { |dir| File.executable?(File.join(dir, name)) }
    .then do |found|
      if found
        yield
      else
        warn("NOTE: #{name} is not on PATH; skipping it")
      end
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
    with_program("update-desktop-database") do
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
    with_program("gtk4-update-icon-cache") do
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
    with_program("desktop-file-validate") do
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
  end

  desc "Validate the AppStream metainfo with appstreamcli"
  task :metainfo do
    with_program("appstreamcli") do
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
  end

  # --strict turns glib-compile-schemas' warnings into errors, which is how
  # upstream runs it as a test; `rake schema` deliberately does not, because
  # that one builds the cache the app reads.
  desc "Validate the GSettings schema with glib-compile-schemas --strict"
  task :schema do
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
