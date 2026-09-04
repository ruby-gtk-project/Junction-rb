# frozen_string_literal: true

module JunctionRb
  # The main menu, shared by the two menu buttons. Both popovers need their own
  # theme switcher widget — a widget can only live in one place — so the model
  # is built per button rather than shared as one object.
  class MenuModel
    def self.build
      Gio::Menu.new.tap do |menu|
        menu.append_section(nil, theme_section)
        menu.append_section(nil, window_section)
        menu.append_section(nil, application_section)
      end
    end

    # The custom slot the theme switcher widget is later dropped into.
    def self.theme_section
      Gio::Menu.new.tap do |section|
        section.append_item(
          Gio::MenuItem.new(nil, nil).tap do |item|
                    item.set_attribute_value('custom', GLib::Variant.new('themeswitcher'))
                  end,
        )
      end
    end

    def self.window_section
      Gio::Menu.new.tap do |section|
        section.append('Show App Names', 'win.show-app-names')
        section.append('Copy to Clipboard', 'win.copy')
      end
    end

    def self.application_section
      Gio::Menu.new.tap do |section|
        section.append('Keyboard Shortcuts', 'app.shortcuts')
        section.append('About Junction', 'app.about')
      end
    end
  end
end
