# frozen_string_literal: true

# A scratch XDG_DATA_HOME holding applications Junction can discover.
#
# Without this a test run asserts nothing about the grid: a build machine has
# no browser and no text editor installed, so `recommended_for("text/html")`
# comes back empty, every tile check is vacuous and anything that reaches for
# `tiles[1]` dies on nil. Planting the applications also makes a launch
# *observable* — the fixture Exec lines point at a recorder script, so "the
# tile launched this application with this resource" is a fact on disk.
#
# Require this before `lib/junction_rb`: GIO reads XDG_DATA_HOME when it first
# builds its application index, and setting it afterwards is too late.
#
# (An earlier note in test/desktop_entry_test.rb held that planting an
# application was impossible because XDG_DATA_DIRS always includes the system
# directories. XDG_DATA_HOME is the one that can be moved, and GIO reads the
# two the same way — so discovery can be pinned after all.)

require 'fileutils'
require 'tmpdir'

module FixtureApps
  DATA_HOME = Dir.mktmpdir('junction-rb-data')
  APPLICATIONS = File.join(DATA_HOME, 'applications')
  RECORDER = File.join(DATA_HOME, 'record.sh')
  LAUNCH_LOG = File.join(DATA_HOME, 'launches.log')

  # The two that should be offered, in the order their ids sort.
  OFFERED = ['fixture-editor.desktop', 'fixture-viewer.desktop'].freeze

  def self.install
    ENV['XDG_DATA_HOME'] = DATA_HOME
    FileUtils.mkdir_p(APPLICATIONS)
    write_recorder
    write_entries
    # Without the cache GIO has no mime -> application index to answer
    # g_app_info_get_recommended_for_type from, and the grid comes up empty.
    system('update-desktop-database', APPLICATIONS, out: File::NULL, err: File::NULL)
  end

  def self.write_recorder
    File.write(RECORDER, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" >> #{LAUNCH_LOG}
    SH
    FileUtils.chmod(0o755, RECORDER)
    File.write(LAUNCH_LOG, '')
  end

  # Everything the recorder has been asked to open so far, in order.
  def self.launches = File.read(LAUNCH_LOG).lines.map(&:strip).reject(&:empty?)

  def self.entry(name, body)
    File.write(File.join(APPLICATIONS, name), body)
  end

  def self.write_entries
    # Offered, and the one with desktop actions. `about` has no field code in
    # its Exec, so DesktopEntry#actions must drop it: an action that ignores
    # the resource is not worth offering.
    entry('fixture-viewer.desktop', <<~DESKTOP)
      [Desktop Entry]
      Type=Application
      Name=Fixture Viewer
      Exec=#{RECORDER} viewer %U
      Terminal=false
      NoDisplay=false
      MimeType=text/html;text/plain;x-scheme-handler/http;x-scheme-handler/https;
      Actions=new-window;about;

      [Desktop Action new-window]
      Name=New Fixture Window
      Exec=#{RECORDER} new-window %U

      [Desktop Action about]
      Name=About Fixture Viewer
      Exec=#{RECORDER} about
    DESKTOP

    # Offered, and takes a file rather than a URI.
    entry('fixture-editor.desktop', <<~DESKTOP)
      [Desktop Entry]
      Type=Application
      Name=Fixture Editor
      Exec=#{RECORDER} editor %f
      Terminal=false
      MimeType=text/html;text/plain;
    DESKTOP

    # Not offered: should_show is false for a NoDisplay entry.
    entry('fixture-hidden.desktop', <<~DESKTOP)
      [Desktop Entry]
      Type=Application
      Name=Fixture Hidden
      Exec=#{RECORDER} hidden %U
      Terminal=false
      NoDisplay=true
      MimeType=text/html;text/plain;
    DESKTOP

    # Not offered: Junction opening in Junction is a loop, and Braus is
    # another "which app?" chooser. Both are in DesktopEntry::EXCLUDED.
    entry('re.sonny.Junction.Rb.desktop', <<~DESKTOP)
      [Desktop Entry]
      Type=Application
      Name=Junction (this port)
      Exec=#{RECORDER} junction %U
      Terminal=false
      MimeType=text/html;text/plain;
    DESKTOP

    entry('com.properlypurple.braus.desktop', <<~DESKTOP)
      [Desktop Entry]
      Type=Application
      Name=Braus
      Exec=#{RECORDER} braus %U
      Terminal=false
      MimeType=text/html;text/plain;
    DESKTOP
  end
end

FixtureApps.install
