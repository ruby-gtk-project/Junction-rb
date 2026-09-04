# frozen_string_literal: true

module JunctionRb
  # "Open Location": reveal the file in the file manager rather than open it.
  # This goes through the OpenURI portal, which is what reaches the host's file
  # manager from inside a sandbox.
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
      Host.open_directory(@parent, @file.uri) do |opened|
        if opened
          @on_opened.call
        end
      end
    end
  end
end
