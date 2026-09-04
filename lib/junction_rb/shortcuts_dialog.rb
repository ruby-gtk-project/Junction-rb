# frozen_string_literal: true

module JunctionRb
  # The keyboard shortcuts reference. Adwaita's shortcuts dialog replaces
  # Gtk::ShortcutsWindow, which GTK deprecated in 4.18.
  class ShortcutsDialog
    # Two groups, matching the original: what you can do to the resource in
    # front of you, and what you can do to Junction.
    SECTIONS = {
      nil           => [
        ['Discard and close', 'Escape <Primary>W'],
        ['Copy to Clipboard', '<Primary>C'],
        ['Select next/previous application', 'Left Right'],
        ['Open with selected application', 'Return space'],
        ['Open with selected application and stay active', '<Primary>Return <Primary>space'],
        ['Open with application at position', '1...9'],
      ],
      'Application' => [
        ['Keyboard Shortcuts', '<Primary>question'],
        ['Quit', '<Primary>Q'],
      ],
    }.freeze

    def build
      dialog.tap do |d|
        sections.each { |section| d.add(section) }
      end
    end

    def present(parent) = build.present(parent)

    def dialog = @dialog ||= Adwaita::ShortcutsDialog.new

    def sections
      @sections ||= SECTIONS.map do |title, shortcuts|
        Adwaita::ShortcutsSection.new.tap do |section|
          section.title = title
          shortcuts.each { |(label, accelerator)| section.add(item_for(label, accelerator)) }
        end
      end
    end

    def item_for(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
  end
end
