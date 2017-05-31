require "json"

module Webtorrent::Tracker
  class SocketContext
    INTERVAL_MS = 10 * 60 * 1000

    property client_id : String
    property ip : String
    property port : Int32

    def initialize(@socket : HTTP::WebSocket, @http_context : HTTP::Server::Context, @swarm : Swarm, @peer_manager : PeerManager)
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

      unless @peer_manager.has_peer(params.info_hash.hex, params.peer_id.hex)
        @peer_manager.add_peer(params.info_hash.hex, params.peer_id.hex, self)
      end

      case params.action
      when WebtorrentMessage::ACTION_CONNECT
        on_connect(params)
      when WebtorrentMessage::ACTION_ANNOUNCE
        on_announce(params)
      when WebtorrentMessage::ACTION_SCRAPE
        on_scrape(params)
      when "none"
        if params.answer
          message = {
            action: "announce",
            answer: params.answer,
            offer_id: params.offer_id.as(WebtorrentMessage::HashValue).value,
            peer_id: params.peer_id.value,
            info_hash: params.info_hash.value
          }

          @peer_manager.send_to_peer(params.info_hash.hex, params.to_peer_id.as(WebtorrentMessage::HashValue).hex, message.to_json)
        end
      else
        raise InvalidActionException.new(params.action)
      end
    end

    def on_connect(params : WebtorrentMessage)
    end

    def on_announce(params : WebtorrentMessage)
        params.event = "update" if (params.event.nil? || params.event == "empty")

        response =  @swarm.announce(self, params)

        unless response.has_key? "action"
          response["action"] = WebtorrentMessage::ACTION_ANNOUNCE
        end

        unless response.has_key? "interval"
          response["interval"] = (INTERVAL_MS / 1000).ceil
        end

        response["action"] = params.action

        peers = [] of Peer
        if response["action"] == WebtorrentMessage::ACTION_ANNOUNCE
          peers = response["peers"].as(Array(Peer))
          response.delete "peers"

          response["info_hash"] = params.info_hash.value
          response["interval"] = (INTERVAL_MS / 1000 / 5).ceil
        end

        if params.answer.nil?
          @socket.send response.to_json
        end

        unless params.offers.nil?
          i = 0
          peers.each do |peer|
              offers = params.offers.as(Array(WebtorrentMessage::Offers))
              puts "Accesing #{i} offers size #{offers.size}"
              offer = offers[i]

              message = {
                action: "announce",
                offer: offers[i].offer,
                offer_id: offers[i].offer_id,
                peer_id: params.peer_id.value,
                info_hash: params.info_hash.value
              }

              i += 1
              if offers.size <= i
                i -= 1
              end

              @peer_manager.send_to_peer(params.info_hash.hex, peer.peerId, message.to_json)
          end
        end

        if params.answer
          message = {
            action: "announce",
            answer: params.answer,
            offer_id: params.offer_id.as(WebtorrentMessage::HashValue).value,
            peer_id: params.peer_id.value,
            info_hash: params.info_hash.value
          }

          @peer_manager.send_to_peer(params.info_hash.hex, params.to_peer_id.as(WebtorrentMessage::HashValue).hex, message.to_json)
        end
        # puts response.to_json
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

    def send_message(message : String)
      if @socket.closed?
        return close
      end

      @socket.send message
    end

    def close
        @peer_manager.remove_peer(self)
    end
  end
end
