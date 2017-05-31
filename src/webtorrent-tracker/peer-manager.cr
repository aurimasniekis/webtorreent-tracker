require "redis"
require "json"

module Webtorrent::Tracker
  class PeerManager
    @sockets = {} of String => SocketContext

    PUBSUB_KEY = "peer_pubsub"

    def initialize(@redis_pubsub : Redis, @redis : Redis)
      spawn do
        @redis_pubsub.subscribe(PUBSUB_KEY) do |on|
          on.message do |channel, message|
              on_message(message)
          end
        end
      end
    end

    def add_peer(info_hash : String, peer_id : String, socket : SocketContext)
      @sockets["#{info_hash}||#{peer_id}"] = socket
    end

    def has_peer(info_hash : String, peer_id : String) : Bool
      @sockets.has_key? "#{info_hash}||#{peer_id}"
    end

    def send_to_peer(info_hash : String, peer_id : String, message : String)
      @redis.publish(PUBSUB_KEY, "#{info_hash}||#{peer_id}||#{message}")
    end

    def on_message(message : String)
      parts = message.split("||", 3)

      unless parts.size == 3
        return
      end

      info_hash, peer_id, message = parts

      unless has_peer(info_hash, peer_id)
        return
      end

      socket = @sockets["#{info_hash}||#{peer_id}"]

      puts "================="
      puts "Sending message to #{info_hash}||#{peer_id}"
      puts "================="
      socket.send_message message
    end

    def remove_peer(socket : SocketContext)
      @sockets.each do |key, value|
        if value == socket
          @sockets.delete key
        end
      end
    end
  end
end
