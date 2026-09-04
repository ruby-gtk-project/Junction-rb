# frozen_string_literal: true

# The URL side of the main window, which behaves differently from the file side:
# the entry is editable, it opens showing the host rather than the tail, and an
# http link is marked as insecure.

$stdout.sync = true

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('junction-rb-config')
ENV['GSETTINGS_BACKEND'] = 'memory'

require_relative '../lib/junction_rb'
require_relative 'gtk_driver'

INSECURE = 'http://example.com/some/page'

app = JunctionRb::Application.new
window = nil

GtkDriver.drive(app, shots: 'tmp/shots') do |d, _app|
  d.window { window&.window }

  d.step('open an http URL') do
    app.open([Gio::File.new_for_commandline_arg(INSECURE)])
    window = ObjectSpace.each_object(JunctionRb::Window).first
  end

  d.step('the URL is read as a URL') do
    d.check('the scheme is http') { window.resource.scheme == 'http' }
    d.check('it asks for the http handler') do
      window.resource.content_type == 'x-scheme-handler/http'
    end
    d.check('the entry shows the URL') { window.uri_entry.text == INSECURE }
    d.check('a URL is editable') { window.uri_entry.entry.editable? }
    d.check('it starts at the host, not the tail') { window.uri_entry.entry.position.zero? }
    d.check('Open Location is not offered for a URL') do
      window.tiles.none? { |tile| tile.is_a?(JunctionRb::ShowInFolderButton) }
    end
    d.shot('06-url')
  end

  d.step('http is marked insecure') do
    d.check('the entry carries the warning icon') do
      window.uri_entry.entry.get_icon_name(:primary) == 'channel-insecure-symbolic'
    end
    d.check('the icon explains itself') do
      window.uri_entry.entry.get_icon_tooltip_text(:primary).to_s.include?('no security')
    end
    d.check('the warning is not clickable') do
      !window.uri_entry.entry.get_icon_activatable(:primary)
    end
  end

  d.step('editing the entry changes what would be opened') do
    window.uri_entry.entry.text = 'https://example.com/other'
    d.check('the entry took the edit') do
      window.uri_entry.text == 'https://example.com/other'
    end
    d.check('that is what the launcher would receive') do
      JunctionRb::Resource.parse_location(window.uri_entry.text) ==
        'https://example.com/other'
    end
  end

  # Right-clicking a tile offers that application's desktop actions. Whether any
  # installed browser declares one is not something a test can insist on, so the
  # check adapts: with actions, the menu fills and pops up; without, it stays
  # empty and nothing is shown.
  d.step('the actions menu reflects the desktop file') do
    window.tiles.grep(JunctionRb::AppButton).first.then do |tile|
      tile.popup_actions_menu

      d.check('the menu has one item per offered action') do
        tile.menu.n_items == tile.entry.actions.length
      end
      d.check('the popover follows whether there was anything to show') do
        tile.popover_menu.visible? == tile.entry.actions.length.positive?
      end
      d.check('rebuilding does not duplicate the items') do
        tile.popup_actions_menu
        tile.menu.n_items == tile.entry.actions.length
      end

      puts "      (#{tile.entry.name} declares #{tile.entry.actions.length} action(s))"
      tile.popover_menu.popdown
    end
  end

  d.step('the run-action target is a plain string pair') do
    window.window.lookup_action('run-action').then do |action|
      d.check('the action exists') { !action.nil? }
      d.check('it takes an array of strings') do
        action.parameter_type.to_s == 'as'
      end
      d.check('an unknown desktop id is ignored rather than crashing') do
        window.window.activate_action(
          'run-action',
          GLib::Variant.new(['nope.desktop', 'new-window']),
        )
        true
      end
    end
  end
end
