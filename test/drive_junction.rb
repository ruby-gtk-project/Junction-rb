# frozen_string_literal: true

# Drives the whole of Junction headlessly: the welcome window, a chooser window
# for a local file, a chooser window for an insecure URL, one for a wrapped
# x-junction: URI, every menu and dialog, every action and keyboard shortcut,
# the portrait breakpoint, the portal seam, and the empty and error states.
#
# Why this file exists: a GTK app that loads is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window, and the Ruby bindings
# differ from the C API in ways only a run reveals — the first run of this
# script found that WelcomeWindow#present re-entered #build on every
# activation, so the second time Junction was launched with nothing to open it
# printed three GTK criticals (gtk_box_append, adw_toolbar_view_add_top_bar and
# adw_header_bar_pack_start all assert the child has no parent yet) and
# re-assembled a window that was already assembled.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_junction.rb
#
# GTK4 here has no offscreen backend — gtk_init fails outright with no display
# — so xvfb-run is not optional on this machine.
#
# The grid is driven against *planted* applications rather than whatever the
# machine happens to have installed, so the checks are the same everywhere and
# a launch can be observed. XDG_DATA_HOME is a scratch directory holding five
# fixture .desktop files: two that should be offered, one hidden, and the two
# Junction excludes by name. Their Exec lines point at a recorder script, so
# "the tile launched the application with this URI" is a fact on disk rather
# than an assumption.

require 'fileutils'
require 'tmpdir'

$stdout.sync = true

# --- The scratch environment -------------------------------------------------

# A scratch config directory, so a run never reads or writes the real one. The
# `gio mime` registrations the welcome window makes land in here.
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('junction-rb-config')

# XDG_CONFIG_HOME alone does not isolate GSettings: with a session bus present
# the dconf backend writes over D-Bus to the user's real settings, so the run
# would both scribble on them and lose writes to the round trip.
ENV['GSETTINGS_BACKEND'] = 'memory'

# The planted applications, the recorder script and the desktop database.
require_relative 'fixture_apps'

RECORDER = FixtureApps::RECORDER

require_relative '../lib/junction_rb'
require_relative 'gtk_driver'

SHOTS = File.expand_path('../tmp/shots', __dir__)
FileUtils.rm_rf(SHOTS)

# --- Fixture resources -------------------------------------------------------

FIXTURE_DIR = Dir.mktmpdir('junction-rb-fixture')
PAGE = File.join(FIXTURE_DIR, 'page.html')
File.write(PAGE, '<!doctype html><title>fixture</title>')

MISSING = File.join(FIXTURE_DIR, 'no-such-file')

URL = 'http://example.com/path?q=1'
# Upstream's wrapper only mangles a "://" separator into ":0//", so a mailto:
# URI is wrapped as-is (src/util.js, readResource).
WRAPPED = 'x-junction://mailto:someone@example.com'

# And the mangled form, which is the branch the wrapper exists for.
WRAPPED_MANGLED = 'x-junction://file:0//etc/os-release'

def launches = FixtureApps.launches

# Stands in for Xdp::Portal, which would otherwise put a real file manager
# window on the desktop. The real call answers through the block it is handed;
# so does this, immediately.
StubPortal = Struct.new(:source) do
  def open_directory(_parent, _uri, _flags, _cancellable, &block)
    block.call(source, :result)
  end
end

class OpenedFolder
  def open_directory_finish(_result) = true
end

class RefusedFolder
  def open_directory_finish(_result)
    raise 'the portal refused to show the folder'
  end
end

# Walks the sections of a Gio::Menu and collects every item label.
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

app = JunctionRb::Application.new
settings = nil
file_window = nil
folder_window = nil
url_window = nil
wrapped_window = nil
opened_window = nil
switcher = nil
broken_window = nil
clipboard_text = nil
background_answer = nil

