# frozen_string_literal: true

$stdout.sync = true

# Drives the main window against a real file: the grid fills with the apps the
# system recommends, the entry shows the path, the menus open, and the keyboard
# shortcuts land on the tiles they claim to.

require 'tmpdir'
require 'fileutils'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('junction-rb-config')
# XDG_CONFIG_HOME alone does not isolate GSettings: with a session bus present
# the dconf backend writes over D-Bus to the user's real settings, so the run
# would both scribble on them and lose writes to the round trip.
ENV['GSETTINGS_BACKEND'] = 'memory'

require_relative '../lib/junction_rb'
require_relative 'gtk_driver'

FIXTURE = File.join(Dir.mktmpdir('junction-rb-fixture'), 'page.html')
File.write(FIXTURE, '<!doctype html><title>fixture</title>')

app = JunctionRb::Application.new
window = nil

# Walks the three sections of the main menu and collects every item label.
def menu_labels(model)
  (0...model.n_items).flat_map do |index|
    model.get_item_link(index, 'section').then do |section|
      if section
        (0...section.n_items).map do |item|
          section.get_item_attribute_value(item, 'label', nil)
        end
      else
        []
      end
    end
  end.compact
end

GtkDriver.drive(app, shots: 'tmp/shots') do |d, _app|
  d.window { window&.window }

  d.step('open a local HTML file') do
    app.open([Gio::File.new_for_path(FIXTURE)])
    window = ObjectSpace.each_object(JunctionRb::Window).first
  end

  d.step('the window is built from the file') do
    d.check('a window exists') { !window.nil? }
    d.check('the scheme is file') { window.resource.scheme == 'file' }
    d.check('the content type is html') { window.resource.content_type == 'text/html' }
    d.check('the entry shows the path') { window.uri_entry.text == FIXTURE }
    d.check('the entry is not editable for files') { !window.uri_entry.entry.editable? }
    d.check('at least one application was offered') { window.entries.length.positive? }
    d.check('Open Location is offered for a file') do
      window.tiles.last.is_a?(JunctionRb::ShowInFolderButton)
    end
    d.check('Junction excludes itself') do
      window.entries.none? { |entry| entry.id == JunctionRb::DESKTOP_ID }
    end
    d.shot('01-window')
  end

  d.step('every tile rendered a button with an icon') do
    d.check('all tiles built') { window.tiles.all? { |tile| tile.button.is_a?(Gtk::Button) } }
    d.check('each tile has a tooltip') do
      window.tiles.all? { |tile| !tile.button.tooltip_text.to_s.empty? }
    end
    d.check('the flow box holds one child per tile') do
      window.list.children.length == window.tiles.length
    end
  end

  d.step('app names are hidden until the setting is on') do
    d.check('labels start hidden') { window.tiles.none? { |tile| tile.name_label.visible? } }
    window.window.activate_action('show-app-names', nil)
  end

  d.step('toggling the action reveals them') do
    d.check('labels now visible') { window.tiles.all? { |tile| tile.name_label.visible? } }
    d.check('each label is named') do
      window.tiles.all? { |tile| !tile.name_label.label.to_s.empty? }
    end
    d.shot('02-app-names')
    window.window.activate_action('show-app-names', nil)
  end

  d.step('and toggling it back hides them again') do
    d.check('labels hidden again') { window.tiles.none? { |tile| tile.name_label.visible? } }
  end

  d.step('the digit shortcut claims the key') do
    window.focus_tile(Gdk::Keyval::KEY_1).then do |handled|
      d.check('1 was handled') { handled }
    end
    d.check('a non-digit is left alone') { !window.focus_tile(Gdk::Keyval::KEY_a) }
    window.focus_tile(Gdk::Keyval::KEY_2)
  end

  # Focus is granted by the window on its own turn of the loop, so it is only
  # readable on the tick after the grab.
  d.step('and moves focus to that tile') do
    # The window's focus widget rather than Gtk::Widget#has_focus?: the latter
    # also requires the window to be active, which is not reliably true in a
    # headless run.
    d.check('the second tile holds the focus') do
      window.window.focus == window.tiles[1].button
    end
  end

  d.step('copy puts the location on the clipboard') do
    window.window.activate_action('copy', nil)
    d.check('the copy action exists') { !window.window.lookup_action('copy').nil? }
  end

  d.step('the main menu opens') do
    window.top_menu_button.popup
  end

  d.step('and shows the theme switcher') do
    labels = menu_labels(window.top_menu_button.menu_model)

    d.check('the popover is visible') { window.top_menu_button.popover.visible? }
    d.check('the theme switcher is in the popover') do
      !window.top_menu_button.popover.child.nil?
    end
    # The menu itself is a model rather than widgets, so it is checked rather
    # than screenshotted — a popover renders into its own surface and would not
    # appear in a screenshot of the window anyway.
    # Four labelled items across three sections; the fifth slot is the theme
    # switcher, a custom widget with no label of its own.
    d.check('the menu offers all four labelled items') { labels.length == 4 }
    d.check('the menu has three sections') { window.top_menu_button.menu_model.n_items == 3 }
    d.check('the menu names the window actions') do
      (labels & ['Show App Names', 'Copy to Clipboard']).length == 2
    end
    d.check('the menu names the application actions') do
      (labels & ['Keyboard Shortcuts', 'About Junction']).length == 2
    end
    window.top_menu_button.popdown
  end

  d.step('the shortcuts window opens') do
    app.application.activate_action('shortcuts', nil)
  end

  d.step('and lists both sections') do
    d.check('a dialog is showing') { !window.window.visible_dialog.nil? }
    d.shot('04-shortcuts', window.window.visible_dialog)
    window.window.visible_dialog&.close
  end

  d.step('the about dialog opens') do
    app.application.activate_action('about', nil)
  end

  d.step('and carries the debug report') do
    d.check('a dialog is showing') { !window.window.visible_dialog.nil? }
    d.check('the report names XDG_DATA_DIRS') do
      JunctionRb::AboutDialog.new.debug_info.include?('$XDG_DATA_DIRS')
    end
    d.check('the report names the GTK version') do
      JunctionRb::AboutDialog.new.debug_info.include?('GTK ')
    end
  end

  # A dialog needs a turn of the loop after it is presented before it has a
  # render node to screenshot.
  d.step('and is rendered') do
    d.shot('05-about', window.window.visible_dialog)
    window.window.visible_dialog&.close
  end
end
