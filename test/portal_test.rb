# frozen_string_literal: true

# The portal, and the development-only branches.
#
# The background request goes over real DBus to the real portal — it asks for
# permission to keep running, which is a question the portal answers from the
# user's existing settings rather than a change to them, so it is safe to make
# here. The autostart command it names is Junction's own service invocation.
#
# open_directory is NOT exercised: it would put a file manager window on the
# desktop. The part that could plausibly break in a Ruby port — building the
# XdpParent handle out of a Gtk::Window — is checked on its own.

$stdout.sync = true

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('junction-rb-config')
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

# --- The typelibs load -------------------------------------------------------

check('the Xdp typelib is loaded') { defined?(Xdp::Portal) == 'constant' }
check('the XdpGtk4 typelib is loaded') { XdpGtk4.respond_to?(:parent_new_gtk) }
check('a portal can be constructed') { !JunctionRb::Host.portal.nil? }
check('the sandbox test comes from libportal') do
  JunctionRb::Host.flatpak? == Xdp::Portal.running_under_flatpak
end

# --- The background request --------------------------------------------------

check('the autostart command names the service invocation') do
  JunctionRb::Host::AUTOSTART_COMMAND == ['junction-rb', '--gapplication-service']
end

check('the reason is a sentence the portal can show the user') do
  JunctionRb::Host::BACKGROUND_REASON.end_with?('.')
end

check('the AUTOSTART flag matches libportal') do
  JunctionRb::BackgroundRequest::AUTOSTART == Xdp::BackgroundFlags::AUTOSTART.to_i
end

# The whole point of the Fiddle path: ruby-gnome cannot marshal the GPtrArray
# this call needs, so if the request ever silently stops reaching the portal,
# this is what notices.
answered = nil

JunctionRb::BackgroundRequest.call(
  reason:  JunctionRb::Host::BACKGROUND_REASON,
  command: JunctionRb::Host::AUTOSTART_COMMAND,
) { |granted| answered = granted }

GLib::MainLoop.new.tap do |loop_|
  GLib::Timeout.add_seconds(10) do
    loop_.quit
    false
  end
  GLib::Timeout.add(100) do
    if answered.nil?
      true
    else
      loop_.quit
      false
    end
  end
  loop_.run
end

check('the portal answered the background request') { !answered.nil? }
check('the answer is a boolean, not a stub') { [true, false].include?(answered) }

# --- The parent handle -------------------------------------------------------

Gtk::Application.new('re.sonny.Junction.Rb.PortalTest', :default_flags).tap do |app|
  app.signal_connect('activate') do
    Adwaita::ApplicationWindow.new(app).then do |window|
      check('a Gtk window converts to an XdpParent') do
        !XdpGtk4.parent_new_gtk(window).nil?
      end
    end
    app.quit
  end
  app.run([$PROGRAM_NAME])
end

# --- Development branches ----------------------------------------------------

check('dev mode is off by default') do
  ENV.delete('JUNCTION_RB_DEV')
  !JunctionRb.dev?
end

check('the environment variable turns it on') do
  ENV['JUNCTION_RB_DEV'] = '1'
  JunctionRb.dev?
end

check('an empty value does not count as on') do
  ENV['JUNCTION_RB_DEV'] = ''
  !JunctionRb.dev?
end

ENV['JUNCTION_RB_DEV'] = '1'

check('dev mode registers the restart action') do
  JunctionRb::Application.new.tap(&:build).then do |application|
    !application.application.lookup_action('restart').nil?
  end
end

# GTK normalises what it is given: <Primary><Shift>Q is stored, and read back,
# as <Shift><Control>q.
check('and binds it to Ctrl+Shift+Q') do
  JunctionRb::Application.new.tap(&:build).then do |application|
    application.application.get_accels_for_action('app.restart') == ['<Shift><Control>q']
  end
end

ENV.delete('JUNCTION_RB_DEV')

check('without dev mode there is no restart action') do
  JunctionRb::Application.new.tap(&:build).then do |application|
    application.application.lookup_action('restart').nil?
  end
end

puts
puts(FAILURES.empty? ? 'PORTAL OK' : "PORTAL FAILED (#{FAILURES.length})")
exit(FAILURES.empty? ? 0 : 1)
