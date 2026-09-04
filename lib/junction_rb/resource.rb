# frozen_string_literal: true

module JunctionRb
  # What Junction was asked to open: the text it shows in the entry, the URI
  # scheme, and the content type used to look up candidate applications.
  class Resource
    # Junction registers this scheme so a page can hand it a URL to re-dispatch
    # without the browser intercepting it first. The wrapped URI is everything
    # after the scheme, with the "//" the wrapper had to mangle put back.
    SCHEME = 'x-junction'

    FALLBACK_CONTENT_TYPE = 'application/octet-stream'

    def self.for_file(file) = new(unwrap(file))

    def self.unwrap(file)
      if file.uri_scheme == SCHEME
        parse_wrapped(file.uri.split("#{SCHEME}://", 2).last.to_s)
      else
        file
      end
    end

    def self.parse_wrapped(uri)
      uri.sub('file:0//', 'file:///').sub(':0//', '://').then do |unmangled|
        if unmangled.start_with?('~/')
          Gio::File.parse_name(unmangled)
        else
          Gio::File.new_for_commandline_arg(unmangled)
        end
      end
    end

    SCHEME_PATTERN = /\A([A-Za-z][A-Za-z0-9+.\-]*):/

    # Read off the URI text, not from Gio::File#uri_scheme: that one reports
    # "http" for an https URI, which would send us looking up the wrong handler
    # and offering apps that cannot open the page.
    def self.scheme_of(file)
      file.uri[SCHEME_PATTERN, 1]&.downcase || file.uri_scheme
    end

    attr_reader :file

    def initialize(file)
      @file = file
    end

    def scheme = @scheme ||= self.class.scheme_of(file)

    def file? = scheme == 'file'

    # The parse name is what the user sees and edits — a plain path for files,
    # the full URI otherwise. A document-portal proxy path is swapped for the
    # real one so the entry shows something meaningful and other apps can open
    # it.
    def text
      @text ||= file.parse_name.then do |parse_name|
        if Host.document_portal_path?(parse_name)
          Host.real_path(parse_name) || parse_name
        else
          parse_name
        end
      end
    end

    def content_type
      @content_type ||= resolve_content_type
    end

    # A local file is sniffed; anything else is dispatched on its scheme, which
    # is how a browser ends up as the candidate for an https link.
    def resolve_content_type
      if file?
        query_content_type
      else
        "x-scheme-handler/#{scheme}"
      end
    end

    def query_content_type
      file.query_info('standard::content-type', :none).content_type
    rescue StandardError => e
      warn "junction-rb: could not determine content type: #{e.message}"
      FALLBACK_CONTENT_TYPE
    end

    # "Open Location" only makes sense for a real file with a real parent, so it
    # is offered for files but not for directories or unidentifiable blobs.
    NON_LOCATABLE = ['inode/directory', FALLBACK_CONTENT_TYPE].freeze

    def show_in_folder? = file? && !NON_LOCATABLE.include?(content_type)

    # Turns whatever is in the entry back into a URI. A leading ~ or / is a
    # path, and Gio does the percent-escaping; anything else is assumed to be an
    # already-encoded URI and is passed through untouched, so its escapes are
    # not escaped a second time.
    def self.parse_location(text)
      if text == '~' || text.start_with?('~/')
        Gio::File.parse_name(text).uri
      elsif text.start_with?('/')
        Gio::File.new_for_path(text).uri
      else
        text
      end
    end
  end
end
