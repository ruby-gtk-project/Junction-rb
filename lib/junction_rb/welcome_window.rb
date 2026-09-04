# frozen_string_literal: true

module JunctionRb
  # What Junction shows when it is launched on its own rather than handed a
  # link. Junction is only useful once the desktop routes links to it, so the
  # window exists to offer exactly that, plus a link to try it with.
  class WelcomeWindow
    DEMO_URI = "#{WEBSITE}/demo"

    # The types worth claiming: web links, and the local files a browser would
    # otherwise open.
    WEB_TYPES = [
      'x-scheme-handler/http',
      'x-scheme-handler/https',
      'text/html',
      'text/xml',
      'application/xhtml+xml',
    ].freeze

    def initialize(application:)
      @application = application
    end

    def build
      window.tap do |win|
        win.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box

          header_bar.tap do |bar|
            bar.pack_start(about_button)
          end

          content_box.tap do |box|
            box.append(icon)
            box.append(demo_button)
            box.append(install_button)

            install_button.tap do |button|
              button.signal_connect('clicked') { install }
            end
          end
        end
      end
    end

    def present = build.present

    # The result page doubles as the confirmation: it is opened with whatever
    # now handles https, so seeing Junction ask which browser to use is itself
    # the proof it worked.
    def install
      Gtk::UriLauncher
        .new("#{WEBSITE}/#{set_as_default_for_web ? 'success' : 'error'}")
        .launch(window) { |launcher, result| finish_launch(launcher, result) }
    end

    def finish_launch(launcher, result)
      launcher.launch_finish(result)
    rescue StandardError => e
      warn "junction-rb: could not open the result page: #{e.message}"
    end

    def set_as_default_for_web
      WEB_TYPES.each { |type| Host.spawn_sync("gio mime #{type} #{DESKTOP_ID}") }
      true
    rescue StandardError => e
      warn "junction-rb: could not register as the default handler: #{e.message}"
      false
    end

    # Hidden rather than destroyed on close, so the application can present the
    # same window again without rebuilding it.
    def window
      @window ||= Adwaita::ApplicationWindow.new(@application).tap do |win|
        win.title = 'Junction'
        win.hide_on_close = true
        win.add_css_class('welcome')
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def about_button
      @about_button ||= Gtk::Button.new.tap do |button|
        button.action_name = 'app.about'
        button.icon_name = 'help-about-symbolic'
        button.tooltip_text = 'About Junction'
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 14).tap do |box|
        box.name = 'content'
        box.valign = :center
        box.halign = :center
        box.vexpand = true
        box.hexpand = true
      end
    end

    def icon
      @icon ||= Gtk::Image.new.tap do |image|
        image.icon_name = APPLICATION_ID
        image.pixel_size = 128
      end
    end

    def demo_button
      @demo_button ||= Gtk::LinkButton.new(DEMO_URI).tap do |button|
        button.label = 'Test Junction'
        button.valign = :center
        button.halign = :center
      end
    end

    def install_button
      @install_button ||= Gtk::Button.new(label: 'Set Junction as default for Web').tap do |button|
        button.valign = :center
        button.halign = :center
      end
    end
  end
end
