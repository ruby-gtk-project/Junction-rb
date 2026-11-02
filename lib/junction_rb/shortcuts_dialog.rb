# frozen_string_literal: true

module JunctionRb
  # The keyboard shortcuts reference. Adwaita's shortcuts dialog replaces
  # Gtk::ShortcutsWindow, which GTK deprecated in 4.18.
  class ShortcutsDialog
    include Translations

    # Two untitled groups, matching the original's two ShortcutsGroups
    # (src/ShortcutsWindow.blp): what you can do to the resource in front of
    # you, and what you can do to Junction. Neither carries a title upstream, so
    # neither carries one here — a title invented by the port would be a
    # user-visible string with no msgid in any of the 32 catalogues.
    #
    # The labels are marked here and translated in #item_for, because the table
    # is frozen at load time and the locale is not settled until the
    # application starts up.
    SECTIONS = [
      [
        [N_('Discard and close'), 'Escape <Primary>W'],
        [N_('Copy to Clipboard'), '<Primary>C'],
        [N_('Select next/previous application'), 'Left Right'],
        [N_('Open with selected application'), 'Return space'],
        [N_('Open with selected application and stay active'), '<Primary>Return <Primary>space'],
        [N_('Open with application at position'), '1...9'],
      ],
      [
        [N_('Keyboard Shortcuts'), '<Primary>question'],
        [N_('Quit'), '<Primary>Q'],
      ],
    ].freeze

    def build
      dialog.tap do |d|
        sections.each { |section| d.add(section) }
      end
    end

    def present(parent) = build.present(parent)

    def dialog = @dialog ||= Adwaita::ShortcutsDialog.new

    def sections
      @sections ||= SECTIONS.map do |shortcuts|
        Adwaita::ShortcutsSection.new.tap do |section|
          shortcuts.each { |(label, accelerator)| section.add(item_for(label, accelerator)) }
        end
      end
    end

    def item_for(label, accelerator) = Adwaita::ShortcutsItem.new(_(label), accelerator)
  end
end
