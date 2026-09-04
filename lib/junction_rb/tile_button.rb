# frozen_string_literal: true

module JunctionRb
  # One square in the grid: a big icon with an optional label under it. Both the
  # application tiles and "Open Location" are this shape, so the layout lives
  # here once and the subclass only supplies the icon and what clicking does.
  class TileButton
    ICON_SIZE = 92

    def initialize(settings:, label:, tooltip: nil, on_clicked: nil)
      @settings = settings
      @label = label
      @tooltip = tooltip || label
      @on_clicked = on_clicked
    end

    def build
      button.tap do |b|
        b.tooltip_text = @tooltip
        b.child = box
        b.signal_connect('clicked') { @on_clicked&.call }

        box.tap do |bx|
          bx.append(image)
          bx.append(name_label)

          name_label.tap do |l|
            l.label = @label
            # Bound rather than set, so toggling "Show App Names" updates every
            # open window at once.
            @settings.bind('show-app-names', l, 'visible')
          end
        end
      end

      button
    end

    def button
      @button ||= Gtk::Button.new.tap do |b|
        b.halign = :fill
        b.valign = :fill
        b.width_request = 134
        b.height_request = 134
        b.add_css_class('flat')
      end
    end

    def box
      @box ||= Gtk::Box.new(:vertical, 0).tap do |b|
        b.valign = :center
        b.halign = :center
      end
    end

    def image
      @image ||= Gtk::Image.new.tap do |i|
        i.pixel_size = ICON_SIZE
        i.width_request = ICON_SIZE
        i.height_request = ICON_SIZE
        i.add_css_class('icon-dropshadow')
      end
    end

    def name_label
      @name_label ||= Gtk::Label.new.tap do |l|
        l.ellipsize = :end
        l.max_width_chars = 10
        l.margin_top = 6
        l.visible = false
      end
    end
  end
end
