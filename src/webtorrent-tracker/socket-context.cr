require "json"

module Webtorrent::Tracker
  class SocketContext
    property client_id : String
    property ip : String
    property port : Int32

    def initialize(@socket : HTTP::WebSocket, @http_context : HTTP::Server::Context, @swarm : Swarm)
      @client_id = parse_client_id

      @ip = @http_context.request.as(Request).remote_address.as(Socket::IPAddress).address
      @port = @http_context.request.as(Request).remote_address.as(Socket::IPAddress).port
    end

    def parse_client_id
      match = @http_context.request.path.match(/^\/([^\/]+)\/(announce|scrape)$/)
    
      if match.nil?
        raise InvalidUrlException.new(@http_context.request)
      end

      match[1]
    end

    def on_message(message : String)
      params = parse_message(message)

      case params.action
      when WebtorrentMessage::ACTION_CONNECT
        on_connect(params)
      when WebtorrentMessage::ACTION_ANNOUNCE
        on_announce(params)
      when WebtorrentMessage::ACTION_SCRAPE
        on_scrape(params)
      else
        raise InvalidActionException.new(params.action)
      end
    end

    def on_connect(params : WebtorrentMessage)
    end

    def on_announce(params : WebtorrentMessage)
        params.event = "update" if (params.event.nil? || params.event == "empty")

        puts @swarm.announce(self, params).inspect
    end

    def on_scrape(params : WebtorrentMessage)
      puts @swarm.scrape(params).inspect
    end

    def parse_message(json_request : String)
      begin
        WebtorrentMessage.from_json(json_request)
      rescue ex : JSON::ParseException
        raise InvalidJsonBodyException.new(ex)
      end
    end
  end
end
