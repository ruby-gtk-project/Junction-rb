# frozen_string_literal: true

# The URI handling, which is where Junction's awkward cases live: an https URL
# that Gio insists on calling http, the x-junction: wrapper that exists to carry
# schemes GFile mangles, and the entry text going back out as a URI.

$stdout.sync = true

ENV['GSETTINGS_BACKEND'] = 'memory'

require 'tmpdir'
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

def resource_for(uri) = JunctionRb::Resource.for_file(Gio::File.new_for_commandline_arg(uri))

# --- Scheme ------------------------------------------------------------------

check('https is reported as https, not http') do
  resource_for('https://example.com/page').scheme == 'https'
end

check('http stays http') { resource_for('http://example.com').scheme == 'http' }

check('a scheme is lowercased') { resource_for('HTTPS://example.com').scheme == 'https' }

check('mailto is recognised') { resource_for('mailto:someone@example.com').scheme == 'mailto' }

# --- Content type ------------------------------------------------------------

check('a URL asks for its scheme handler') do
  resource_for('https://example.com').content_type == 'x-scheme-handler/https'
end

check('https does not ask for the http handler') do
  resource_for('https://example.com').content_type != 'x-scheme-handler/http'
end

Dir.mktmpdir do |dir|
  File.join(dir, 'page.html').tap do |path|
    File.write(path, '<!doctype html><title>x</title>')

    JunctionRb::Resource.new(Gio::File.new_for_path(path)).tap do |resource|
      check('a local file is sniffed') { resource.content_type == 'text/html' }
      check('a local file has the file scheme') { resource.file? }
      check('the entry shows the plain path') { resource.text == path }
      check('a file offers Open Location') { resource.show_in_folder? }
    end
  end

  JunctionRb::Resource.new(Gio::File.new_for_path(dir)).tap do |resource|
    check('a directory is a directory') { resource.content_type == 'inode/directory' }
    check('a directory does not offer Open Location') { !resource.show_in_folder? }
  end

  File.join(dir, 'unknown.bin').tap do |path|
    File.binwrite(path, "\x00\x01\x02\x03")

    JunctionRb::Resource.new(Gio::File.new_for_path(path)).then do |resource|
      check('an unidentifiable file does not offer Open Location') do
        !resource.show_in_folder?
      end
    end
  end
end

check('a URL never offers Open Location') { !resource_for('https://example.com').show_in_folder? }

# --- The x-junction wrapper --------------------------------------------------

check('a wrapped https URL is unwrapped') do
  resource_for('x-junction://https://example.com/page').text == 'https://example.com/page'
end

check('a wrapped URL keeps its own scheme') do
  resource_for('x-junction://https://example.com').scheme == 'https'
end

check('the mangled scheme separator is restored') do
  resource_for('x-junction://https:0//example.com').text == 'https://example.com'
end

check('a mangled file URL is restored') do
  resource_for('x-junction://file:0//tmp/x').text == '/tmp/x'
end

# --- Entry text back out as a URI --------------------------------------------

check('an absolute path becomes a file URI') do
  JunctionRb::Resource.parse_location('/tmp/x') == 'file:///tmp/x'
end

check('a path with a space is escaped') do
  JunctionRb::Resource.parse_location('/tmp/a b') == 'file:///tmp/a%20b'
end

check('a tilde is expanded') do
  JunctionRb::Resource.parse_location('~').start_with?('file:///')
end

check('a tilde path is expanded') do
  JunctionRb::Resource.parse_location('~/x') == "file://#{Dir.home}/x"
end

check('an encoded URL is passed through untouched') do
  JunctionRb::Resource.parse_location('https://example.com/a%20b') ==
    'https://example.com/a%20b'
end

check('a query string survives') do
  JunctionRb::Resource.parse_location('https://example.com/?a=1&b=2') ==
    'https://example.com/?a=1&b=2'
end

puts
puts(FAILURES.empty? ? 'RESOURCE OK' : "RESOURCE FAILED (#{FAILURES.length})")
exit(FAILURES.empty? ? 0 : 1)
