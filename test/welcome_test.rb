# frozen_string_literal: true

# The welcome window — what Junction shows when it is launched with nothing to
# open.
#
# The "Set Junction as default for Web" button is deliberately never activated
# here: it runs `gio mime` against the real session and would change which
# browser the machine opens links with. What it would do is checked instead.

$stdout.sync = true

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('junction-rb-config')
ENV['GSETTINGS_BACKEND'] = 'memory'

require_relative '../lib/junction_rb'
require_relative 'gtk_driver'

app = JunctionRb::Application.new

GtkDriver.drive(app, shots: 'tmp/shots') do |d, _app|
  d.window { app.welcome_window.window }

  d.step('launching with nothing to open shows the welcome window') do
    d.check('the window is titled Junction') do
      app.welcome_window.window.title == 'Junction'
    end
    d.check('it is visible') { app.welcome_window.window.visible? }
    d.shot('07-welcome')
  end

  d.step('it offers a way in and a way to try it') do
    d.check('the demo link points at the demo page') do
      app.welcome_window.demo_button.uri == 'https://junction.sonny.re/demo'
    end
    d.check('the install button says what it does') do
      app.welcome_window.install_button.label == 'Set Junction as default for Web'
    end
    d.check('about is reachable from the header bar') do
      app.welcome_window.about_button.action_name == 'app.about'
    end
    d.check('the app icon is used') do
      app.welcome_window.icon.icon_name == JunctionRb::APPLICATION_ID
    end
  end

  d.step('installing would claim the web types') do
    d.check('http and https are claimed') do
      (JunctionRb::WelcomeWindow::WEB_TYPES &
        ['x-scheme-handler/http', 'x-scheme-handler/https']).length == 2
    end
    d.check('the local web documents are claimed too') do
      (JunctionRb::WelcomeWindow::WEB_TYPES &
        ['text/html', 'text/xml', 'application/xhtml+xml']).length == 3
    end
    d.check('it would register this port, not the original') do
      JunctionRb::DESKTOP_ID == 're.sonny.Junction.Rb.desktop'
    end
  end

  # Junction lives as a background service, so closing the welcome window must
  # not take the process with it — the next link still has to be dispatched.
  d.step('closing it hides rather than destroys') do
    d.check('the window hides on close') { app.welcome_window.window.hide_on_close? }
    app.welcome_window.window.close
  end

  d.step('and it can be shown again') do
    d.check('it is hidden') { !app.welcome_window.window.visible? }
    app.welcome_window.present
  end

  d.step('the same window comes back') do
    d.check('visible again') { app.welcome_window.window.visible? }
  end
end
