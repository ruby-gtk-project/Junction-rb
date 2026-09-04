# frozen_string_literal: true

# Reading a candidate application's desktop actions, and the host/sandbox
# helpers around launching.
#
# The action reading is checked against fixture .desktop files rather than
# installed ones. Planting an application for Gio to discover is not possible
# here — GLib always includes the system data directories, so XDG_DATA_DIRS
# cannot be narrowed to a fixture directory — so discovery is checked against
# whatever the machine really has installed, and the parsing is checked against
# files written for the purpose.

$stdout.sync = true

ENV['GSETTINGS_BACKEND'] = 'memory'

require 'tmpdir'
require 'fileutils'

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

# Stands in for the Gio::AppInfo a real entry wraps. Only the four things
# DesktopEntry asks of one are needed, and `filename` is the one that matters:
# everything about actions is read from the file it points at.
StubAppInfo = Struct.new(
  :id,
  :display_name,
  :filename,
  :icon,
)

DIR = Dir.mktmpdir('junction-rb-desktop')

def fixture(name, body)
  File.join(DIR, name).tap { |path| File.write(path, body) }
end

def entry_for(name, body)
  JunctionRb::DesktopEntry.new(
    StubAppInfo.new(
      name,
      'Fixture',
      fixture(name, body),
      nil,
    ),
  )
end

# --- Actions -----------------------------------------------------------------

browser = entry_for('test-browser.desktop', <<~DESKTOP)
  [Desktop Entry]
  Type=Application
  Name=Test Browser
  Exec=test-browser %U
  Terminal=false
  MimeType=text/html;
  Actions=new-window;private;about;

  [Desktop Action new-window]
  Name=New Window
  Exec=test-browser --new-window %U

  [Desktop Action private]
  Name=New Private Window
  Exec=test-browser --incognito %u

  [Desktop Action about]
  Name=About Test Browser
  Exec=test-browser --about
DESKTOP

check('the Exec line is read') { browser.exec == 'test-browser %U' }

check('actions that take the resource are offered') do
  browser.actions.map(&:first) == %w[new-window private]
end

check('an action without a field code is dropped') do
  !browser.actions.map(&:first).include?('about')
end

check('%u counts as taking the resource') do
  browser.actions.map(&:first).include?('private')
end

check('actions keep the order of the desktop file') do
  browser.actions.first.first == 'new-window'
end

check('an action carries its human name') do
  browser.actions.map(&:last) == ['New Window', 'New Private Window']
end

check('the action Exec is read from its own group') do
  browser.action_exec('new-window') == 'test-browser --new-window %U'
end

check('an unknown action has no Exec') { browser.action_exec('nope').nil? }

plain = entry_for('test-viewer.desktop', <<~DESKTOP)
  [Desktop Entry]
  Type=Application
  Name=Test Viewer
  Exec=test-viewer %f
  Terminal=false
DESKTOP

check('an application with no Actions key offers none') { plain.actions.empty? }

declared = entry_for('test-liar.desktop', <<~DESKTOP)
  [Desktop Entry]
  Type=Application
  Name=Test Liar
  Exec=test-liar %U
  Terminal=false
  Actions=ghost;

  [Desktop Action ghost]
  Name=Ghost
DESKTOP

check('an action declared but not defined is skipped') { declared.actions.empty? }

missing = JunctionRb::DesktopEntry.new(
  StubAppInfo.new(
    'gone.desktop',
    'Gone',
    File.join(DIR, 'gone.desktop'),
    nil,
  ),
)

check('an unreadable desktop file yields no actions') { missing.actions.empty? }
check('an unreadable desktop file yields no Exec') { missing.exec.nil? }

check('an unknown action is refused rather than raising') do
  browser.launch_action('does-not-exist', 'https://example.com') == false
end

# --- Discovery ---------------------------------------------------------------

entries = JunctionRb::DesktopEntry.recommended_for('text/html')

check('something handles HTML on this machine') { entries.length.positive? }
check('nothing is offered twice') { entries.map(&:id).uniq.length == entries.length }
check('every candidate has a name') { entries.all? { |e| !e.name.to_s.empty? } }

check('Junction never offers itself') do
  JunctionRb::DesktopEntry::EXCLUDED.none? { |id| entries.map(&:id).include?(id) }
end

check('the exclusion list names both Junctions and the known clashes') do
  JunctionRb::DesktopEntry::EXCLUDED.include?(JunctionRb::DESKTOP_ID) &&
    JunctionRb::DesktopEntry::EXCLUDED.include?('re.sonny.Junction.desktop') &&
    JunctionRb::DesktopEntry::EXCLUDED.include?('com.properlypurple.braus.desktop') &&
    JunctionRb::DesktopEntry::EXCLUDED.include?('spacefm.desktop')
end

check('a content type nothing handles gives an empty list') do
  JunctionRb::DesktopEntry.recommended_for('application/x-nothing-handles-this').empty?
end

check('an unknown desktop id finds nothing') do
  JunctionRb::DesktopEntry.find(entries, 'nope.desktop').nil?
end

check('a known desktop id is found') do
  JunctionRb::DesktopEntry.find(entries, entries.first.id)&.id == entries.first.id
end

# --- Host and sandbox --------------------------------------------------------

check('outside a sandbox the command line is untouched') do
  JunctionRb::Host.prefix_command_line('test-browser %U') == 'test-browser %U'
end

check('an already-wrapped command is not wrapped twice') do
  JunctionRb::Host.prefix_command_line('flatpak-spawn --host x') == 'flatpak-spawn --host x'
end

check('a host path is only rewritten inside a sandbox') do
  JunctionRb::Host.host_path('/usr/share/icons/x.png') == '/usr/share/icons/x.png'
end

check('os-release is readable') { !JunctionRb::Host.os_release['NAME'].to_s.empty? }

check('a document portal path is recognised') do
  JunctionRb::Host.document_portal_path?('/run/user/1000/doc/abc123/file.odt')
end

check('an ordinary path is not mistaken for one') do
  !JunctionRb::Host.document_portal_path?('/home/someone/file.odt')
end

check('a spawned command comes back') do
  JunctionRb::Host.spawn_sync('echo junction').first.strip == 'junction'
end

puts
puts(FAILURES.empty? ? 'DESKTOP ENTRY OK' : "DESKTOP ENTRY FAILED (#{FAILURES.length})")
exit(FAILURES.empty? ? 0 : 1)
