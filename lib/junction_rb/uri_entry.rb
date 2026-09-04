# frozen_string_literal: true

module JunctionRb
  # The URI bar along the bottom. It is editable for URLs — the user may want to
  # trim a tracking parameter before handing the link on — but not for files,
  # where there is nothing useful to change.
  class UriEntry
    # The wording GNOME uses for the same warning, so it reads as part of the
    # desktop rather than as Junction's own invention.
    INSECURE_TOOLTIP = 'This site has no security. An attacker could see any ' \
                       'information you send, or control the content that you see.'

    def initialize(resource:)
      @resource = resource
    end

    def build
      entry.tap do |e|
        e.text = @resource.text

        if @resource.file?
          e.editable = false
          # A filename is most identifiable at its end.
          e.position = -1
        else
          # A URL is most identifiable at its start — that is where the host is.
          e.position = 0
        end

        if @resource.scheme == 'http'
          mark_insecure(e)
        end

        e.add_controller(focus_controller)

        focus_controller.tap do |controller|
          controller.signal_connect('enter') { scroll_to_end }
        end
      end

      entry
    end

    def text = entry.text

    def mark_insecure(target)
      target.set_icon_from_icon_name(:primary, 'channel-insecure-symbolic')
      target.set_icon_tooltip_text(:primary, INSECURE_TOOLTIP)
      target.set_icon_sensitive(:primary, false)
      target.set_icon_activatable(:primary, false)
    end

    # Focusing an entry selects all of it, and that happens after our handler
    # runs — so the deselect has to wait for the next turn of the main loop.
    # Landing at the end is what the user wants: editing a URL almost always
    # means editing its tail.
    def scroll_to_end
      GLib::Timeout.add(0) do
        entry.select_region(-1, 0)
        entry.position = -1
        GLib::Source::REMOVE
      end
    end

    def entry
      @entry ||= Gtk::Entry.new.tap do |e|
        e.hexpand = true
        e.input_purpose = :url
        e.xalign = 0.5
        e.add_css_class('uri')
      end
    end

    def focus_controller = @focus_controller ||= Gtk::EventControllerFocus.new
  end
end
