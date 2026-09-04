# frozen_string_literal: true

# libportal has no ruby-gnome binding gem, so its typelibs are loaded straight
# through GObject Introspection. Xdp is what tells us we are sandboxed, asks to
# keep running in the background, and opens a file's folder; XdpGtk4 turns a
# Gtk::Window into the parent handle the portal wants so its dialogs are
# attached to our window rather than floating loose.
module Xdp
  LOG_DOMAIN = 'Xdp'
  GLib::Log.set_log_domain(LOG_DOMAIN)

  GObjectIntrospection::Loader.new(self).load('Xdp')
end

module XdpGtk4
  LOG_DOMAIN = 'XdpGtk4'
  GLib::Log.set_log_domain(LOG_DOMAIN)

  GObjectIntrospection::Loader.new(self).load('XdpGtk4')
end
