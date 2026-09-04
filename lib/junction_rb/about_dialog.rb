# frozen_string_literal: true

module JunctionRb
  # About, including the debug report the issue tracker asks for. The report
  # carries the versions and the environment variables that decide which
  # applications Junction can even see — XDG_DATA_DIRS above all, since an
  # empty app grid is nearly always that.
  class AboutDialog
    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::AboutDialog.new.tap do |d|
        d.application_name = 'Junction'
        d.application_icon = APPLICATION_ID
        d.developer_name = 'Sonny Piers'
        d.copyright = '© 2021-2024 Sonny Piers'
        d.license_type = Gtk::License::GPL_3_0_ONLY
        d.version = VERSION
        d.website = WEBSITE
        d.issue_url = 'https://github.com/sonnyp/Junction/issues'
        d.translator_credits = 'translator-credits'
        d.debug_info = debug_info
        d.developers = ['Sonny Piers https://sonny.re']
        d.designers = ['Sonny Piers https://sonny.re', 'Tobias Bernard <tbernard@gnome.org>']
        d.artists = ['Tobias Bernard <tbernard@gnome.org>']
        d.add_credit_section('Contributors', ['Patrick Decat https://github.com/pdecat'])
      end
    end

    def debug_info
      <<~INFO.strip
        Junction:
        version #{VERSION}
        programInvocationName #{$PROGRAM_NAME}
        argv #{ARGV.join(' ')}
        cwd #{Dir.pwd}

        Powered by:
        Ruby #{RUBY_VERSION}
        ruby-gnome #{GLib::BINDING_VERSION.join('.')}
        GTK #{Gtk::Version::STRING}
        GLib #{GLib::Version::STRING}
        #{flatpak_line}
        Environment:
        OS #{os_line}
        $XDG_DATA_DIRS #{ENV.fetch('XDG_DATA_DIRS', nil)}
        $PATH #{ENV.fetch('PATH', nil)}
        $FLATPAK_ID #{ENV.fetch('FLATPAK_ID', nil)}
        $XDG_CURRENT_DESKTOP #{ENV.fetch('XDG_CURRENT_DESKTOP', nil)}
        $XDG_SESSION_TYPE #{ENV.fetch('XDG_SESSION_TYPE', nil)}
      INFO
    end

    def os_line
      Host.os_release.then do |release|
        "#{release['NAME']} #{release['VERSION']}".strip
      end
    end

    def flatpak_line
      Host.flatpak_info.then do |info|
        if info
          "flatpak #{info.get_string('Instance', 'flatpak-version')}\n"
        else
          ''
        end
      end
    rescue StandardError
      ''
    end
  end
end
