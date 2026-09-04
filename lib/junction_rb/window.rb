# frozen_string_literal: true

module JunctionRb
  # One window per resource Junction is asked to open: the grid of applications
  # that can handle it, with the resource itself editable along the bottom.
  class Window
    DEFAULT_WIDTH = 772
    DEFAULT_HEIGHT = 218

    # Taller than it is wide — a phone, or a narrow tile. The bottom bar's menu
    # button and window controls fold away and the header bar appears instead,
    # so the two never both show.
    PORTRAIT = 'max-aspect-ratio: 1'

    def initialize(application:, settings:, file:)
      @application = application
      @settings = settings
      @resource = Resource.for_file(file)
    end

    attr_reader :resource

    def build
      window.tap do |win|
        win.content = toolbar_view
        win.add_breakpoint(portrait_breakpoint)
        win.add_controller(key_controller)

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = window_handle
          view.add_bottom_bar(bottom_bar)

          header_bar.tap do |bar|
            bar.pack_start(top_menu_button)
          end

          window_handle.tap do |handle|
            handle.child = scrolled_window

            scrolled_window.tap do |scrolled|
              scrolled.child = list

              list.tap do |flow_box|
                tiles.each { |tile| flow_box.append(child_for(tile)) }
              end
            end
          end

          bottom_bar.tap do |bar|
            bar.append(bottom_menu_button)
            bar.append(uri_entry.build)
            bar.append(window_controls)
          end
        end

        key_controller.tap do |controller|
          controller.signal_connect('key-pressed') { |_self, keyval| focus_tile(keyval) }
          controller.signal_connect('key-released') { |_self, keyval| activate_tile(keyval) }
        end

        register_actions
      end
    end

    def present = build.present

    # --- Contents ------------------------------------------------------------

    def entries = @entries ||= DesktopEntry.recommended_for(resource.content_type)

    # The application tiles, then "Open Location" where it applies. The order is
    # also the 1…9 shortcut order, so it has to be fixed before anything binds
    # to it.
    def tiles
      @tiles ||= entries.map { |entry| app_button_for(entry) }.then do |buttons|
        if resource.show_in_folder?
          buttons + [show_in_folder_button]
        else
          buttons
        end
      end
    end

    def app_button_for(entry)
      AppButton.new(
        entry:    entry,
        settings: @settings,
        on_open:  method(:open_with),
      )
    end

    def show_in_folder_button
      @show_in_folder_button ||= ShowInFolderButton.new(
        file:      resource.file,
        settings:  @settings,
        parent:    window,
        on_opened: -> { window.close },
      )
    end

    # The child is not focusable itself: focus belongs to the button inside it,
    # which is what the 1…9 shortcuts and arrow keys move between.
    def child_for(tile)
      Gtk::FlowBoxChild.new.tap do |child|
        child.focusable = false
        child.child = tile.build
      end
    end

    def open_with(entry, close_on_success)
      entry.launch(uri_entry.text, content_type: resource.content_type).then do |success|
        if close_on_success && success
          window.close
        end
      end
    end

    # --- Keyboard ------------------------------------------------------------

    # 1…9 pick the nth tile. Focus moves on the press and the button fires on
    # the release, so holding a digit does not launch the app repeatedly.
    def tile_for(keyval)
      Gdk::Keyval.to_name(keyval).then do |name|
        if /\A\d\z/.match?(name)
          tiles[name.to_i - 1]
        end
      end
    end

    def focus_tile(keyval)
      tile_for(keyval).then do |tile|
        tile&.button&.grab_focus
        !tile.nil?
      end
    end

    def activate_tile(keyval)
      tile_for(keyval).then do |tile|
        tile&.button&.activate
        !tile.nil?
      end
    end

    # --- Actions -------------------------------------------------------------

    def register_actions
      window.add_action(copy_action)
      window.add_action(@settings.create_action('show-app-names'))
      window.add_action(run_action)

      copy_action.signal_connect('activate') { copy_to_clipboard }
      run_action.signal_connect('activate') { |_action, target| run_desktop_action(target) }
    end

    def copy_action = @copy_action ||= Gio::SimpleAction.new('copy')

    # ruby-gnome cannot convert the a{ss} dictionary the original used, so the
    # target is a plain string array: [desktop id, action name]. The location is
    # not carried in it — the entry is right there and holds the current text,
    # which is the value the user expects to be acted on anyway.
    def run_action
      @run_action ||= Gio::SimpleAction.new('run-action', GLib::VariantType.new('as'))
    end

    # ruby-gnome unpacks the variant before it reaches here, so the target
    # arrives as a plain [desktop id, action name] array.
    def run_desktop_action((desktop_id, action))
      DesktopEntry.find(entries, desktop_id)&.then do |entry|
        if entry.launch_action(action, uri_entry.text)
          window.close
        end
      end
    end

    def copy_to_clipboard
      Gdk::Display.default&.clipboard&.set(uri_entry.text)
    end

    # --- Widgets -------------------------------------------------------------

    def window
      @window ||= Adwaita::ApplicationWindow.new(@application).tap do |win|
        win.set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
        win.width_request = 360
        win.height_request = DEFAULT_HEIGHT
        win.add_css_class('main')
      end
    end

    # add_setter cannot take a boolean through ruby-gnome — it reaches
    # adw_breakpoint_add_setter without a GValue and the call is dropped — so
    # the layout is switched from the apply/unapply signals instead, which also
    # keeps all five changes readable in one place.
    def portrait_breakpoint
      @portrait_breakpoint ||=
        Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse(PORTRAIT)).tap do |breakpoint|
          breakpoint.signal_connect('apply') { apply_portrait(true) }
          breakpoint.signal_connect('unapply') { apply_portrait(false) }
        end
    end

    # Portrait fills the grid across the bottom and moves the menu up into the
    # header bar, so the bar at the bottom is left to the entry alone.
    def apply_portrait(portrait)
      if portrait
        list.halign = :fill
        list.valign = :end
      else
        list.halign = :center
        list.valign = :center
      end

      window_controls.visible = !portrait
      bottom_menu_button.visible = !portrait
      toolbar_view.reveal_top_bars = portrait
    end

    # The top bars stay hidden in landscape: the bottom bar already carries the
    # menu and the close button, and a second header would only eat the grid.
    def toolbar_view
      @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
        view.reveal_top_bars = false
      end
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def window_handle = @window_handle ||= Gtk::WindowHandle.new

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.vexpand = true
      end
    end

    def list
      @list ||= Gtk::FlowBox.new.tap do |flow_box|
        flow_box.halign = :center
        flow_box.valign = :center
        flow_box.max_children_per_line = 5
        flow_box.min_children_per_line = 2
        flow_box.homogeneous = true
        flow_box.column_spacing = 12
        flow_box.row_spacing = 12
        flow_box.selection_mode = :none
        flow_box.activate_on_single_click = true
        flow_box.add_css_class('list')
      end
    end

    def bottom_bar
      @bottom_bar ||= Gtk::Box.new(:horizontal, 12).tap do |bar|
        bar.add_css_class('bar')
      end
    end

    def top_menu_button = @top_menu_button ||= menu_button

    def bottom_menu_button = @bottom_menu_button ||= menu_button

    # Each button gets its own model and its own theme switcher: a widget can
    # only be in one popover at a time.
    def menu_button
      Gtk::MenuButton.new.tap do |button|
        button.menu_model = MenuModel.build
        button.icon_name = 'open-menu-symbolic'
        button.tooltip_text = 'Main Menu'
        button.valign = :center
        button.primary = true
        button.add_css_class('circular')
        button.add_css_class('flat')
        button.popover.add_child(ThemeSwitcher.new(settings: @settings).build, 'themeswitcher')
      end
    end

    def window_controls
      @window_controls ||= Gtk::WindowControls.new(:end).tap do |controls|
        controls.decoration_layout = 'close'
      end
    end

    def uri_entry = @uri_entry ||= UriEntry.new(resource: resource)

    def key_controller = @key_controller ||= Gtk::EventControllerKey.new
  end
end
