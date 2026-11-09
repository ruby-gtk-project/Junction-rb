# frozen_string_literal: true

require 'gtk4'
require 'adwaita'
require 'gobject-introspection'
require 'gettext'
require_relative "junction_rb/version"

# Ported from src/main.js, src/bin.js and src/local.js, which between them hold
# everything upstream decides once at start-up: the application id, the website
# the welcome window links into, whether this is a development build, and the
# gettext initialisation (`pkg.initGettext()`).
module JunctionRb
  # The .Rb suffix runs through the desktop id, the metainfo component id, the
  # GSettings schema and the D-Bus service name, so the port installs next to
  # the original rather than fighting it for the name.
  APPLICATION_ID = 're.sonny.Junction.Rb'

  # The icon a checkout uses, so a development copy is distinguishable from an
  # installed one in the dock, the about dialog and the welcome window.
  DEVEL_APPLICATION_ID = "#{APPLICATION_ID}.Devel"

  DESKTOP_ID = "#{APPLICATION_ID}.desktop"

  # Passed explicitly alongside the schema id, exactly as upstream's
  # src/common.js does (`new Gio.Settings({schema_id: "re.sonny.Junction",
  # path: "/re/sonny/Junction/"})`), and it has to agree with `path=` in
  # data/schemas/re.sonny.Junction.Rb.gschema.xml or GSettings aborts the
  # process. The trailing slash is part of the path, not decoration.
  SETTINGS_PATH = '/re/sonny/Junction/Rb/'

  # Upstream's site, not the port's: the welcome window's "Test Junction" link
  # and the success/error pages it opens after registering as the web handler
  # are pages that live there.
  WEBSITE = 'https://junction.sonny.re'

  # Upstream's `pkg.datadir` — where the style sheet, the icons and the schema
  # are read from. In a checkout that is the repository's own data/, and it is
  # the line in the debug report that explains an about dialog with a missing
  # icon or a window with no CSS.
  DATA_DIR = File.expand_path('../data', __dir__)

  # The gettext domain is upstream's app id — `i18n.gettext(app_id)` in
  # po/meson.build — and NOT the port's. A compiled catalogue is found at
  # <path>/<lang>/LC_MESSAGES/<domain>.mo, so the domain is the filename:
  # renaming it to re.sonny.Junction.Rb would orphan all 32 donated
  # translations in po/. The msgids in this port are byte-identical to
  # upstream's for the same reason.
  TEXT_DOMAIN = 're.sonny.Junction'

  # `rake gettext:mo:update` compiles po/*.po to locale/<lang>/LC_MESSAGES/.
  # The path is passed explicitly because the gem's default candidate list
  # starts at ./locale relative to the working directory, which silently finds
  # nothing whenever Junction is launched from somewhere other than a checkout
  # root — which, being a link dispatcher, is almost always.
  LOCALE_DIR = File.expand_path('../locale', __dir__)

  include GetText

  # Bound on the namespace module rather than on each class, because the gem
  # resolves a domain by walking the enclosing module path of the receiver's
  # class as well as its ancestors (GetText::ClassInfo#related_classes): a
  # binding here is therefore found from every JunctionRb::Something, however
  # that class got hold of the markers.
  bindtextdomain TEXT_DOMAIN, path: LOCALE_DIR

  # The markers — `_` to translate now, `N_` to mark a literal here and
  # translate it at display — mixed into every class with user-visible text.
  # Including them also extends the class, so they work in a class body and in
  # `self.` methods as well as in instance methods.
  Translations = GetText

  # The .desktop file, the metainfo and the GSettings schema are translated by
  # GLib and AppStream rather than by the Ruby gem, and they read the same
  # catalogue — so libintl needs the same binding.
  GLib::GetText.bindtextdomain(TEXT_DOMAIN, LOCALE_DIR)

  # `GLib.set_application_name("Junction")`, which both src/bin.js and
  # src/local.js do before anything else. It is what GTK titles a window with
  # when the window sets no title of its own, and src/window.blp sets none —
  # so without this the chooser's header bar reads "ruby" the moment the
  # portrait breakpoint reveals it.
  APPLICATION_NAME = 'Junction'

  GLib.application_name = APPLICATION_NAME

  # Upstream compiles __DEV__ in with its gjspack bundler: src/local.js (a
  # checkout) sets it true and src/bin.js (installed) sets it false. There is
  # no bundler here, so the port reads the environment instead — see PORTING.md
  # — and the variable turns on the same two things: the restart action on
  # Ctrl+Shift+Q, and the `devel` style class and icon that mark a window as
  # not the installed copy.
  # Read on every call rather than frozen into a constant at load: the
  # variable is what a checkout sets, and freezing it would make the setting
  # unobservable to anything that sets it after lib/junction_rb.rb is
  # required — test/portal_test.rb among them.
  DEV_VARIABLE = 'JUNCTION_RB_DEV'

  def self.dev? = !ENV.fetch(DEV_VARIABLE, '').empty?

  def self.icon_name = dev? ? DEVEL_APPLICATION_ID : APPLICATION_ID
end

require_relative 'junction_rb/portal'
require_relative 'junction_rb/background_request'
require_relative 'junction_rb/host'
require_relative 'junction_rb/resource'
require_relative 'junction_rb/desktop_entry'
require_relative 'junction_rb/settings'
require_relative 'junction_rb/uri_entry'
require_relative 'junction_rb/theme_switcher'
require_relative 'junction_rb/menu_model'
require_relative 'junction_rb/tile_button'
require_relative 'junction_rb/app_button'
require_relative 'junction_rb/show_in_folder_button'
require_relative 'junction_rb/about_dialog'
require_relative 'junction_rb/shortcuts_dialog'
require_relative 'junction_rb/welcome_window'
require_relative 'junction_rb/window'
require_relative 'junction_rb/application'
