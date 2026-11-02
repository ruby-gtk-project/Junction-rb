# frozen_string_literal: true

# Drives Junction in a process whose locale is German, and asserts German on
# real widgets.
#
# Why this is a separate script rather than more steps in
# test/drive_junction.rb: two of the three localisation layers are decided
# before any Ruby of ours runs, and cannot be switched afterwards.
#
#   * GLib::KeyFile only keeps the `Name[xx]` variants for the languages in the
#     process's language list, and it fixes that list when the file is loaded.
#     With no LANGUAGE set it keeps none, so `get_locale_string(group, "Name")`
#     returns the English however it is called — which is why the fixture's
#     `Name[de]` is invisible in drive_junction.rb's default-locale run.
#   * libintl, which translates the installed .desktop and the metainfo, also
#     reads the environment once.
#
# So this script puts LANGUAGE=de into its own environment and re-executes
# itself before requiring anything. test/drive_junction.rb stays under the
# default locale, where its 240-odd English assertions belong.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_locale.rb

LANGUAGE = 'de'

# The re-exec has to happen before `require "glib2"`, which is why it is the
# first thing in the file. ENV is inherited, so one hop is enough, and the
# guard is what stops it being more than one.
if ENV['LANGUAGE'] != LANGUAGE
  # LANGUAGE alone, and not LC_MESSAGES: this machine has no de_DE.UTF-8
  # locale generated, and setting LC_MESSAGES to one that does not exist earns
  # "Locale not supported by C library. Using the fallback 'C' locale." from
  # GTK. LANGUAGE is the variable gettext and GLib's key-file locale list both
  # consult first, and it needs no generated locale behind it.
  exec(
    { 'LANGUAGE' => LANGUAGE },
    RbConfig.ruby,
    __FILE__,
    *ARGV,
  )
end

require 'fileutils'
require 'tmpdir'

$stdout.sync = true

# The same isolation drive_junction.rb sets up: a scratch config directory and
# the memory GSettings backend, so a run never touches the real session.
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('junction-rb-locale-config')
ENV['GSETTINGS_BACKEND'] = 'memory'

require_relative 'fixture_apps'
require_relative '../lib/junction_rb'
require_relative 'gtk_driver'

SHOTS = File.expand_path('../tmp/shots-de', __dir__)
FileUtils.rm_rf(SHOTS)

FIXTURE_DIR = Dir.mktmpdir('junction-rb-locale-fixture')
PAGE = File.join(FIXTURE_DIR, 'page.html')
File.write(PAGE, '<!doctype html><title>fixture</title>')

# Every string below is a msgstr in po/de.po as committed. They are quoted
# here rather than computed, so a catalogue that stops carrying them fails this
# script instead of agreeing with it.
QUIT = 'Beenden'
CLIPBOARD = 'Kopiere in die Zwischenablage'
SHORTCUTS = 'Tastaturkürzel'
ABOUT = 'Über Junction'
DEMO = 'Junction testen'
INSTALL = 'Junction als Standard festlegen'
INSECURE = 'Diese Website ist nicht sicher. Ein Angreifer könnte alle deine gesendeten ' \
           'Informationen sehen oder den Inhalt kontrollieren, den du siehst.'

