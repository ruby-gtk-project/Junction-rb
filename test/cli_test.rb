# frozen_string_literal: true

# The command line, which is how Junction is always really invoked: the desktop
# hands it a URI as an argument.
#
# The argv[0] check here is not a formality. GApplication reads argv the C way,
# so passing a bare ARGV makes it take the first URI for the program name — the
# link is dropped and Junction shows its welcome window instead of the chooser,
# which is the one thing it exists not to do.

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

# Stands in for the Gtk::Application so run can be called without a main loop;
# all it does is record the argv it was handed.
class ArgvRecorder
  attr_reader :argv

  def run(argv)
    @argv = argv
    0
  end
end

recorder = ArgvRecorder.new

application = JunctionRb::Application.new(['https://example.com', '/tmp/x']).tap do |app|
  app.define_singleton_method(:build) { recorder }
  app.run
end

check('the application is invoked at all') { !recorder.argv.nil? }

check('argv[0] is the program name, not the first URI') do
  recorder.argv.first == $PROGRAM_NAME
end

check('every argument survives') do
  recorder.argv.drop(1) == ['https://example.com', '/tmp/x']
end

check('nothing is dropped') { recorder.argv.length == 3 }

check('running with no arguments still passes a program name') do
  ArgvRecorder.new.then do |empty|
    JunctionRb::Application.new.tap do |app|
      app.define_singleton_method(:build) { empty }
      app.run
    end
    empty.argv == [$PROGRAM_NAME]
  end
end

# --- Option handling ---------------------------------------------------------

application = JunctionRb::Application.new

check('the smoke-test option exits successfully') do
  GLib::VariantDict.new(nil).tap do |options|
    # A bare Ruby true segfaults the binding; the value has to be a Variant.
    options.insert(JunctionRb::Application::TERMINATE_AFTER_INIT, GLib::Variant.new(true))
  end.then { |options| application.handle_options(options) == 0 }
end

check('anything else carries on and runs normally') do
  application.handle_options(GLib::VariantDict.new(nil)) == -1
end

puts
puts(FAILURES.empty? ? 'CLI OK' : "CLI FAILED (#{FAILURES.length})")
exit(FAILURES.empty? ? 0 : 1)
