# frozen_string_literal: true

# Captures the three screenshots the AppStream metainfo points a software
# centre at, into docs/.
#
# Why this is a script and not three files someone took by hand: the metainfo
# claims a caption for each image, and a caption that no longer matches its
# picture is a lie a software centre repeats on every store page. Regenerating
# the set is one command, so a change to the chooser can be followed by a
# change to the pictures of it.
#
# It also makes the pictures possible at all on a build machine. Upstream's
# three screenshots are of a desktop with browsers and an image viewer
# installed; this one plants its own applications in a scratch XDG_DATA_HOME
# (test/screenshot_apps.rb), so the grid is the same everywhere and never the
# empty box that a machine with no browser would otherwise photograph.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/capture_screenshots.rb
#
# or `rake screenshots`. Each image is checked before it is written: a grid
# with no tiles in it fails the run rather than overwriting a good picture
# with an empty one.

require 'fileutils'
require 'tmpdir'

$stdout.sync = true

# A scratch config directory, so a capture never reads or writes the real one.
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('junction-rb-shot-config')

# XDG_CONFIG_HOME alone does not isolate GSettings: with a session bus present
# the dconf backend writes over D-Bus to the user's real settings.
ENV['GSETTINGS_BACKEND'] = 'memory'

# The applications the grids are made of. Before lib/junction_rb, always.
require_relative 'screenshot_apps'

require_relative '../lib/junction_rb'
require_relative 'gtk_driver'

SHOTS = File.expand_path('../docs', __dir__)

# The resource each screenshot is of. The link is upstream's own site, which
# is what its screenshot shows; the image lives under a short, readable path
# because the chooser puts that path on screen at the bottom of the picture.
LINK = 'https://junction.sonny.re'

#
# /tmp rather than Dir.tmpdir: inside the dev shell Dir.tmpdir is the
# per-invocation /tmp/nix-shell.XXXXXX, and a store page should not be showing
# anyone a build machine's scratch directory. Dir.home is worse again — it
# would put the developer's username in a committed PNG.
PICTURES = '/tmp/junction-rb-screenshots/Pictures'
PHOTO = File.join(PICTURES, 'photo.png')

FileUtils.mkdir_p(PICTURES)
FileUtils.cp(File.expand_path('../data/icons/re.sonny.Junction.Rb.png', __dir__), PHOTO)

# A phone-shaped window: narrower than the 360px minimum request would allow
# to shrink any further, and tall enough that the portrait breakpoint's
# bottom-aligned grid has somewhere to sit.
MOBILE_WIDTH = 360
MOBILE_HEIGHT = 640

app = JunctionRb::Application.new

link_window = nil
image_window = nil
mobile_window = nil

GtkDriver.drive(app, shots: SHOTS, timeout: 120) do |d, _app|
  d.window { app.welcome_window.window }

  # --- "Choose the browser to open the link with" ---------------------------

  d.step('a chooser window for a link') do
    link_window = JunctionRb::Window.new(
      application: app.application,
      settings:    app.settings,
      file:        Gio::File.new_for_uri(LINK),
    )
    link_window.present
  end

  d.step('the link grid is the three browsers') do
    d.check('the scheme is https') { link_window.resource.scheme == 'https' }
    d.check('three browsers were offered') do
      link_window.entries.map(&:id).sort ==
        ScreenshotApps::BROWSERS.map(&:first).sort
    end
    d.check('a link gets no Open Location tile') do
      link_window.tiles.none? { |tile| tile.is_a?(JunctionRb::ShowInFolderButton) }
    end
    # An application's icon comes off the desktop entry as a GIcon, so the
    # themed name is on the gicon rather than on Gtk::Image#icon_name. A tile
    # with neither is the blank square these pictures exist to rule out.
    d.check('every tile drew an icon') do
      link_window.tiles.all? do |tile|
        !tile.image.gicon.nil? || !tile.image.icon_name.to_s.empty? ||
          !tile.image.paintable.nil?
      end
    end
    d.check('the entry shows the link') { link_window.uri_entry.text == LINK }
    d.shot('window', link_window.window)
  end

  # --- "Choose the application to open the image with" ----------------------

  d.step('a chooser window for an image file') do
    image_window = JunctionRb::Window.new(
      application: app.application,
      settings:    app.settings,
      file:        Gio::File.new_for_path(PHOTO),
    )
    image_window.present
  end

  d.step('the image grid is the three viewers and the folder') do
    d.check('the content type was sniffed as a PNG') do
      image_window.resource.content_type == 'image/png'
    end
    d.check('three viewers were offered') do
      image_window.entries.map(&:id).sort ==
        ScreenshotApps::VIEWERS.map(&:first).sort
    end
    d.check('a file gets an Open Location tile') do
      image_window.tiles.last.is_a?(JunctionRb::ShowInFolderButton)
    end
    d.check('so the grid has four tiles') { image_window.tiles.length == 4 }
    d.shot('window-image', image_window.window)
  end

  # --- "Junction supports Linux mobile" -------------------------------------

  d.step('a phone-shaped chooser window') do
    mobile_window = JunctionRb::Window.new(
      application: app.application,
      settings:    app.settings,
      file:        Gio::File.new_for_uri(LINK),
    )
    mobile_window.window.set_default_size(MOBILE_WIDTH, MOBILE_HEIGHT)
    mobile_window.present
  end

  d.step('portrait folds the bottom bar away and reveals the header bar') do
    # The breakpoint's own signal rather than a resize: ruby-gnome cannot hand
    # adw_breakpoint_add_setter a boolean, so the port runs the five portrait
    # changes from apply/unapply, and emitting apply is what a real narrow
    # window would do. The same route the drive script takes.
    mobile_window.portrait_breakpoint.signal_emit('apply')
  end

  d.step('and that is the picture') do
    d.check('the header bar is revealed') { mobile_window.toolbar_view.reveal_top_bars? }
    d.check('the window controls are folded away') do
      !mobile_window.window_controls.visible?
    end
    d.check('the grid fills the width and sits at the bottom') do
      mobile_window.list.halign == :fill && mobile_window.list.valign == :end
    end
    d.check('the window is phone-shaped') do
      mobile_window.window.width <= MOBILE_WIDTH &&
        mobile_window.window.height > mobile_window.window.width
    end
    d.shot('window-mobile', mobile_window.window)
  end

  d.step('all three images were written') do
    ['window.png', 'window-image.png', 'window-mobile.png'].each do |name|
      d.check("docs/#{name} exists and is not empty") do
        File.join(SHOTS, name).then { |path| File.exist?(path) && File.size(path).positive? }
      end
    end
  end
end
