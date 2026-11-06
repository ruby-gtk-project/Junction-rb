# frozen_string_literal: true

module JunctionRb
  # The light / system / dark selector at the top of the main menu, ported from
  # troll's ThemeSelector widget (the submodule upstream's menu embeds in its
  # custom "themeswitcher" slot). The values are Adwaita::ColorScheme's own,
  # because that is what gets stored and handed straight to the style manager.
  #
  # The three buttons target the stateful `app.color-scheme` action, which
  # Settings#create_action binds to the GSettings key. That is the whole of the
  # wiring: GTK sets a button active when the action's state equals its target
  # and writes the target into the action when it is clicked, so the stored
  # value and the buttons cannot disagree and nothing here writes GSettings.
  class ThemeSwitcher
    include Translations

    SCHEMES = { light: 1, system: 0, dark: 4 }.freeze

    TOOLTIPS = {
      light:  N_('Light Style'),
      system: N_('Follow System Style'),
      dark:   N_('Dark Style'),
    }.freeze

    ACTION_NAME = 'app.color-scheme'

    def build
      box.tap do |b|
        SCHEMES.each_key { |name| b.append(overlays.fetch(name)) }
      end

      # Following a system preference is only meaningful where there is one to
      # follow. Upstream's ThemeSelector reconnects this on the style
      # manager's own notify signal so the button's visibility tracks a
      # desktop whose portal support changes while the app is running, not
      # just its value at build time.
      system_overlay.visible = Adwaita::StyleManager.default.system_supports_color_schemes?
      Adwaita::StyleManager.default.signal_connect('notify::system-supports-color-schemes') do
        system_overlay.visible = Adwaita::StyleManager.default.system_supports_color_schemes?
      end

      # The checkmark over the active button. Blueprint binds `visible` to the
      # button's own `active` property; ruby-gnome reaches the same place
      # through the notify signal, and the handler does nothing else — the
      # colour scheme itself belongs to the action.
      selectors.each do |name, selector|
        checks.fetch(name).visible = selector.active?
        selector.signal_connect('notify::active') do
          checks.fetch(name).visible = selector.active?
        end
      end

      box
    end

    def system_overlay = overlays.fetch(:system)

    def box
      @box ||= Gtk::Box.new(:horizontal, 18).tap do |b|
        b.homogeneous = true
        b.add_css_class('themeswitcher')
      end
    end

    def overlays
      @overlays ||= SCHEMES.each_key.to_h do |name|
        [name, Gtk::Overlay.new.tap do |overlay|
          overlay.halign = :center
          overlay.child = selectors.fetch(name)
          overlay.add_overlay(checks.fetch(name))
        end
]
      end
    end

    # One group, so the three behave as radio buttons. The first is the group
    # leader — grouping a check button with itself trips a GTK assertion.
    #
    # The target is built with an explicit 'i' variant type: the action's state
    # comes from an integer GSettings key, and an int64 target would never
    # compare equal to it, leaving all three buttons permanently inactive.
    def selectors
      @selectors ||= SCHEMES.to_h do |name, scheme|
        [name, Gtk::CheckButton.new.tap do |button|
          button.tooltip_text = _(TOOLTIPS.fetch(name))
          button.halign = :center
          button.add_css_class(name.to_s)
          button.action_name = ACTION_NAME
          button.action_target = GLib::Variant.new(scheme, GLib::VariantType.new('i'))
        end
]
      end.tap do |buttons|
        buttons.values.drop(1).each { |button| button.group = buttons.values.first }
      end
    end

    def checks
      @checks ||= SCHEMES.each_key.to_h do |name|
        [name, Gtk::Image.new.tap do |image|
          image.icon_name = 'object-select-symbolic'
          image.pixel_size = 13
          image.halign = :end
          image.valign = :end
          image.add_css_class('check')
          image.visible = false
        end
]
      end
    end
  end
end
