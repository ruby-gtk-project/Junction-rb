# frozen_string_literal: true

module JunctionRb
  # The light / system / dark selector at the top of the main menu. The values
  # are Adwaita::ColorScheme's own, because that is what gets stored and handed
  # straight to the style manager.
  class ThemeSwitcher
    SCHEMES = { light: 1, system: 0, dark: 4 }.freeze

    TOOLTIPS = {
      light:  'Light Style',
      system: 'Follow System Style',
      dark:   'Dark Style',
    }.freeze

    def initialize(settings:)
      @settings = settings
    end

    def build
      box.tap do |b|
        SCHEMES.each_key { |name| b.append(overlays.fetch(name)) }
      end

      # Following a system preference is only meaningful where there is one to
      # follow.
      system_overlay.visible = Adwaita::StyleManager.default.system_supports_color_schemes?

      sync_from_settings
      @settings.on_color_scheme_change { sync_from_settings }

      selectors.each do |name, selector|
        selector.signal_connect('notify::active') { update(name, selector) }
        checks.fetch(name).visible = selector.active?
      end

      box
    end

    def update(name, selector)
      checks.fetch(name).visible = selector.active?

      if selector.active? && !@syncing
        @settings.color_scheme = SCHEMES.fetch(name)
      end
    end

    # Guarded, so reflecting the stored value back into the buttons does not
    # look like the user clicking them and write it out again.
    def sync_from_settings
      @syncing = true
      SCHEMES.each { |name, scheme| selectors.fetch(name).active = (@settings.color_scheme == scheme) }
      @syncing = false
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
    def selectors
      @selectors ||= SCHEMES.each_key.to_h do |name|
        [name, Gtk::CheckButton.new.tap do |button|
          button.tooltip_text = TOOLTIPS.fetch(name)
          button.halign = :center
          button.add_css_class(name.to_s)
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
