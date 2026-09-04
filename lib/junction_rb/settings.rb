# frozen_string_literal: true

module JunctionRb
  # The two persisted preferences: whether app names show under the icons, and
  # the colour scheme the theme switcher writes.
  class Settings
    # Matches Adwaita::ColorScheme's numbering, which is what the original
    # stores and hands straight to the style manager.
    COLOR_SCHEMES = {
      0 => :default,
      1 => :force_light,
      2 => :prefer_light,
      3 => :prefer_dark,
      4 => :force_dark,
    }.freeze

    def settings = @settings ||= Gio::Settings.new(APPLICATION_ID, path: SETTINGS_PATH)

    def show_app_names? = settings.get_boolean('show-app-names')

    def color_scheme = settings.get_int('color-scheme')

    def color_scheme=(value)
      settings.set_int('color-scheme', value)
    end

    def apply_color_scheme
      Adwaita::StyleManager.default.color_scheme = COLOR_SCHEMES.fetch(color_scheme, :default)
    end

    def on_color_scheme_change(&block)
      settings.signal_connect('changed::color-scheme') { block.call }
    end

    # Both actions are stateful and bound straight to the key, so the menu
    # checkmarks and the stored value can never disagree.
    def create_action(key) = settings.create_action(key)

    def bind(key, object, property)
      settings.bind(
        key,
        object,
        property,
        :get,
      )
    end
  end
end
