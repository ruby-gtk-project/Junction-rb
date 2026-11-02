# frozen_string_literal: true

# The applications the AppStream screenshots are taken against.
#
# Why this is separate from test/fixture_apps.rb: that set exists to make
# assertions sharp — it carries a hidden entry, two excluded entries and an
# action with no field code, because those are the branches the drive script
# has to walk. A software centre's screenshot wants the opposite: a grid that
# looks like the grid a user gets, with nothing in it that is there to fail.
#
# These entries are planted in a scratch XDG_DATA_HOME exactly as the drive
# fixtures are, so a capture is reproducible on a build machine that has no
# browser and no image viewer installed. Their Exec lines point at a script
# that does nothing: the screenshots never launch anything, and an Exec that
# did would be a surprise waiting for whoever runs this next.
#
# The Exec has to name a program that really exists. GIO drops a desktop entry
# whose executable it cannot resolve, and it drops it silently — the grid just
# comes up empty, with no warning to say why. `/bin/true` is not a file on
# NixOS, which is exactly how this was learnt.
#
# Icon names come from the Adwaita icon theme the dev shell ships, so every
# tile renders a real icon rather than falling back to Junction's own.
#
# Require this before lib/junction_rb: GIO reads XDG_DATA_HOME when it first
# builds its application index, and setting it afterwards is too late.

require 'fileutils'
require 'tmpdir'

module ScreenshotApps
  DATA_HOME = File.join(Dir.tmpdir, 'junction-rb-screenshots', 'data')
  APPLICATIONS = File.join(DATA_HOME, 'applications')
  NOOP = File.join(DATA_HOME, 'noop.sh')

  # The three browsers the link screenshot offers, and the three image
  # applications the file screenshot offers. Each is [id, name, icon, types].
  BROWSERS = [
    ['shot-web.desktop', 'Web', 'web-browser-symbolic'],
    ['shot-chronicle.desktop', 'Chronicle', 'help-browser-symbolic'],
    ['shot-reader.desktop', 'Reader', 'text-html'],
  ].freeze

  WEB_TYPES = 'x-scheme-handler/http;x-scheme-handler/https;text/html;'

  VIEWERS = [
    ['shot-loupe.desktop', 'Loupe', 'image-x-generic'],
    ['shot-drawing.desktop', 'Drawing', 'x-office-drawing'],
    ['shot-graphics.desktop', 'Graphics', 'applications-graphics-symbolic'],
  ].freeze

  IMAGE_TYPES = 'image/png;image/jpeg;'

  def self.install
    ENV['XDG_DATA_HOME'] = DATA_HOME
    FileUtils.rm_rf(DATA_HOME)
    FileUtils.mkdir_p(APPLICATIONS)
    write_noop
    BROWSERS.each do |(id, name, icon)|
      entry(
        id,
        name,
        icon,
        WEB_TYPES,
      )
    end
    VIEWERS.each do |(id, name, icon)|
      entry(
        id,
        name,
        icon,
        IMAGE_TYPES,
      )
    end
    # Without the cache GIO has no mime -> application index to answer
    # g_app_info_get_recommended_for_type from, and every grid comes up empty.
    system('update-desktop-database', APPLICATIONS, out: File::NULL, err: File::NULL)
  end

  def self.write_noop
    File.write(NOOP, "#!/bin/sh\nexit 0\n")
    FileUtils.chmod(0o755, NOOP)
  end

  def self.entry(id, name, icon, types)
    File.write(File.join(APPLICATIONS, id), <<~DESKTOP)
      [Desktop Entry]
      Type=Application
      Name=#{name}
      Icon=#{icon}
      Exec=#{NOOP} %U
      Terminal=false
      NoDisplay=false
      MimeType=#{types}
    DESKTOP
  end
end

ScreenshotApps.install