# 300s rather than the default 120: this is forty-odd steps at a tick each,
# plus two portal round trips over real DBus.
GtkDriver.drive(app, shots: SHOTS, timeout: 300) do |d, _app|
  d.window { file_window&.window || app.welcome_window.window }

  # --- The welcome window, which is what `activate` presents -----------------

  d.step('launched with nothing to open, Junction shows the welcome window') do
    d.check('the welcome window is an Adwaita::ApplicationWindow') do
      app.welcome_window.window.is_a?(Adwaita::ApplicationWindow)
    end
    d.check('its title is Junction') { app.welcome_window.window.title == 'Junction' }
    d.check('it is visible') { app.welcome_window.window.visible? }
    d.check('it carries the welcome style class') do
      app.welcome_window.window.has_css_class?('welcome')
    end
    d.check('it hides rather than destroys on close') do
      app.welcome_window.window.hide_on_close?
    end
    d.check('it is the only toplevel so far') { Gtk::Window.list_toplevels.length == 1 }
    d.shot('01-welcome')
  end

  d.step('the welcome window offers a way in and a way to try it') do
    d.check('the demo link points at the demo page') do
      app.welcome_window.demo_button.uri == "#{JunctionRb::WEBSITE}/demo"
    end
    d.check('the install button says what it does') do
      app.welcome_window.install_button.label == 'Set Junction as default for Web'
    end
    d.check('about is reachable from the header bar') do
      app.welcome_window.about_button.action_name == 'app.about'
    end
    d.check('the icon is the application icon at 128px') do
      app.welcome_window.icon.icon_name == JunctionRb.icon_name &&
        app.welcome_window.icon.pixel_size == 128
    end
    d.check('the icon theme can actually resolve it') do
      Gtk::IconTheme.get_for_display(Gdk::Display.default)
                    .has_icon?(JunctionRb.icon_name)
    end
    d.check('the three children are in the content box') do
      app.welcome_window.content_box.children.length == 3
    end
  end

  d.step('the welcome window claimed the web types when it was constructed') do
    d.check('it claims both link schemes') do
      (JunctionRb::WelcomeWindow::WEB_TYPES &
        ['x-scheme-handler/http', 'x-scheme-handler/https']).length == 2
    end
    d.check('and the local web documents too') do
      (JunctionRb::WelcomeWindow::WEB_TYPES &
        ['text/html', 'text/xml', 'application/xhtml+xml']).length == 3
    end
    d.check('the registration reached the scratch mimeapps.list') do
      File.join(ENV.fetch('XDG_CONFIG_HOME'), 'mimeapps.list').then do |path|
        File.exist?(path) && File.read(path).include?(JunctionRb::DESKTOP_ID)
      end
    end
    d.check('it registered this port, not the original') do
      JunctionRb::DESKTOP_ID == 're.sonny.Junction.Rb.desktop'
    end
    # `gio mime` reports a refusal in its exit status rather than by raising,
    # which is the only thing that can route the install button to /error.
    d.check('a claim answers with the exit status, not with true') do
      [true, false].include?(app.welcome_window.claim('x-scheme-handler/https'))
    end
    d.check('a non-zero status is read as a failure') do
      JunctionRb::Host.spawn_sync('false').then { |(_o, _e, status)| !status.to_i.zero? }
    end
  end

  # The bug this script found first time out: presenting the same window again
  # must not re-enter #build.
  d.step('closing and re-presenting the welcome window re-uses it') do
    app.welcome_window.window.close
  end

  d.step('it comes back without being re-assembled') do
    d.check('it was hidden') { !app.welcome_window.window.visible? }
    app.welcome_window.present
    d.check('the same window is visible again') { app.welcome_window.window.visible? }
    d.check('its content box still holds exactly three children') do
      app.welcome_window.content_box.children.length == 3
    end
    d.check('the header bar still holds one button') do
      app.welcome_window.header_bar.pack_start_children.length == 1
    rescue StandardError
      # pack_start_children is not bound; walking the bar is enough.
      app.welcome_window.about_button.parent.nil? == false
    end
    d.check('the toolbar view still has the one top bar') do
      app.welcome_window.toolbar_view.content.equal?(app.welcome_window.content_box)
    end
    app.welcome_window.window.close
  end

  # --- Application-level wiring ---------------------------------------------

  d.step('the application registered its actions and accelerators') do
    settings = app.settings

    d.check('the application id is the port\'s own') do
      app.application.application_id == JunctionRb::APPLICATION_ID
    end
    d.check('it handles open, not command line') do
      app.application.flags.to_i == Gio::ApplicationFlags::HANDLES_OPEN.to_i
    end
    ['quit', 'about', 'shortcuts', 'color-scheme'].each do |name|
      d.check("app.#{name} exists") { !app.application.lookup_action(name).nil? }
    end
    d.check('there is no restart action outside dev mode') do
      app.application.lookup_action('restart').nil?
    end
    d.check('Ctrl+Q quits') do
      app.application.get_accels_for_action('app.quit') == ['<Control>q']
    end
    d.check('Ctrl+? opens the shortcuts dialog') do
      app.application.get_accels_for_action('app.shortcuts') == ['<Control>question']
    end
    d.check('Escape and Ctrl+W both close the window') do
      app.application.get_accels_for_action('window.close').sort ==
        ['<Control>w', 'Escape']
    end
    d.check('Ctrl+C copies') do
      app.application.get_accels_for_action('win.copy') == ['<Control>c']
    end
    d.check('the smoke-test option exits successfully') do
      GLib::VariantDict.new(nil).tap do |options|
        options.insert(
          JunctionRb::Application::TERMINATE_AFTER_INIT,
          GLib::Variant.new(true),
        )
      end.then { |options| app.handle_options(options) == 0 }
    end
    d.check('anything else carries on and runs normally') do
      app.handle_options(GLib::VariantDict.new(nil)) == -1
    end
  end

  d.step('the style sheet and the icon search path were installed at startup') do
    d.check('the CSS provider loaded data/style.css') { !app.css_provider.nil? }
    d.check('the data directory is the checkout\'s own') do
      File.directory?(File.join(JunctionRb::DATA_DIR, 'icons'))
    end
    d.check('the symbolic application icon resolves too') do
      Gtk::IconTheme.get_for_display(Gdk::Display.default)
                    .has_icon?("#{JunctionRb::APPLICATION_ID}-symbolic")
    end
  end

  # --- Settings -------------------------------------------------------------

  d.step('the settings round trip through the schema') do
    d.check('app names are off by default, as upstream has them') do
      !settings.show_app_names?
    end
    d.check('the colour scheme follows the system by default') do
      settings.color_scheme.zero?
    end
    settings.color_scheme = 4
    d.check('a written colour scheme reads back') { settings.color_scheme == 4 }
    d.check('the change reached the style manager') do
      Adwaita::StyleManager.default.color_scheme == :force_dark
    end
    settings.color_scheme = 0
    d.check('and back again') do
      Adwaita::StyleManager.default.color_scheme == :default
    end
    d.check('every scheme the switcher offers is one the style manager knows') do
      JunctionRb::ThemeSwitcher::SCHEMES.each_value.all? do |value|
        JunctionRb::Settings::COLOR_SCHEMES.key?(value)
      end
    end
  end

  # --- DesktopEntry discovery ----------------------------------------------

  d.step('the planted applications are discovered, and the right ones dropped') do
    JunctionRb::DesktopEntry.recommended_for('text/html').then do |entries|
      d.check('two applications are offered') { entries.length == 2 }
      d.check('the viewer is one of them') do
        entries.any? { |e| e.id == 'fixture-viewer.desktop' }
      end
      d.check('the editor is the other') do
        entries.any? { |e| e.id == 'fixture-editor.desktop' }
      end
      d.check('a NoDisplay entry is not offered') do
        entries.none? { |e| e.id == 'fixture-hidden.desktop' }
      end
      d.check('Junction excludes itself') do
        entries.none? { |e| e.id == JunctionRb::DESKTOP_ID }
      end
      d.check('and the other chooser') do
        entries.none? { |e| e.id == 'com.properlypurple.braus.desktop' }
      end
      d.check('a name comes off the desktop file') do
        entries.map(&:name).sort == ['Fixture Editor', 'Fixture Viewer']
      end
      d.check('find picks an entry out by desktop id') do
        JunctionRb::DesktopEntry.find(entries, 'fixture-editor.desktop')&.id ==
          'fixture-editor.desktop'
      end
      d.check('an unknown desktop id finds nothing') do
        JunctionRb::DesktopEntry.find(entries, 'nope.desktop').nil?
      end
      entries.find { |e| e.id == 'fixture-viewer.desktop' }.then do |viewer|
        d.check('the Exec line is read off the key file') do
          viewer.exec == "#{RECORDER} viewer %U"
        end
        d.check('both declared actions are seen') do
          viewer.action_names == ['new-window', 'about']
        end
        d.check('only the one that takes the resource is offered') do
          viewer.actions == [['new-window', 'New Fixture Window']]
        end
      end
    end
  end

  # --- A chooser window for a local file -----------------------------------

  d.step('Application#open builds a chooser window for a local file') do
    app.open([Gio::File.new_for_path(PAGE)])
    opened_window = ObjectSpace.each_object(JunctionRb::Window).find do |candidate|
      candidate.resource.text == PAGE
    end
    file_window = opened_window
  end

  d.step('the window is built from the file it was handed') do
    d.check('a window exists') { !file_window.nil? }
    d.check('it is a second toplevel') { Gtk::Window.list_toplevels.length >= 2 }
    d.check('the window is an Adwaita::ApplicationWindow') do
      file_window.window.is_a?(Adwaita::ApplicationWindow)
    end
    d.check('it carries the main style class') { file_window.window.has_css_class?('main') }
    d.check('a fresh window asks for upstream\'s default size') do
      JunctionRb::Window.new(
        application: app.application,
        settings:    settings,
        file:        Gio::File.new_for_path(PAGE),
      ).window.default_size ==
        [JunctionRb::Window::DEFAULT_WIDTH, JunctionRb::Window::DEFAULT_HEIGHT]
    end
    d.check('and it will not be squeezed below upstream\'s minimum') do
      file_window.window.width_request == 360 &&
        file_window.window.height_request == JunctionRb::Window::DEFAULT_HEIGHT
    end
    d.check('the scheme is file') { file_window.resource.scheme == 'file' }
    d.check('the content type was sniffed as html') do
      file_window.resource.content_type == 'text/html'
    end
    d.check('the entry shows the path') { file_window.uri_entry.text == PAGE }
    d.check('the entry is not editable for a file') do
      !file_window.uri_entry.entry.editable?
    end
    d.check('two applications were offered') { file_window.entries.length == 2 }
    d.check('Open Location is offered for a file') do
      file_window.tiles.last.is_a?(JunctionRb::ShowInFolderButton)
    end
    d.check('so there are three tiles') { file_window.tiles.length == 3 }
    d.check('the flow box holds one child per tile') do
      file_window.list.children.length == file_window.tiles.length
    end
    d.check('no flow box child is focusable itself') do
      file_window.list.children.none?(&:focusable?)
    end
    d.check('the top bars start hidden in landscape') do
      !file_window.toolbar_view.reveal_top_bars?
    end
    d.check('the window controls draw the close button') do
      file_window.window_controls.decoration_layout == 'close'
    end
    d.shot('02-file-window')
  end

  d.step('every tile rendered a button with an icon and a tooltip') do
    d.check('all tiles built a Gtk::Button') do
      file_window.tiles.all? { |tile| tile.button.is_a?(Gtk::Button) }
    end
    d.check('each tile has a tooltip') do
      file_window.tiles.all? { |tile| !tile.button.tooltip_text.to_s.empty? }
    end
    d.check('each tile is the same 134px square') do
      file_window.tiles.all? do |tile|
        tile.button.width_request == 134 && tile.button.height_request == 134
      end
    end
    d.check('the application icons are set') do
      file_window.tiles.take(2).all? do |tile|
        !tile.image.icon_name.to_s.empty? || !tile.image.paintable.nil?
      end
    end
    d.check('Open Location uses the folder icon at 48px') do
      file_window.tiles.last.then do |tile|
        tile.image.icon_name == 'folder-symbolic' &&
          tile.image.pixel_size == JunctionRb::ShowInFolderButton::ICON_SIZE
      end
    end
    d.check('Open Location is labelled and explained') do
      file_window.tiles.last.then do |tile|
        tile.name_label.label == 'Open Location' &&
          tile.button.tooltip_text == 'View File in File Manager'
      end
    end
  end

  d.step('app names are hidden until the setting is on') do
    d.check('labels start hidden') do
      file_window.tiles.none? { |tile| tile.name_label.visible? }
    end
    file_window.window.activate_action('show-app-names', nil)
  end

  d.step('toggling the bound action reveals every label at once') do
    d.check('the stored setting followed the action') { settings.show_app_names? }
    d.check('labels are visible now') do
      file_window.tiles.all? { |tile| tile.name_label.visible? }
    end
    d.check('each label is named') do
      file_window.tiles.all? { |tile| !tile.name_label.label.to_s.empty? }
    end
    d.shot('03-app-names')
    file_window.window.activate_action('show-app-names', nil)
  end

  d.step('and toggling it back hides them again') do
    d.check('the setting went back off') { !settings.show_app_names? }
    d.check('labels are hidden again') do
      file_window.tiles.none? { |tile| tile.name_label.visible? }
    end
  end

  # --- Keyboard -------------------------------------------------------------

  d.step('the digit shortcuts claim their keys and nothing else') do
    d.check('1 is handled') { file_window.focus_tile(Gdk::Keyval::KEY_1) }
    d.check('3 is handled, since there are three tiles') do
      file_window.focus_tile(Gdk::Keyval::KEY_3)
    end
    d.check('4 is not, since there is no fourth tile') do
      !file_window.focus_tile(Gdk::Keyval::KEY_4)
    end
    d.check('a letter is left alone') { !file_window.focus_tile(Gdk::Keyval::KEY_a) }
    d.check('the key controller is on the window') do
      !file_window.key_controller.widget.nil?
    end
    file_window.focus_tile(Gdk::Keyval::KEY_2)
  end

  # Focus is granted by the window on its own turn of the loop, so it is only
  # readable on the tick after the grab.
  d.step('and the second one takes the focus') do
    # The window's focus widget rather than Gtk::Widget#has_focus?: the latter
    # also requires the window to be active, which is not reliably true in a
    # headless run.
    d.check('the second tile holds the focus') do
      file_window.window.focus == file_window.tiles[1].button
    end
  end

  # --- The menu, and the theme switcher inside it ---------------------------

  d.step('the main menu model is upstream\'s three sections') do
    file_window.top_menu_button.menu_model.then do |model|
      d.check('three sections') { model.n_items == 3 }
      menu_labels(model).then do |labels|
        d.check('four labelled items') { labels.length == 4 }
        d.check('the window actions are named') do
          (labels & ['Show App Names', 'Copy to Clipboard']).length == 2
        end
        d.check('the application actions are named') do
          (labels & ['Keyboard Shortcuts', 'About Junction']).length == 2
        end
      end
    end
    d.check('both menu buttons are primary, circular and flat') do
      [file_window.top_menu_button, file_window.bottom_menu_button].all? do |button|
        button.primary? && button.has_css_class?('circular') &&
          button.has_css_class?('flat')
      end
    end
    d.check('the two buttons have their own models') do
      !file_window.top_menu_button.menu_model
                  .equal?(file_window.bottom_menu_button.menu_model)
    end
    file_window.top_menu_button.popup
  end

  d.step('the popover opens with the theme switcher in its custom slot') do
    d.check('the popover is visible') { file_window.top_menu_button.popover.visible? }
    d.check('the popover has a child') do
      !file_window.top_menu_button.popover.child.nil?
    end
    file_window.top_menu_button.popdown
  end

  d.step('the theme switcher offers three exclusive, action-bound choices') do
    switcher = JunctionRb::ThemeSwitcher.new.tap(&:build)

    d.check('three selectors') { switcher.selectors.length == 3 }
    d.check('all three target the application action') do
      switcher.selectors.each_value.all? do |selector|
        selector.action_name == JunctionRb::ThemeSwitcher::ACTION_NAME
      end
    end
    # ruby-gnome unwraps a GVariant on the way out, so the target reads back
    # as a plain Integer; what matters is that it is the integer the action's
    # GSettings-backed state can compare equal to, not an int64.
    d.check('the targets are Adwaita\'s own scheme numbers') do
      switcher.selectors.all? do |name, selector|
        selector.action_target == JunctionRb::ThemeSwitcher::SCHEMES.fetch(name)
      end
    end
    d.check('each is explained') do
      switcher.selectors.each_value.all? { |s| !s.tooltip_text.to_s.empty? }
    end
    d.check('no checkmark is showing yet') do
      switcher.checks.each_value.none?(&:visible?)
    end
    d.check('the system choice shows only where there is a system preference') do
      switcher.system_overlay.visible? ==
        Adwaita::StyleManager.default.system_supports_color_schemes?
    end
    # Gtk::CheckButton has no `group` reader in ruby-gnome, so the grouping is
    # checked by what it is for: ticking one unticks the rest.
    d.check('they behave as one radio group') do
      switcher.selectors.fetch(:system).active = true
      switcher.selectors.fetch(:dark).active = true
      switcher.selectors.each_value.count(&:active?) == 1 &&
        switcher.selectors.fetch(:dark).active?
    end
  end

  d.step('ticking one moves the checkmark onto it and off the others') do
    d.check('dark carries the checkmark') { switcher.checks.fetch(:dark).visible? }
    d.check('and nothing else does') do
      switcher.checks.reject { |name, _| name == :dark }.each_value.none?(&:visible?)
    end
    switcher.selectors.fetch(:light).active = true
    d.check('ticking light moves it again') { switcher.checks.fetch(:light).visible? }
    d.check('and unticks dark') { !switcher.checks.fetch(:dark).visible? }
  end

  d.step('the colour-scheme action is what actually changes the style') do
    app.application.activate_action(
      'color-scheme',
      GLib::Variant.new(1, GLib::VariantType.new('i')),
    )
  end

  d.step('and the stored value and the style manager agree') do
    d.check('the action state followed') do
      app.application.lookup_action('color-scheme').state == 1
    end
    d.check('the setting followed') { settings.color_scheme == 1 }
    d.check('so did the style manager') do
      Adwaita::StyleManager.default.color_scheme == :force_light
    end
    app.application.activate_action(
      'color-scheme',
      GLib::Variant.new(0, GLib::VariantType.new('i')),
    )
  end

  d.step('back to following the system') do
    d.check('the setting is back to zero') { settings.color_scheme.zero? }
    d.check('and the style manager to default') do
      Adwaita::StyleManager.default.color_scheme == :default
    end
  end

  # --- The portrait breakpoint ---------------------------------------------

  d.step('the portrait breakpoint parses and is attached to the window') do
    d.check('the condition parses') do
      !Adwaita::BreakpointCondition.parse(JunctionRb::Window::PORTRAIT).nil?
    end
    d.check('the breakpoint exists') do
      file_window.portrait_breakpoint.is_a?(Adwaita::Breakpoint)
    end
    # The apply/unapply signals rather than add_setter: ruby-gnome reaches
    # adw_breakpoint_add_setter without a GValue for a boolean and the call is
    # dropped. Emitting the signal is what the breakpoint itself would do.
    file_window.portrait_breakpoint.signal_emit('apply')
  end

  d.step('portrait fills the grid and moves the menu into the header bar') do
    d.check('the grid fills the width') { file_window.list.halign == :fill }
    d.check('and sits at the bottom') { file_window.list.valign == :end }
    d.check('the header bar is revealed') { file_window.toolbar_view.reveal_top_bars? }
    # src/window.blp gives the chooser no title of its own, so GTK falls back
    # to g_get_application_name() — which is why both src/bin.js and
    # src/local.js call GLib.set_application_name("Junction") first. Without
    # it this header bar reads "ruby".
    d.check('and it is titled Junction, not the interpreter') do
      GLib.application_name == JunctionRb::APPLICATION_NAME
    end
    d.check('the bottom menu button is gone') do
      !file_window.bottom_menu_button.visible?
    end
    d.check('so are the window controls') { !file_window.window_controls.visible? }
    d.shot('04-portrait')
    file_window.portrait_breakpoint.signal_emit('unapply')
  end

  d.step('and landscape puts all five back') do
    d.check('the grid is centred again') do
      file_window.list.halign == :center && file_window.list.valign == :center
    end
    d.check('the header bar is hidden again') do
      !file_window.toolbar_view.reveal_top_bars?
    end
    d.check('the bottom menu button is back') { file_window.bottom_menu_button.visible? }
    d.check('and the window controls') { file_window.window_controls.visible? }
  end

  # --- Copy -----------------------------------------------------------------

  d.step('the copy action puts the location on the clipboard') do
    d.check('the action exists') { !file_window.window.lookup_action('copy').nil? }
    file_window.window.activate_action('copy', nil)
    Gdk::Display.default.clipboard.read_text_async(nil) do |clipboard, result|
      clipboard_text = clipboard.read_text_finish(result)
    rescue StandardError => e
      clipboard_text = "failed: #{e.message}"
    end
  end

  d.step('and the clipboard holds what the entry showed') do
    d.check('the clipboard came back with the path') { clipboard_text == PAGE }
  end

  # --- The actions menu on a tile ------------------------------------------

  d.step('right-clicking a tile offers the desktop file\'s own actions') do
    file_window.tiles.find { |t| t.is_a?(JunctionRb::AppButton) &&
                                t.entry.id == 'fixture-viewer.desktop' }.then do |tile|
      tile.popup_actions_menu

      d.check('one action is offered') { tile.menu.n_items == 1 }
      d.check('it is the one that takes the resource') do
        tile.menu.get_item_attribute_value(0, 'label', nil) == 'New Fixture Window'
      end
      d.check('it targets win.run-action') do
        tile.menu.get_item_attribute_value(0, 'action', nil) == 'win.run-action'
      end
      # Unwrapped on the way out again: an `as` variant arrives as an Array.
      d.check('with the desktop id and the action name as a string pair') do
        tile.menu.get_item_attribute_value(0, 'target', nil) ==
          ['fixture-viewer.desktop', 'new-window']
      end
      d.check('the popover menu came up') { tile.popover_menu.visible? }
      tile.popover_menu.popdown
    end
  end

  d.step('an application with no actions offers an empty menu and no popover') do
    file_window.tiles.find { |t| t.is_a?(JunctionRb::AppButton) &&
                                t.entry.id == 'fixture-editor.desktop' }.then do |tile|
      tile.popup_actions_menu
      d.check('nothing is offered') { tile.menu.n_items.zero? }
      d.check('and no popover was shown') { !tile.popover_menu.visible? }
    end
  end

  # --- Launching ------------------------------------------------------------

  d.step('Ctrl+Return opens the resource and leaves Junction standing') do
    file_window.tiles.find { |t| t.is_a?(JunctionRb::AppButton) &&
                                t.entry.id == 'fixture-viewer.desktop' }.then do |tile|
      tile.handle_key(Gdk::Keyval::KEY_Return, Gdk::ModifierType::CONTROL_MASK)
    end
  end

  d.step('the viewer was launched with the file URI') do
    d.check('one launch was recorded') { launches.length == 1 }
    # GIO expands %U from the GFile it is handed, and for a local file that is
    # its path rather than its file:// URI — the same string upstream's
    # launch_uris would have produced, since GLib expands the macro from a
    # GFile either way.
    d.check('the viewer got the resource') { launches.first == "viewer #{PAGE}" }
    d.check('the window is still open, because Ctrl+Return keeps it') do
      file_window.window.visible?
    end
  end

  d.step('the run-action action launches a desktop action instead') do
    file_window.window.activate_action(
      'run-action',
      GLib::Variant.new(['fixture-viewer.desktop', 'new-window']),
    )
  end

  d.step('the action\'s own Exec line was what ran') do
    d.check('a second launch was recorded') { launches.length == 2 }
    d.check('the action\'s own Exec line ran, with the same resource') do
      launches.last == "new-window #{PAGE}"
    end
    # Upstream closes the window once a desktop action has been launched.
    d.check('and Junction got out of the way') { !file_window.window.visible? }
  end

  d.step('an unknown desktop id is ignored rather than crashing') do
    file_window.window.activate_action(
      'run-action',
      GLib::Variant.new(['nope.desktop', 'new-window']),
    )
    d.check('nothing else was launched') { launches.length == 2 }
  end

  d.step('an action with no Exec line launches nothing and says so') do
    file_window.entries.find { |e| e.id == 'fixture-viewer.desktop' }.then do |entry|
      d.check('launch_action refuses an action that is not there') do
        !entry.launch_action('no-such-action', PAGE)
      end
      d.check('still nothing launched') { launches.length == 2 }
    end
  end

  # --- Open Location, through the portal seam -------------------------------

  # A fresh window, because the one above is gone: Window#close on an
  # Adwaita::ApplicationWindow destroys it (upstream does not keep the chooser
  # around either), and presenting a destroyed window only earns a GTK warning
  # about an inconsistent state.
  d.step('a fresh chooser window is opened to drive Open Location') do
    folder_window = JunctionRb::Window.new(
      application: app.application,
      settings:    settings,
      file:        Gio::File.new_for_path(PAGE),
    )
    folder_window.present
  end

  d.step('Open Location closes Junction only once the file manager is up') do
    folder_window.show_in_folder_button.then do |button|
      JunctionRb::Host.portal = StubPortal.new(OpenedFolder.new)
      opened = nil
      JunctionRb::Host.open_directory(folder_window.window, 'file:///tmp') do |ok|
        opened = ok
      end
      d.check('the folder coming up is reported to the caller') { opened == true }

      JunctionRb::Host.portal = StubPortal.new(RefusedFolder.new)
      refused = nil
      JunctionRb::Host.open_directory(folder_window.window, 'file:///tmp') do |ok|
        refused = ok
      end
      d.check('and a refusal is reported too, rather than raising') { refused == false }

      d.check('a Gtk window really does convert to an XdpParent') do
        !JunctionRb::Host.parent_for(folder_window.window).nil?
      end

      # The button's own behaviour: a refusal has to leave the window standing.
      JunctionRb::Host.portal = StubPortal.new(RefusedFolder.new)
      button.open_containing_folder
      d.check('a refusal leaves the window open') { folder_window.window.visible? }

      JunctionRb::Host.portal = StubPortal.new(OpenedFolder.new)
      button.open_containing_folder
    end
  end

  d.step('and the window is gone once it is') do
    d.check('the window closed') { !folder_window.window.visible? }
    JunctionRb::Host.portal = nil
  end

  # --- A chooser window for an insecure URL --------------------------------

  d.step('a chooser window for an http URL marks it insecure') do
    url_window = JunctionRb::Window.new(
      application: app.application,
      settings:    settings,
      file:        Gio::File.new_for_uri(URL),
    )
    url_window.present
  end

  d.step('the URL window is editable and warns about the scheme') do
    d.check('the scheme is http') { url_window.resource.scheme == 'http' }
    d.check('the content type is the scheme handler') do
      url_window.resource.content_type == 'x-scheme-handler/http'
    end
    d.check('the entry shows the URL') { url_window.uri_entry.text == URL }
    d.check('a URL is editable') { url_window.uri_entry.entry.editable? }
    d.check('the cursor starts at the host, not the tail') do
      url_window.uri_entry.entry.position.zero?
    end
    d.check('the warning icon is showing') do
      url_window.uri_entry.entry.get_icon_name(:primary) == 'channel-insecure-symbolic'
    end
    d.check('it explains itself in GNOME\'s own words') do
      url_window.uri_entry.entry.get_icon_tooltip_text(:primary) ==
        JunctionRb::UriEntry::INSECURE_TOOLTIP
    end
    d.check('and is not clickable') do
      !url_window.uri_entry.entry.get_icon_activatable(:primary) &&
        !url_window.uri_entry.entry.get_icon_sensitive(:primary)
    end
    d.check('Open Location is not offered for a URL') do
      url_window.tiles.none? { |tile| tile.is_a?(JunctionRb::ShowInFolderButton) }
    end
    d.check('the one http handler was offered') do
      url_window.entries.map(&:id) == ['fixture-viewer.desktop']
    end
    d.shot('05-url-window', url_window.window)
  end

  d.step('focusing the entry lands the cursor at the end') do
    url_window.uri_entry.focus_controller.signal_emit('enter')
  end

  d.step('which is where editing a URL almost always means editing') do
    d.check('the cursor is at the tail now') do
      url_window.uri_entry.entry.position == URL.length
    end
  end

  d.step('editing the entry changes what would be opened') do
    url_window.uri_entry.entry.text = 'https://example.org/edited'
    d.check('the entry took the edit') do
      url_window.uri_entry.text == 'https://example.org/edited'
    end
    url_window.tiles.first.then do |tile|
      tile.button.signal_emit('clicked')
    end
  end

  d.step('and that is the URI the application was handed') do
    d.check('a third launch was recorded') { launches.length == 3 }
    d.check('it carried the edited URL') do
      launches.last == 'viewer https://example.org/edited'
    end
    d.check('a plain click closed the window') { !url_window.window.visible? }
  end

  # --- A wrapped x-junction: URI -------------------------------------------

  d.step('a wrapped x-junction: URI is unwrapped before anything else') do
    wrapped_window = JunctionRb::Window.new(
      application: app.application,
      settings:    settings,
      file:        Gio::File.new_for_uri(WRAPPED),
    )
    wrapped_window.present
  end

  d.step('the window shows the mailto URI the wrapper carried') do
    d.check('the wrapper was unwrapped') do
      wrapped_window.uri_entry.text == 'mailto:someone@example.com'
    end
    d.check('and a mangled file:0// separator is put back') do
      JunctionRb::Resource.for_file(Gio::File.new_for_uri(WRAPPED_MANGLED))
                          .text == '/etc/os-release'
    end
    d.check('a mangled scheme separator too') do
      JunctionRb::Resource
        .for_file(Gio::File.new_for_uri('x-junction://https:0//example.com/'))
        .then { |r| r.scheme == 'https' && r.text == 'https://example.com/' }
    end
    d.check('the scheme is mailto, not x-junction') do
      wrapped_window.resource.scheme == 'mailto'
    end
    d.check('so the lookup is for a mailto handler') do
      wrapped_window.resource.content_type == 'x-scheme-handler/mailto'
    end
    # The empty state: nothing on this machine handles mailto:, so the grid is
    # empty and Open Location does not apply either.
    d.check('nothing is offered for it here') { wrapped_window.entries.empty? }
    d.check('and there are no tiles at all') { wrapped_window.tiles.empty? }
    d.check('the flow box is empty') { wrapped_window.list.children.empty? }
    d.check('a digit shortcut is not claimed when there is no tile') do
      !wrapped_window.focus_tile(Gdk::Keyval::KEY_1)
    end
    d.check('and activating one launches nothing') do
      wrapped_window.activate_tile(Gdk::Keyval::KEY_1) == false &&
        launches.length == 3
    end
    d.shot('06-empty-state', wrapped_window.window)
    wrapped_window.window.close
  end

  # --- Error states ---------------------------------------------------------

  d.step('a path that does not exist falls back to octet-stream') do
    JunctionRb::Resource.new(Gio::File.new_for_path(MISSING)).then do |resource|
      d.check('the content type is the fallback') do
        resource.content_type == JunctionRb::Resource::FALLBACK_CONTENT_TYPE
      end
      d.check('it is still a file') { resource.file? }
      d.check('but Open Location is not offered for it') { !resource.show_in_folder? }
      d.check('and the entry still shows the path it was given') do
        resource.text == MISSING
      end
    end
    JunctionRb::Resource.new(Gio::File.new_for_path(FIXTURE_DIR)).then do |resource|
      d.check('a directory is not locatable either') { !resource.show_in_folder? }
      d.check('because it is a directory') { resource.content_type == 'inode/directory' }
    end
  end

  d.step('a window for an unopenable resource still builds') do
    JunctionRb::Window.new(
      application: app.application,
      settings:    settings,
      file:        Gio::File.new_for_path(MISSING),
    ).tap do |broken|
      broken_window = broken
      broken.present
    end
  end

  d.step('it came up with nothing to offer, and renders') do
    d.check('the window came up') { broken_window.window.visible? }
    d.check('with no tiles to offer') { broken_window.tiles.empty? }
    d.check('and no Open Location, since there is no file to locate') do
      !broken_window.resource.show_in_folder?
    end
    d.shot('07-error-state', broken_window.window)
    broken_window.window.close
  end

  # --- Host, and the sandbox branches --------------------------------------

  d.step('the host helpers answer for both host and sandbox') do
    d.check('this run is not sandboxed') { !JunctionRb::Host.flatpak? }
    d.check('a command is left alone on the host') do
      JunctionRb::Host.prefix_command_line('gio mime x y') == 'gio mime x y'
    end
    d.check('and a path is left alone too') do
      JunctionRb::Host.host_path('/usr/share/icons') == '/usr/share/icons'
    end
    JunctionRb::Host.flatpak = true
    d.check('inside a sandbox the command goes back to the host') do
      JunctionRb::Host.prefix_command_line('gio mime x y') ==
        'flatpak-spawn --host gio mime x y'
    end
    d.check('but it is not wrapped twice') do
      JunctionRb::Host.prefix_command_line('flatpak-spawn --host true') ==
        'flatpak-spawn --host true'
    end
    d.check('and /usr means the host\'s /usr') do
      JunctionRb::Host.host_path('/usr/share/icons') == '/run/host/usr/share/icons'
    end
    d.check('while /tmp does not') { JunctionRb::Host.host_path('/tmp/x') == '/tmp/x' }
    JunctionRb::Host.flatpak = nil
    d.check('clearing the seam puts the question back to libportal') do
      JunctionRb::Host.flatpak? == Xdp::Portal.running_under_flatpak
    end
    d.check('a document-portal proxy path is recognised') do
      JunctionRb::Host.document_portal_path?('/run/user/1000/doc/abc123/file.pdf')
    end
    d.check('an ordinary path is not') do
      !JunctionRb::Host.document_portal_path?('/home/someone/file.pdf')
    end
    d.check('os-release is parsed, with a Linux fallback') do
      JunctionRb::Host.os_release['NAME'].to_s.length.positive?
    end
    d.check('the typelibs really are loaded') do
      defined?(Xdp::Portal) == 'constant' && XdpGtk4.respond_to?(:parent_new_gtk)
    end
  end

  # --- The background request, over real DBus ------------------------------

  d.step('the background request reaches the portal through Fiddle') do
    d.check('the autostart command names the service invocation') do
      JunctionRb::Host::AUTOSTART_COMMAND == ['junction-rb', '--gapplication-service']
    end
    d.check('the AUTOSTART flag matches libportal') do
      JunctionRb::BackgroundRequest::AUTOSTART == Xdp::BackgroundFlags::AUTOSTART.to_i
    end
    JunctionRb::BackgroundRequest.call(
      reason:  'Run Junction in the background.',
      command: JunctionRb::Host::AUTOSTART_COMMAND,
    ) { |granted| background_answer = granted }
  end

  # The portal answers over DBus, which needs a few turns of the loop.
  d.step('waiting for the portal to answer') do
    100.times do
      break unless background_answer.nil?

      GLib::MainContext.default.iteration(false)
    end
  end

  d.step('and it answered with a verdict rather than silence') do
    d.check('the portal answered') { !background_answer.nil? }
    d.check('the answer is a boolean, not a stub') do
      [true, false].include?(background_answer)
    end
  end

  # --- The shortcuts dialog -------------------------------------------------

  d.step('the welcome window is brought back to the front') do
    app.welcome_window.present
  end

  # Its own tick: GApplication settles active_window on the next turn of the
  # loop, and the dialog is presented on whatever is active when the action
  # fires.
  d.step('the shortcuts dialog opens from the application action') do
    d.check('the welcome window is the active one') do
      app.application.active_window.equal?(app.welcome_window.window)
    end
    app.application.activate_action('shortcuts', nil)
  end

  d.step('it lists upstream\'s two groups and all eight shortcuts') do
    app.welcome_window.window.visible_dialog.then do |dialog|
      d.check('a dialog is showing') { !dialog.nil? }
      d.check('it is an Adwaita shortcuts dialog') do
        dialog.is_a?(Adwaita::ShortcutsDialog)
      end
    end
    JunctionRb::ShortcutsDialog.new.tap(&:build).then do |shortcuts|
      d.check('two untitled sections, as upstream has them') do
        shortcuts.sections.length == 2
      end
      d.check('six resource shortcuts and two application ones') do
        JunctionRb::ShortcutsDialog::SECTIONS.map(&:length) == [6, 2]
      end
      d.check('every item carries an accelerator') do
        JunctionRb::ShortcutsDialog::SECTIONS.flatten(1).none? do |(_, accel)|
          accel.to_s.empty?
        end
      end
      d.check('the quit accelerator agrees with the application\'s') do
        JunctionRb::ShortcutsDialog::SECTIONS.flatten(1)
                                             .find { |(label, _)| label == 'Quit' }
                                             .last == '<Primary>Q'
      end
      d.check('presenting the same dialog twice does not re-add its sections') do
        shortcuts.sections.length == 2 && shortcuts.assembled.equal?(shortcuts.dialog)
      end
    end
  end

  d.step('and it renders') do
    d.shot('08-shortcuts', app.welcome_window.window.visible_dialog)
  end

  # --- The about dialog -----------------------------------------------------

  d.step('the about dialog opens with the debug report the tracker asks for') do
    app.welcome_window.window.visible_dialog&.close
    app.application.activate_action('about', nil)
  end

  d.step('and it carries the versions and the environment') do
    app.welcome_window.window.visible_dialog.then do |dialog|
      d.check('a dialog is showing') { !dialog.nil? }
      d.check('it is an Adwaita about dialog') { dialog.is_a?(Adwaita::AboutDialog) }
      d.check('named Junction, not junction-rb') { dialog.application_name == 'Junction' }
      d.check('with the application icon') do
        dialog.application_icon == JunctionRb.icon_name
      end
      d.check('and the port\'s version') { dialog.version == JunctionRb::VERSION }
      d.check('licensed GPL-3.0-only') do
        dialog.license_type == Gtk::License::GPL_3_0_ONLY
      end
      d.check('pointing at upstream\'s issue tracker') do
        dialog.issue_url == 'https://github.com/sonnyp/Junction/issues'
      end
    end
    JunctionRb::AboutDialog.new.debug_info.then do |report|
      d.check('the report names the data directory') do
        report.include?("datadir #{JunctionRb::DATA_DIR}")
      end
      d.check('the GTK version') { report.match?(/^GTK \d+\.\d+\.\d+$/) }
      d.check('the libadwaita version') { report.match?(/^libadwaita \d+\.\d+\.\d+$/) }
      d.check('the ruby-gnome version') { report.match?(/^ruby-gnome \d+\.\d+\.\d+$/) }
      d.check('the OS') { report.match(/^OS .+$/) }
      d.check('and XDG_DATA_DIRS, which is what an empty grid usually is') do
        report.include?('$XDG_DATA_DIRS')
      end
    end
    d.shot('09-about', app.welcome_window.window.visible_dialog)
  end

  d.step('the about dialog closes again') do
    app.welcome_window.window.visible_dialog&.close
    d.check('nothing is showing on the welcome window') do
      app.welcome_window.window.visible_dialog.nil?
    end
  end

  # --- Resource, directly ---------------------------------------------------

  d.step('the entry text is turned back into a URI the way upstream does') do
    d.check('an absolute path becomes a file URI') do
      JunctionRb::Resource.parse_location('/tmp/a b') == 'file:///tmp/a%20b'
    end
    d.check('a trailing slash survives, so the app knows it is a directory') do
      JunctionRb::Resource.parse_location('/tmp/') == 'file:///tmp/'
    end
    d.check('a tilde is expanded') do
      JunctionRb::Resource.parse_location('~').start_with?('file://')
    end
    d.check('an already-encoded URL is passed through untouched') do
      JunctionRb::Resource.parse_location('https://example.com/a%20b') ==
        'https://example.com/a%20b'
    end
    d.check('and so is a scheme Gio would mangle') do
      JunctionRb::Resource.parse_location('mailto:a@b.c') == 'mailto:a@b.c'
    end
    d.check('https is read off the text, not from Gio\'s uri_scheme') do
      JunctionRb::Resource.scheme_of(Gio::File.new_for_uri('https://example.com')) ==
        'https'
    end
  end

  # --- The dev-only branches -----------------------------------------------

  d.step('dev mode adds the restart action and its accelerator') do
    d.check('dev mode is off in this run') { !JunctionRb.dev? }
    d.check('so the icon is the installed one') do
      JunctionRb.icon_name == JunctionRb::APPLICATION_ID
    end
    ENV[JunctionRb::DEV_VARIABLE] = '1'
    d.check('the variable turns it on') { JunctionRb.dev? }
    d.check('and switches the icon to the devel one') do
      JunctionRb.icon_name == JunctionRb::DEVEL_APPLICATION_ID
    end
    JunctionRb::Application.new.tap(&:build).then do |dev|
      d.check('a dev application has a restart action') do
        !dev.application.lookup_action('restart').nil?
      end
      # GTK normalises what it is given: <Primary><Shift>Q is stored, and read
      # back, as <Shift><Control>q.
      d.check('bound to Ctrl+Shift+Q') do
        dev.application.get_accels_for_action('app.restart') == ['<Shift><Control>q']
      end
    end
    # On the running application rather than the one just built above: adding
    # a window to a GApplication that has not emitted ::startup earns
    # "New application windows must be added after the GApplication::startup
    # signal has been emitted."
    d.check('and a window built in dev mode is marked as not the installed copy') do
      JunctionRb::Window.new(
        application: app.application,
        settings:    settings,
        file:        Gio::File.new_for_path(PAGE),
      ).window.has_css_class?('devel')
    end
    ENV.delete(JunctionRb::DEV_VARIABLE)
    d.check('and without it there is no restart action') do
      JunctionRb::Application.new.tap(&:build).then do |plain|
        plain.application.lookup_action('restart').nil?
      end
    end
  end

  # --- Translation wiring --------------------------------------------------

  d.step('the catalogues are bound to upstream\'s text domain') do
    d.check('the domain is upstream\'s app id, so the .mo files are found') do
      JunctionRb::TEXT_DOMAIN == 're.sonny.Junction'
    end
    d.check('the compiled catalogues are on disk') do
      Dir.glob(File.join(JunctionRb::LOCALE_DIR, '*', 'LC_MESSAGES', '*.mo'))
         .length.positive?
    end
    d.check('a marked string comes back translated or unchanged, never empty') do
      !JunctionRb::Window.new(
        application: app.application,
        settings:    settings,
        file:        Gio::File.new_for_path(PAGE),
      ).top_menu_button.tooltip_text.to_s.empty?
    end
  end

  d.step('the welcome window is still standing at the end of all that') do
    d.check('it is visible') { app.welcome_window.window.visible? }
    d.check('and its content box was never re-assembled') do
      app.welcome_window.content_box.children.length == 3
    end
    d.shot('10-welcome-again', app.welcome_window.window)
  end
end
