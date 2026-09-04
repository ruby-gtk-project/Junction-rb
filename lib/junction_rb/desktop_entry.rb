# frozen_string_literal: true

module JunctionRb
  # A candidate application, and the launching that goes with it.
  #
  # Gio::AppInfo's action API (list_actions, get_action_name, launch_action) is
  # not bound in ruby-gnome, so the desktop actions are read straight out of the
  # .desktop key file. The original read the key file anyway — GLib cannot
  # launch an action with a URI argument, so it had to rewrite Exec by hand —
  # which makes the key file the single source for both here.
  # https://gitlab.gnome.org/GNOME/glib/-/issues/2568
  class DesktopEntry
    DESKTOP_GROUP = 'Desktop Entry'

    # Only actions that take the resource are worth offering: an action whose
    # Exec has no field code would ignore what the user asked to open.
    FIELD_CODES = %w[%U %u %f %F].freeze

    # Junction opening in Junction is a loop; Braus is another "which app?"
    # chooser, and SpaceFM claims to handle urls but does not.
    # https://github.com/properlypurple/braus/issues/26
    EXCLUDED = [
      DESKTOP_ID,
      're.sonny.Junction.desktop',
      'com.properlypurple.braus.desktop',
      'spacefm.desktop',
    ].freeze

    def self.recommended_for(content_type)
      Gio::AppInfo.get_recommended_for_type(content_type)
                  .reject { |app_info| EXCLUDED.include?(app_info.id) }
                  .select(&:should_show)
                  .map { |app_info| new(app_info) }
    end

    def self.find(entries, desktop_id) = entries.find { |entry| entry.id == desktop_id }

    attr_reader :app_info

    def initialize(app_info)
      @app_info = app_info
    end

    def id = app_info.id

    def name = app_info.display_name

    def icon = app_info.icon

    def key_file
      @key_file ||= app_info.filename.then do |filename|
        if filename
          load_key_file(filename)
        end
      end
    end

    def load_key_file(filename)
      GLib::KeyFile.new.tap do |file|
        file.load_from_file(filename, :none)
      end
    rescue StandardError => e
      warn "junction-rb: could not read #{filename}: #{e.message}"
      nil
    end

    def key(group, name)
      key_file&.get_string(group, name)
    rescue StandardError
      nil
    end

    def exec = key(DESKTOP_GROUP, 'Exec')

    # [[action_name, human_readable_label]] for the actions that actually accept
    # the resource, in the order the desktop file lists them.
    def actions
      @actions ||= action_names.filter_map do |action|
        action_exec(action).then do |command|
          if command && FIELD_CODES.any? { |code| command.include?(code) }
            [action, action_name(action) || action]
          end
        end
      end
    end

    def action_names
      key_file&.get_string_list(DESKTOP_GROUP, 'Actions').to_a.reject(&:empty?)
    rescue StandardError
      []
    end

    def action_group(action) = "Desktop Action #{action}"

    def action_exec(action) = key(action_group(action), 'Exec')

    def action_name(action) = key(action_group(action), 'Name')

    # --- Launching -----------------------------------------------------------

    # Launching the application itself. Inside a sandbox the command has to be
    # rerouted through the host, which means building a throwaway AppInfo from
    # the rewritten command line rather than using the one Gio handed us.
    def launch(location, content_type: nil)
      launch_app_info(Host.flatpak? ? host_app_info(exec) : app_info, location).tap do |success|
        if success && content_type && !Host.flatpak?
          remember_as_last_used(content_type)
        end
      end
    end

    # Launching one of the desktop actions. GLib has no API that passes a URI to
    # an action, so the action's own Exec line becomes the command.
    def launch_action(action, location)
      action_exec(action).then do |command|
        if command
          launch_app_info(host_app_info(command), location)
        else
          false
        end
      end
    end

    def host_app_info(command)
      if command
        Gio::AppInfo.create_from_commandline(
          Host.prefix_command_line(command),
          name,
          :supports_uris,
        )
      end
    rescue StandardError => e
      warn "junction-rb: could not build launcher for #{name}: #{e.message}"
      nil
    end

    def launch_app_info(target, location)
      if target.nil?
        false
      else
        Resource.parse_location(location).then do |uri|
          launch_uri(target, uri).tap do |success|
            unless success
              warn "junction-rb: could not launch #{location} with #{target.commandline}"
            end
          end
        end
      end
    rescue StandardError => e
      warn "junction-rb: could not launch #{location}: #{e.message}"
      false
    end

    def launch_uri(target, uri)
      Gdk::Display.default&.app_launch_context.then do |context|
        if target.supports_uris
          target.launch_uris([uri], context)
        else
          target.launch([Gio::File.new_for_uri(uri)], context)
        end
      end
    end

    # So the next launch of this type offers the same app first. Meaningless
    # under Flatpak, where the AppInfo we hold has no filename to write back to.
    def remember_as_last_used(content_type)
      app_info.set_as_last_used_for_type(content_type)
    rescue StandardError => e
      warn "junction-rb: could not record last used app: #{e.message}"
    end
  end
end
