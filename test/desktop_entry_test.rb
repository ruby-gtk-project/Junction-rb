# frozen_string_literal: true

# Reading a candidate application's desktop actions, and the host/sandbox
# helpers around launching.
#
# The action reading is checked against fixture .desktop files written here;
# discovery is checked against the applications test/fixture_apps.rb plants in
# a scratch XDG_DATA_HOME. It used to be checked against whatever the machine
# really had installed, on the belief that an application could not be planted
# because XDG_DATA_DIRS always includes the system directories — but
# XDG_DATA_HOME can be moved, and GIO reads the two the same way, so on a
# machine with no browser installed those checks were simply failing.

$stdout.sync = true

ENV['GSETTINGS_BACKEND'] = 'memory'

require 'tmpdir'
require 'fileutils'

# Plants applications Junction can discover, so the grid is the same on
# every machine and a launch leaves a trace on disk.
require_relative 'fixture_apps'

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

# --- Both sides of the sandbox ----------------------------------------------

# Upstream drives these branches by assigning over
# Xdp.Portal.running_under_flatpak (test/util.test.js:103-156). Host.flatpak?
# memoises, so assigning it does the same job here: without a seam every
# sandbox path in host.rb, desktop_entry.rb and application.rb is unreachable
# from a test run on the host, which is every test run there has ever been.
COMMAND_LINE = %(foo --bar hello='world' something="wow")

JunctionRb::Host.flatpak = false

check('on the host the command line is handed over as written') do
  JunctionRb::Host.prefix_command_line(COMMAND_LINE) == COMMAND_LINE
end

check('and a flatpak-spawn command is left alone') do
  JunctionRb::Host.prefix_command_line('flatpak-spawn foo') == 'flatpak-spawn foo'
end

JunctionRb::Host.flatpak = true

check('in the sandbox the command line is sent to the host') do
  JunctionRb::Host.prefix_command_line(COMMAND_LINE) ==
    %(flatpak-spawn --host foo --bar hello='world' something="wow")
end

check('and a command already going to the host is not wrapped twice') do
  JunctionRb::Host.prefix_command_line('flatpak-spawn foo') == 'flatpak-spawn foo'
end

# An icon under /usr or /etc means the host's copy, which is mounted at
# /run/host inside the sandbox; anywhere else means exactly what it says.
# https://github.com/flatpak/flatpak/issues/2538
JunctionRb::Host.flatpak = false
check('on the host /usr is itself') do
  JunctionRb::Host.host_path('/usr/share/hello.png') == '/usr/share/hello.png'
end

JunctionRb::Host.flatpak = true
check('in the sandbox /usr is the host mount') do
  JunctionRb::Host.host_path('/usr/share/hello.png') == '/run/host/usr/share/hello.png'
end

JunctionRb::Host.flatpak = false
check('on the host /etc is itself') do
  JunctionRb::Host.host_path('/etc/foo/hello.png') == '/etc/foo/hello.png'
end

JunctionRb::Host.flatpak = true
check('in the sandbox /etc is the host mount') do
  JunctionRb::Host.host_path('/etc/foo/hello.png') == '/run/host/etc/foo/hello.png'
end

JunctionRb::Host.flatpak = false
check('a home path is never rewritten on the host') do
  JunctionRb::Host.host_path('/home/foo/bar.png') == '/home/foo/bar.png'
end

JunctionRb::Host.flatpak = true
check('nor in the sandbox') do
  JunctionRb::Host.host_path('/home/foo/bar.png') == '/home/foo/bar.png'
end

JunctionRb::Host.flatpak = false
check('and neither is /opt on the host') do
  JunctionRb::Host.host_path('/opt/foo/bar.png') == '/opt/foo/bar.png'
end

JunctionRb::Host.flatpak = true
check('nor /opt in the sandbox') do
  JunctionRb::Host.host_path('/opt/foo/bar.png') == '/opt/foo/bar.png'
end

# The sandbox-only read path: os-release is looked for under /run/host. That
# mount is not there on a host run, so this exercises the prefix and the
# fall-back to the built-in defaults rather than a distribution's real file.
check('os-release still names something when read through /run/host') do
  !JunctionRb::Host.os_release['NAME'].to_s.empty?
end

# Back to whatever libportal says, so nothing after this runs under a pretend
# sandbox.
JunctionRb::Host.flatpak = nil

check('the seam hands the question back to libportal') do
  JunctionRb::Host.flatpak? == Xdp::Portal.running_under_flatpak
end

puts
puts(FAILURES.empty? ? 'DESKTOP ENTRY OK' : "DESKTOP ENTRY FAILED (#{FAILURES.length})")
exit(FAILURES.empty? ? 0 : 1)