GtkDriver.drive(JunctionRb::Application.new, shots: SHOTS) do |d, app|
  d.window { app.welcome_window&.window }

  window = nil

  d.step('the process really is running in German') do
    d.check('LANGUAGE reached the process') { ENV.fetch('LANGUAGE', nil) == LANGUAGE }
    d.check('and the gettext gem resolved a German catalogue') do
      JunctionRb::MenuModel.send(:_, 'Quit') == QUIT
    end
  end

  d.step('the welcome window reads German on screen') do
    app.welcome_window.then do |welcome|
      d.check("its primary button is labelled #{INSTALL}") do
        welcome.install_button.label == INSTALL
      end
      d.check("its secondary button is labelled #{DEMO}") do
        welcome.demo_button.label == DEMO
      end
      d.check("the about button's tooltip is #{ABOUT}") do
        welcome.about_button.tooltip_text == ABOUT
      end
    end
  end

  # A shot goes in the step *after* the one that presented the widget: GTK
  # realises on the next turn of the main loop, and GtkDriver runs one step per
  # tick, so shooting in the same step gets "widget produced no render node".
  d.step('the welcome window renders') do
    d.shot('de-01-welcome', app.welcome_window.window)
  end

  d.step('a chooser window for a local file comes up') do
    JunctionRb::Window.new(
      application: app.application,
      settings:    app.settings,
      file:        Gio::File.new_for_path(PAGE),
    ).tap(&:build).then do |built|
      window = built
      built.window.present
      d.check('it has a menu button with a tooltip') do
        # "Main Menu" is one of the eight msgids the donated catalogues predate,
        # so there is no German for it yet; po/re.sonny.Junction.pot now carries
        # the msgid so a translator can supply one. This check is named for what
        # it actually establishes — the tooltip is set and comes from the
        # catalogue lookup — rather than dressed up as a translation check.
        !built.top_menu_button.tooltip_text.to_s.empty?
      end
    end
  end

  d.step('the chooser window renders') do
    d.shot('de-02-window', window.window)
  end

  insecure = nil

  d.step('the insecure-link hint is German') do
    JunctionRb::Window.new(
      application: app.application,
      settings:    app.settings,
      file:        Gio::File.new_for_uri('http://example.com/path?q=1'),
    ).tap(&:build).then do |built|
      insecure = built
      built.window.present
      d.check('the entry carries the German warning on its primary icon') do
        built.uri_entry.entry.get_icon_tooltip_text(:primary) == INSECURE
      end
    end
  end

  d.step('the insecure window renders') do
    d.shot('de-03-insecure', insecure.window)
  end

  d.step('the shortcuts dialog is German') do
    JunctionRb::ShortcutsDialog.new.tap(&:build).then do |dialog|
      d.check("the Quit row reads #{QUIT}") do
        dialog.item_for('Quit', '<Primary>Q').title == QUIT
      end
      d.check("the clipboard row reads #{CLIPBOARD}") do
        dialog.item_for('Copy to Clipboard', '<Primary>C').title == CLIPBOARD
      end
      d.check("the shortcuts row reads #{SHORTCUTS}") do
        dialog.item_for('Keyboard Shortcuts', '<Primary>question').title == SHORTCUTS
      end
      dialog.present(window.window)
    end
  end

  d.step('the shortcuts dialog renders over the chooser window') do
    d.shot('de-04-shortcuts', window.window)
  end

  # The component-parity check. An installed application's desktop actions
  # carry their own translations in its key file, and reading them with
  # GLib::KeyFile#get_string discards every one of them — which is what
  # lib/junction_rb/desktop_entry.rb did, so the right-click menu came up in
  # English in all 32 languages. Upstream's src/AppButton.js:187 uses
  # appInfo.get_action_name, a locale lookup; #locale_key is the port's.
  #
  # The fixture's new-window action has `Name[de]`, so under LANGUAGE=de the
  # two reads differ and only the locale read is right.
  d.step('an application\'s own desktop-action labels are localised') do
    JunctionRb::DesktopEntry
      .recommended_for('text/html')
      .then { |entries| JunctionRb::DesktopEntry.find(entries, 'fixture-viewer.desktop') }
      .then do |viewer|
        d.check('the fixture viewer is offered') { !viewer.nil? }
        d.check('its new-window action label is the German one from the key file') do
          viewer.actions.to_h['new-window'] == FixtureApps::LOCALISED_ACTION_LABEL
        end
        d.check('the untranslated read is still available and differs') do
          viewer.key('Desktop Action new-window', 'Name') == 'New Fixture Window'
        end
        d.check('and the Exec line is read untranslated, so launching still works') do
          viewer.action_exec('new-window').include?('%U')
        end
      end
  end

  d.step('the app is still standing at the end of all that') do
    d.check('the welcome window is visible') { app.welcome_window.window.visible? }
    d.check('and the chooser window is visible') { window.window.visible? }
  end
end
