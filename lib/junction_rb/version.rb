# frozen_string_literal: true

module JunctionRb
  VERSION = '1.6.0'

  # The port keeps its own application id so it can be installed alongside the
  # original. Everything keyed off the id — GSettings path, desktop file name,
  # the self-exclusion in the app list — follows from this one constant.
  APPLICATION_ID = 're.sonny.Junction.Rb'

  DESKTOP_ID = "#{APPLICATION_ID}.desktop"

  SETTINGS_PATH = '/re/sonny/Junction/Rb/'

  WEBSITE = 'https://junction.sonny.re'
end
