# frozen_string_literal: true

module JunctionRb
  # Everything that differs between running on the host and running inside a
  # Flatpak sandbox. The original reached for libportal for this; the two things
  # it actually asked libportal were "am I in a sandbox" (a file test) and "open
  # this file's folder" (Gtk::FileLauncher does it natively since GTK 4.10), so
  # the dependency buys nothing here.
  module Host
    FLATPAK_INFO = '/.flatpak-info'

    def self.flatpak? = File.exist?(FLATPAK_INFO)

    # Commands launched from inside the sandbox have to be handed back to the
    # host, or they run against the sandbox's own (nearly empty) filesystem.
    def self.prefix_command_line(command_line)
      if !flatpak? || command_line.start_with?('flatpak-spawn ')
        command_line
      else
        "flatpak-spawn --host #{command_line}"
      end
    end

    def self.spawn_sync(command_line)
      GLib::Spawn.command_line_sync(prefix_command_line(command_line))
    end

    def self.spawn_async(command_line)
      GLib::Spawn.command_line_async(prefix_command_line(command_line))
    end

    # Paths under /usr and /etc mean the host's copies when we are sandboxed,
    # and those are mounted at /run/host.
    # https://github.com/flatpak/flatpak/issues/2538
    def self.host_path(path)
      if flatpak? && ['/usr/', '/etc/'].any? { |parent| path.to_s.start_with?(parent) }
        File.join('/run/host', path)
      else
        path
      end
    end

    def self.flatpak_info
      GLib::KeyFile.new.tap do |key_file|
        key_file.load_from_file(FLATPAK_INFO, :none)
      end
    rescue StandardError
      nil
    end

    # The subset of /etc/os-release the about dialog reports. Missing or
    # unreadable means a plain "Linux" rather than a crash.
    def self.os_release
      { 'NAME' => 'Linux', 'ID' => 'Linux', 'PRETTY_NAME' => 'Linux' }
        .merge(parse_os_release(read_os_release))
    end

    def self.read_os_release
      if flatpak?
        prefix = '/run/host'
      else
        prefix = ''
      end
      ["#{prefix}/etc/os-release", "#{prefix}/usr/lib/os-release"]
        .filter_map { |path| File.read(path) rescue nil }
        .first
        .to_s
    end

    def self.parse_os_release(text)
      text.lines.filter_map do |line|
        line.strip.then do |stripped|
          if stripped.empty? || stripped.start_with?('#')
            nil
          else
            stripped.match(/\A([A-Z][A-Z_0-9]+)=(.*)\z/)
                    &.then { |match| [match[1], unquote(match[2])] }
          end
        end
      end.to_h
    end

    def self.unquote(value)
      GLib::Shell.unquote(value)
    rescue StandardError
      value
    end

    # The document portal hands out proxy paths under /run/user/N/doc. Launching
    # another app with one of those is a good way to have it open nothing, so we
    # ask flatpak for the real path behind it.
    # https://github.com/sonnyp/Junction/issues/56
    DOCUMENT_PORTAL_PATH = %r{\A/run/user/\d+/doc/.+/.+\z}

    def self.document_portal_path?(path) = DOCUMENT_PORTAL_PATH.match?(path.to_s)

    # Returns [stdout, stderr, exit_status]; raises rather than signalling
    # failure in the return value, hence the rescue at every call site.
    def self.real_path(document_path)
      spawn_sync(%(flatpak document-info "#{document_path}")).then do |(stdout, _stderr, status)|
        if status.zero?
          stdout.to_s.match(/^origin: (.*)$/)&.[](1)
        end
      end
    rescue StandardError
      nil
    end
  end
end
