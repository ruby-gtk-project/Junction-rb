# frozen_string_literal: true

module JunctionRb
  # Junction is a dispatcher: the desktop hands it a link, it puts up a window
  # asking which application should get it, and gets out of the way. Launched
  # with nothing to open, it shows the welcome window instead.
  class Application
    def initialize(argv = [])
      @argv = argv
    end

    # GApplication reads argv the C way, so element 0 must be the program name —
    # pass a bare ARGV and the first URI is swallowed as argv[0], which turns
    # `junction-rb https://…` into a plain activate and shows the welcome window
    # instead of the chooser.
    def run = build.run([$PROGRAM_NAME, *@argv])

    def build
      application.tap do |app|
        app.signal_connect('startup') { start_up }
        app.signal_connect('open') { |_app, files, _hint| open(files) }
        app.signal_connect('activate') { activate }
        app.signal_connect('handle-local-options') { |_app, options| handle_options(options) }

        register_actions
      end
    end

    # HANDLES_OPEN, not HANDLES_COMMAND_LINE: GFile mangles URIs whose scheme
    # separator is not "//" (mailto:, about:), which is why Junction registers
    # its own x-junction: scheme for a page to wrap those in.
    # https://gitlab.gnome.org/GNOME/glib/-/issues/1886
    def application
      @application ||= Gtk::Application.new(APPLICATION_ID, :handles_open).tap do |app|
        app.set_option_context_parameter_string('[URI…]')
        app.set_option_context_description("<#{WEBSITE}>")
        app.add_main_option(
          TERMINATE_AFTER_INIT,
          0,
          GLib::OptionFlags::NONE,
          GLib::OptionArg::NONE,
          'Exit after initialization complete',
          nil,
        )
      end
    end

    # A start-up smoke test: bring everything up, then exit 0 without showing a
    # window. Returning -1 instead means "carry on and run normally".
    TERMINATE_AFTER_INIT = 'terminate_after_init'

    def handle_options(options)
      if options.contains?(TERMINATE_AFTER_INIT)
        0
      else
        -1
      end
    end

    def settings = @settings ||= Settings.new

    def start_up
      Adwaita.init
      load_style_sheet
      load_icons

      settings.apply_color_scheme
      settings.on_color_scheme_change { settings.apply_color_scheme }

      # Junction closes its window the moment it has dispatched, and a service
      # with no windows would exit — which would mean paying the whole start-up
      # cost again on the next link.
      unless application.remote?
        application.hold
      end

      claim_web_handler
    end

    # DBus activation ignores the desktop file's MimeType, so under Flatpak the
    # association has to be asserted from inside.
    # https://gitlab.gnome.org/GNOME/glib/-/issues/1960
    def claim_web_handler
      if Host.flatpak?
        ['x-scheme-handler/https', 'x-scheme-handler/http'].each do |type|
          Host.spawn_async("gio mime #{type} #{DESKTOP_ID}")
        end
      end
    end

    # One window per file: opening three links at once should ask three times,
    # not make the user pick one answer for all of them.
    def open(files)
      files.each do |file|
        Window.new(application: application, settings: settings, file: file).present
      end
    end

    def activate = welcome_window.present

    def welcome_window
      @welcome_window ||= WelcomeWindow.new(application: application)
    end

    # --- Actions -------------------------------------------------------------

    def register_actions
      application.add_action(quit_action)
      application.add_action(about_action)
      application.add_action(shortcuts_action)
      application.add_action(settings.create_action('color-scheme'))

      quit_action.signal_connect('activate') { application.quit }
      about_action.signal_connect('activate') { AboutDialog.new.present(active_window) }
      shortcuts_action.signal_connect('activate') { ShortcutsDialog.new.present(active_window) }

      ACCELERATORS.each { |action, keys| application.set_accels_for_action(action, keys) }
    end

    ACCELERATORS = {
      'app.quit'      => ['<Primary>Q'],
      'app.shortcuts' => ['<Primary>question'],
      # Escape as well as Ctrl+W: Junction is a transient prompt, and dismissing
      # it should feel like dismissing a dialog.
      'window.close'  => ['<Primary>W', 'Escape'],
      'win.copy'      => ['<Primary>C'],
    }.freeze

    def quit_action = @quit_action ||= Gio::SimpleAction.new('quit')

    def about_action = @about_action ||= Gio::SimpleAction.new('about')

    def shortcuts_action = @shortcuts_action ||= Gio::SimpleAction.new('shortcuts')

    def active_window = application.active_window

    # --- Style ---------------------------------------------------------------

    def load_style_sheet
      Gdk::Display.default.then do |display|
        if display
          Gtk::StyleContext.add_provider_for_display(
            display,
            css_provider,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
        end
      end
    end

    def css_provider
      @css_provider ||= Gtk::CssProvider.new.tap do |provider|
        provider.load_from_path(data_path('style.css'))
      end
    end

    # A checkout has its icons in data/icons rather than in an installed
    # hicolor tree, so the app icon in the about dialog and the welcome window
    # would otherwise render as the missing-image glyph.
    def load_icons
      Gdk::Display.default.then do |display|
        if display
          Gtk::IconTheme.get_for_display(display).add_search_path(data_path('icons'))
        end
      end
    end

    def data_path(name) = File.expand_path("../../data/#{name}", __dir__)
  end
end
