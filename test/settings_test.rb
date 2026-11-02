# frozen_string_literal: true

# The two persisted preferences and the schema they live in.
#
# This is the test the port did not have when `JunctionRb::SETTINGS_PATH` went
# missing: `Settings#settings` is the first thing start-up touches, so a schema
# id, a path or a key name that does not match the installed schema takes the
# whole application down before a window is shown. Constructing a Settings and
# reading both keys is therefore a smoke test for start-up itself.
#
# GSettings is held in memory: with a session bus present the dconf backend
# would write the user's real preferences over DBus.

$stdout.sync = true

ENV['GSETTINGS_BACKEND'] = 'memory'

require_relative '../lib/junction_rb'

FAILURES = []

def check(description)
  yield.then do |ok|
    puts(ok ? "ok   #{description}" : "FAIL #{description}")
    unless ok
      FAILURES << description
    end
  end
rescue StandardError => e
  puts "FAIL #{description} (#{e.class}: #{e.message})"
  FAILURES << description
end

SCHEMA = File.read(
  File.expand_path('../data/schemas/re.sonny.Junction.Rb.gschema.xml', __dir__),
)

# --- The schema and the constants agree --------------------------------------

check('the path is defined') { !JunctionRb::SETTINGS_PATH.to_s.empty? }

check('it is the path the schema declares') do
  SCHEMA.include?(%(path="#{JunctionRb::SETTINGS_PATH}"))
end

check('the schema is the application id') do
  SCHEMA.include?(%(id="#{JunctionRb::APPLICATION_ID}"))
end

# --- Both keys read ----------------------------------------------------------

settings = JunctionRb::Settings.new

check('show-app-names reads') { [true, false].include?(settings.show_app_names?) }

check('and is off by default, as upstream has it') { settings.show_app_names? == false }

check('color-scheme reads') { settings.color_scheme.is_a?(Integer) }

check('and defaults to following the system') { settings.color_scheme.zero? }

# --- And write ---------------------------------------------------------------

check('color-scheme writes') do
  settings.color_scheme = 4
  settings.color_scheme == 4
end

check('the stored value is an Adwaita colour scheme') do
  JunctionRb::Settings::COLOR_SCHEMES.fetch(settings.color_scheme) == :force_dark
end

check('every scheme the switcher offers is one the style manager knows') do
  JunctionRb::ThemeSwitcher::SCHEMES.each_value.all? do |scheme|
    JunctionRb::Settings::COLOR_SCHEMES.key?(scheme)
  end
end

# --- The actions the menus target --------------------------------------------

# The theme switcher's three buttons target this one, and the menu's "Show App
# Names" item the other: both are bound straight to the key, so nothing else
# in the application writes either value.
check('the colour scheme is exposed as an action') do
  settings.create_action('color-scheme').name == 'color-scheme'
end

check('and so is the app-name toggle') do
  settings.create_action('show-app-names').name == 'show-app-names'
end

check('the theme switcher targets the application action') do
  JunctionRb::ThemeSwitcher::ACTION_NAME == 'app.color-scheme'
end

puts
puts(FAILURES.empty? ? 'SETTINGS OK' : "SETTINGS FAILED (#{FAILURES.length})")
exit(FAILURES.empty? ? 0 : 1)
