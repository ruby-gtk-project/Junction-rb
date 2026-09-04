# frozen_string_literal: true

module JunctionRb
  # An application tile. Clicking opens the resource and closes Junction; the
  # variations — keep Junction open, show the app's desktop actions — hang off
  # the modifier, the mouse button, or a long press.
  class AppButton < TileButton
    def initialize(entry:, settings:, on_open:)
      super(settings: settings, label: entry.name)
      @entry = entry
      @on_open = on_open
      # Keyboard activation (Return, space, and the 1…9 shortcuts) comes through
      # the button's own clicked signal; the pointer goes through the gesture
      # below, which claims the sequence so the two cannot both fire.
      @on_clicked = -> { open(true) }
    end

    attr_reader :entry

    def build
      super.tap do |b|
        set_icon
        box.append(popover_menu)

        b.add_controller(click_gesture)
        b.add_controller(long_press_gesture)
        b.add_controller(key_controller)

        click_gesture.tap do |gesture|
          gesture.signal_connect('pressed') { handle_press(gesture) }
        end

        long_press_gesture.tap do |gesture|
          gesture.signal_connect('pressed') do
            popup_actions_menu
            gesture.set_state(:claimed)
          end
        end

        key_controller.tap do |controller|
          controller.signal_connect('key-released') do |_self, keyval, _keycode, state|
            handle_key(keyval, state)
          end
        end
      end
    end

    def open(close_on_success) = @on_open.call(entry, close_on_success)

    # Left click opens and closes; Ctrl+left opens and stays, so several apps can
    # be launched from one window. Middle click is the same "stay open" without
    # the modifier, and right click asks for the desktop actions instead.
    def handle_press(gesture)
      gesture.current_event.then do |event|
        # A touch event has no button; treat it as a plain primary click.
        button_of(event).then do |pressed|
          case pressed
          when Gdk::BUTTON_SECONDARY
            popup_actions_menu
            gesture.set_state(:claimed)
          when Gdk::BUTTON_MIDDLE
            open(false)
            gesture.set_state(:claimed)
          when Gdk::BUTTON_PRIMARY
            open(!control_held?(event))
            gesture.set_state(:claimed)
          else
            gesture.set_state(:denied)
          end
        end
      end
    end

    def button_of(event)
      event.respond_to?(:button) ? event.button : Gdk::BUTTON_PRIMARY
    end

    def control_held?(event)
      event.respond_to?(:modifier_state) &&
        !(event.modifier_state & Gdk::ModifierType::CONTROL_MASK).zero?
    end

    # The Menu key is the keyboard's right click. Ctrl+Return and Ctrl+space
    # mirror Ctrl+click: open, but leave Junction up.
    def handle_key(keyval, state)
      Gdk::Keyval.to_name(keyval).then do |name|
        if name == 'Menu'
          popup_actions_menu
        end

        if ['Return', 'space'].include?(name) &&
           !(state & Gdk::ModifierType::CONTROL_MASK).zero?
          open(false)
        end
      end
    end

    # Built fresh on each popup so the location reflects whatever the user has
    # since typed into the entry.
    def popup_actions_menu
      menu.remove_all

      entry.actions.each do |(action, label)|
        menu.append_item(menu_item_for(action, label))
      end

      if menu.n_items.positive?
        popover_menu.popup
      end
    end

    def menu_item_for(action, label)
      Gio::MenuItem.new(label, nil).tap do |item|
        item.set_action_and_target_value(
          'win.run-action',
          GLib::Variant.new([entry.id, action]),
        )
      end
    end

    def set_icon
      entry.icon.then do |icon|
        case icon
        when Gio::FileIcon then image.set_from_file(Host.host_path(icon.file.path))
        when nil then image.icon_name = 'application-x-executable-symbolic'
        else image.set_from_gicon(icon)
        end
      end
    end

    def menu = @menu ||= Gio::Menu.new

    def popover_menu
      @popover_menu ||= Gtk::PopoverMenu.new(menu).tap do |popover|
        popover.halign = :center
      end
    end

    def click_gesture = @click_gesture ||= Gtk::GestureClick.new.tap { |g| g.button = 0 }

    def long_press_gesture = @long_press_gesture ||= Gtk::GestureLongPress.new

    def key_controller = @key_controller ||= Gtk::EventControllerKey.new
  end
end
