# frozen_string_literal: true

module JunctionRb
  # "Open Location": reveal the file in the file manager rather than open it.
  # The original went through the OpenURI portal for this; Gtk::FileLauncher has
  # done the same job natively since GTK 4.10, portal included, so there is no
  # reason to carry libportal for it.
  class ShowInFolderButton < TileButton
    ICON_SIZE = 48

    def initialize(file:, settings:, parent:, on_opened:)
      super(
        settings: settings,
        label:    'Open Location',
        tooltip:  'View File in File Manager',
      )
      @file = file
      @parent = parent
      @on_opened = on_opened
      @on_clicked = -> { open_containing_folder }
    end

    def build
      super.tap do
        image.icon_name = 'folder-symbolic'
        image.pixel_size = ICON_SIZE
        image.width_request = ICON_SIZE
        image.height_request = ICON_SIZE
      end
    end

    # Junction only steps out of the way once the file manager has actually come
    # up, so a failure leaves the window there to try something else with.
    def open_containing_folder
      launcher.open_containing_folder(@parent) do |_launcher, result|
        finish(result)
      end
    end

    def finish(result)
      launcher.open_containing_folder_finish(result).then do |opened|
        if opened
          @on_opened.call
        end
      end
    rescue StandardError => e
      warn "junction-rb: could not show #{@file.uri} in its folder: #{e.message}"
    end

    def launcher = @launcher ||= Gtk::FileLauncher.new(@file)
  end
end
