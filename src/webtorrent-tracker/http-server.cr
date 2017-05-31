require "http/server"

module Webtorrent::Tracker
  class Request < HTTP::Request
    property remote_address : Socket::IPAddress?
  end

  class RequestProcessor < HTTP::Server::RequestProcessor
    def process_with_address(input, output, remote_address : Socket::IPAddress, error = STDERR)
      must_close = true
      response = HTTP::Server::Response.new(output)

      begin
        until @wants_close
          request = Request.from_io(input)

          # EOF
          break unless request

          if request.is_a?(HTTP::Request::BadRequest)
            response.respond_with_error("Bad Request", 400)
            response.close
            return
          end

          request.remote_address = remote_address

          response.version = request.version
          response.reset
          response.headers["Connection"] = "keep-alive" if request.keep_alive?
          context = HTTP::Server::Context.new(request, response)

          begin
            @handler.call(context)
          rescue ex
            response.respond_with_error
            response.close
            error.puts "Unhandled exception on HTTP::Handler"
            ex.inspect_with_backtrace(error)
            return
          end

          if response.upgraded?
            must_close = false
            return
          end

          response.output.close
          output.flush

          break unless request.keep_alive?

          # Skip request body in case the handler
          # didn't read it all, for the next request
          request.body.try &.close
        end
      rescue ex : Errno
        # IO-related error, nothing to do
      ensure
        input.close if must_close
      end
    end
  end

  class HTTPServer < HTTP::Server
    @my_processor : Webtorrent::Tracker::RequestProcessor

    def initialize(@host : String, @port : Int32, &handler : Context ->)
      @my_processor = Webtorrent::Tracker::RequestProcessor.new(handler)
      @processor = @my_processor
    end

    def initialize(@host : String, @port : Int32, handlers : Array(HTTP::Handler), &handler : Context ->)
      handler = HTTP::Server.build_middleware handlers, handler
      @my_processor = Webtorrent::Tracker::RequestProcessor.new(handler)
      @processor = @my_processor
    end

    def initialize(@host : String, @port : Int32, handlers : Array(HTTP::Handler))
      handler = HTTP::Server.build_middleware handlers
      @my_processor = Webtorrent::Tracker::RequestProcessor.new(handler)
      @processor = @my_processor
    end

    def initialize(@host : String, @port : Int32, handler : HTTP::Handler | HTTP::Handler::Proc)
      @my_processor = Webtorrent::Tracker::RequestProcessor.new(handler)
      @processor = @my_processor
    end

    private def handle_client(io)
      # nil means the server was closed
      return unless io

      remote_address = io.remote_address

      io.sync = false

      {% if !flag?(:without_openssl) %}
        if tls = @tls
          io = OpenSSL::SSL::Socket::Server.new(io, tls, sync_close: true)
        end
      {% end %}

      @my_processor.process_with_address(io, io, remote_address)
    end
  end
end
