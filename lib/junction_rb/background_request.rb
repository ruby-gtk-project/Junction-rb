# frozen_string_literal: true

require 'fiddle'

module JunctionRb
  # The background/autostart portal request, called through Fiddle rather than
  # introspection.
  #
  # xdp_portal_request_background takes the autostart command as a GPtrArray of
  # strings, and ruby-gnome cannot marshal a GPtrArray in-argument — it raises
  # "TODO: in Ruby -> GIArgument(array/GPtrArray)". Everything else about the
  # portal goes through the typelib as normal; only this one call needs the
  # array built by hand.
  #
  # The symbols resolve out of the already-loaded process image: requiring the
  # Xdp typelib dlopens libportal, so by the time this runs the functions are
  # there to be found.
  module BackgroundRequest
    # void xdp_portal_request_background (XdpPortal*, XdpParent*, const char*,
    #                                     GPtrArray*, XdpBackgroundFlags,
    #                                     GCancellable*, GAsyncReadyCallback,
    #                                     gpointer)
    REQUEST = [
      Fiddle::TYPE_VOIDP,  # XdpPortal *portal
      Fiddle::TYPE_VOIDP,  # XdpParent *parent
      Fiddle::TYPE_VOIDP,  # const char *reason
      Fiddle::TYPE_VOIDP,  # GPtrArray *commandline
      Fiddle::TYPE_INT,    # XdpBackgroundFlags flags
      Fiddle::TYPE_VOIDP,  # GCancellable *cancellable
      Fiddle::TYPE_VOIDP,  # GAsyncReadyCallback callback
      Fiddle::TYPE_VOIDP,  # gpointer data
    ].freeze

    # Read off the enum rather than written out: XDP_BACKGROUND_FLAG_AUTOSTART
    # is 1 and ACTIVATABLE is 2, which are easy to transpose into a request that
    # succeeds while asking for the wrong thing.
    AUTOSTART = Xdp::BackgroundFlags::AUTOSTART.to_i

    def self.handle = Fiddle::Handle::DEFAULT

    def self.function(name, args, result)
      Fiddle::Function.new(handle[name], args, result)
    end

    def self.portal_new = @portal_new ||= function('xdp_portal_new', [], Fiddle::TYPE_VOIDP)

    def self.request = @request ||= function('xdp_portal_request_background', REQUEST, Fiddle::TYPE_VOID)

    def self.request_finish
      @request_finish ||= function(
        'xdp_portal_request_background_finish',
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_INT,
      )
    end

    def self.ptr_array_new = @ptr_array_new ||= function('g_ptr_array_new', [], Fiddle::TYPE_VOIDP)

    def self.ptr_array_add
      @ptr_array_add ||= function(
        'g_ptr_array_add',
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_VOID,
      )
    end

    def self.ptr_array_unref
      @ptr_array_unref ||= function('g_ptr_array_unref', [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
    end

    # Its own XdpPortal instance rather than the introspected one: there is no
    # public way to get the underlying pointer out of a ruby-gnome object, and a
    # second portal handle is cheap — it is a DBus proxy, not a resource.
    def self.portal = @portal ||= portal_new.call

    # The strings and the array have to outlive the call, which returns before
    # the portal has answered, so both are held here rather than left to the GC.
    def self.commandline(command)
      command.map { |argument| Fiddle::Pointer[argument] }.then do |pointers|
        @arguments = pointers
        ptr_array_new.call.tap do |array|
          pointers.each { |pointer| ptr_array_add.call(array, pointer) }
          @array = array
        end
      end
    end

    # Likewise the closure: freed too early and the portal's reply lands on a
    # dangling function pointer.
    def self.callback(&block)
      Fiddle::Closure::BlockCaller.new(
        Fiddle::TYPE_VOID,
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
      ) do |source, result, _data|
        block.call(finish(source, result))
      end.tap { |closure| @closure = closure }
    end

    def self.finish(source, result)
      Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP, Fiddle::RUBY_FREE).then do |error|
        request_finish.call(source, result, error).then do |granted|
          release(error)
          granted == 1
        end
      end
    end

    # The GError, if there was one, is ours to free.
    def self.release(error)
      error.ptr.null? ? nil : Fiddle::Function.new(
        handle['g_error_free'],
        [Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_VOID,
      ).call(error.ptr)
    rescue StandardError
      nil
    end

    def self.call(reason:, command:, &block)
      request.call(
        portal,
        nil,
        Fiddle::Pointer[reason],
        commandline(command),
        AUTOSTART,
        nil,
        callback(&block),
        nil,
      )
    end
  end
end
